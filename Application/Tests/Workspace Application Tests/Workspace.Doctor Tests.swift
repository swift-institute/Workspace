import Tagged_Primitives
import Testing

@testable import Workspace_Application

extension Workspace.Doctor {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

// MARK: - Check harness

extension Workspace.Doctor.Test.Unit {
    /// A harness check over integers: the evaluation must fire on
    /// negative subjects and stay silent on non-negative ones, matching
    /// the declared controls.
    private static func harness(
        evaluate: @escaping @Sendable (Int) -> [Workspace.Doctor.Finding]
    ) -> Workspace.Doctor.Check<Int> {
        .init(
            name: "harness",
            scope: .contributor,
            controls: .init(positive: -1, negative: 0),
            evaluate: evaluate
        )
    }

    private static func firing(_ subject: Int) -> [Workspace.Doctor.Finding] {
        subject < 0 ? [.init(severity: .error, message: "\(subject) is negative")] : []
    }

    @Test
    func `a broken evaluation is caught by the known-positive control and aborts at unmeasured`() {
        let outcome = Self.harness { _ in [] }.run(population: [1, 2], inventory: 2)

        #expect(
            outcome.result
                == .unmeasured(reason: "the known-positive control did not fire")
        )
    }

    @Test
    func `an over-firing evaluation is caught by the known-negative control and aborts at unmeasured`() {
        let outcome = Self.harness { _ in [.init(severity: .error, message: "always")] }
            .run(population: [1, 2], inventory: 2)

        #expect(outcome.result == .unmeasured(reason: "the known-negative control fired"))
    }

    @Test
    func `an empty population against a non-empty inventory is unmeasured, never ok`() {
        let outcome = Self.harness(evaluate: Self.firing).run(population: [], inventory: 3)

        #expect(outcome.result == .unmeasured(reason: "empty population against an inventory of 3"))
    }

    @Test
    func `an empty population against an empty inventory is ok and states population zero`() {
        let outcome = Self.harness(evaluate: Self.firing).run(population: [], inventory: 0)

        #expect(outcome.result == .ok(population: 0))
    }

    @Test
    func `a measured clean population states its size`() {
        let outcome = Self.harness(evaluate: Self.firing).run(population: [1, 2, 3], inventory: 3)

        #expect(outcome.result == .ok(population: 3))
        #expect(outcome.findings.isEmpty)
    }

    @Test
    func `findings carry the maximum severity and the population covered`() {
        let outcome = Self.harness { subject in
            switch subject {
            case ..<0: [.init(severity: .error, message: "\(subject) is negative")]
            case 7: [.init(severity: .warning, message: "seven is suspicious")]
            default: []
            }
        }
        .run(population: [7, -2, 1], inventory: 3)

        #expect(outcome.result == .finding(severity: .error, population: 3))
        #expect(outcome.findings.count == 2)
    }
}

// MARK: - Report

extension Workspace.Doctor.Test.Unit {
    private static func outcome(
        _ check: Swift.String,
        _ result: Workspace.Doctor.Result,
        findings: [Workspace.Doctor.Finding] = []
    ) -> Workspace.Doctor.Outcome {
        .init(check: check, scope: .contributor, result: result, findings: findings)
    }

    @Test
    func `unmeasured dominates the exit status at 2`() {
        let report = Workspace.Doctor.Report(outcomes: [
            Self.outcome("a", .ok(population: 2)),
            Self.outcome(
                "b",
                .finding(severity: .error, population: 1),
                findings: [.init(severity: .error, message: "broken")]
            ),
            Self.outcome("c", .unmeasured(reason: "no population")),
        ])

        #expect(report.status == 2)
    }

    @Test
    func `error findings exit 1`() {
        let report = Workspace.Doctor.Report(outcomes: [
            Self.outcome("a", .ok(population: 2)),
            Self.outcome(
                "b",
                .finding(severity: .error, population: 1),
                findings: [.init(severity: .error, message: "broken")]
            ),
        ])

        #expect(report.status == 1)
    }

    @Test
    func `warning findings alone exit 0`() {
        let report = Workspace.Doctor.Report(outcomes: [
            Self.outcome(
                "a",
                .finding(severity: .warning, population: 2),
                findings: [.init(severity: .warning, message: "dusty")]
            )
        ])

        #expect(report.status == 0)
    }

    @Test
    func `a run containing unmeasured is textually distinct from ok and never described as passing`() {
        let report = Workspace.Doctor.Report(outcomes: [
            Self.outcome("a", .ok(population: 2)),
            Self.outcome("b", .unmeasured(reason: "no population")),
        ])

        #expect(report.description.contains("unmeasured"))
        #expect(!report.description.contains("passed"))
    }

    @Test
    func `the summary states measured populations, not only finding counts`() {
        let report = Workspace.Doctor.Report(outcomes: [
            Self.outcome("a", .ok(population: 2)),
            Self.outcome(
                "b",
                .finding(severity: .warning, population: 5),
                findings: [.init(severity: .warning, message: "dusty")]
            ),
        ])

        #expect(report.description.contains("measured populations: a 2, b 5"))
    }

    @Test
    func `a passing summary names what did not run`() {
        let report = Workspace.Doctor.Report(outcomes: [
            Self.outcome("a", .ok(population: 2)),
            .init(
                check: "b",
                scope: .instituteInternal,
                result: .notApplicable(scope: .instituteInternal),
                findings: []
            ),
        ])

        #expect(report.status == 0)
        #expect(report.description.contains("1 not run (institute-internal)"))
    }
}

// MARK: - Acceptance

extension Workspace.Doctor.Test.Integration {
    private static func materialization(
        _ report: Workspace.Doctor.Report
    ) throws -> Workspace.Doctor.Outcome {
        try #require(report.outcomes.first { $0.check == "materialization" })
    }

    @Test
    func `a canonical sibling checkout is the only materialized state accepted by doctor`() async throws {
        let repository = Workspace.Repository(
            name: "swift-example",
            url: "https://github.com/swift-foundations/swift-example.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let fixture = try Workspace.Doctor.Fixture(repositories: [repository])
        defer { fixture.remove() }
        try fixture.materialize(repository.name)
        try Workspace.Xcode.write([repository], at: fixture.directory)

        let report = await fixture.doctor().run()

        #expect(try Self.materialization(report).result == .ok(population: 1))
    }

    @Test
    func `a legacy in checkout repository is not counted as canonical materialization`() async throws {
        let repository = Workspace.Repository(
            name: "swift-example",
            url: "https://github.com/swift-foundations/swift-example.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let fixture = try Workspace.Doctor.Fixture(repositories: [repository])
        defer { fixture.remove() }
        try fixture.materializeLegacy(repository.name)
        try Workspace.Xcode.write([repository], at: fixture.directory)

        let report = await fixture.doctor().run()

        #expect(
            try Self.materialization(report).result
                == .finding(severity: .error, population: 1)
        )
    }

    @Test
    func `both canonical and legacy repositories are a doctor conflict rather than an ambiguous success`() async throws {
        let repository = Workspace.Repository(
            name: "swift-example",
            url: "https://github.com/swift-foundations/swift-example.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let fixture = try Workspace.Doctor.Fixture(repositories: [repository])
        defer { fixture.remove() }
        try fixture.materialize(repository.name)
        try fixture.materializeLegacy(repository.name)
        try Workspace.Xcode.write([repository], at: fixture.directory)

        let report = await fixture.doctor().run()

        #expect(
            try Self.materialization(report).result
                == .finding(severity: .error, population: 1)
        )
    }

    @Test
    func `neither canonical nor legacy repository is reported as materialized`() async throws {
        let repository = Workspace.Repository(
            name: "swift-example",
            url: "https://github.com/swift-foundations/swift-example.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let fixture = try Workspace.Doctor.Fixture(repositories: [repository])
        defer { fixture.remove() }
        try Workspace.Xcode.write([repository], at: fixture.directory)

        let report = await fixture.doctor().run()

        #expect(
            try Self.materialization(report).result
                == .finding(severity: .error, population: 1)
        )
    }

    @Test
    func `Contributor checks ignore unselected inventory repositories`() async throws {
        let selected = Workspace.Repository(
            name: "swift-selected",
            url: "https://github.com/swift-foundations/swift-selected.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let unselected = Workspace.Repository(
            name: "swift-unselected",
            url: "https://github.com/swift-foundations/swift-unselected.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let fixture = try Workspace.Doctor.Fixture(
            repositories: [selected, unselected],
            selected: [selected]
        )
        defer { fixture.remove() }
        try fixture.materialize(unselected.name)
        try fixture.write(
            "not resolved-state JSON",
            to: "swift-foundations/swift-unselected/Package.resolved"
        )
        try Workspace.Xcode.write(fixture.selection.repositories, at: fixture.directory)

        let report = await fixture.doctor().run()

        let materialization = report.outcomes.first { $0.check == "materialization" }
        #expect(materialization?.result == .finding(severity: .error, population: 1))
        #expect(
            materialization?.findings.contains {
                $0.message.contains(unselected.name)
            } == false
        )
        let reference = report.outcomes.first { $0.check == "workspace-reference" }
        #expect(reference?.result == .ok(population: 1))
        let census = report.outcomes.first { $0.check == "working-state" }
        #expect(
            census?.result
                == .unmeasured(reason: "empty population against an inventory of 1")
        )
        let pins = report.outcomes.first { $0.check == "resolved-pins" }
        #expect(pins?.result == .ok(population: 0))
        let manifest = report.outcomes.first { $0.check == "manifest-identity" }
        #expect(
            manifest?.result
                == .unmeasured(reason: "empty population against an inventory of 1")
        )
    }

    @Test
    func `an empty Packages population against a non-empty inventory reports unmeasured and exits 2`()
        async throws
    {
        let fixture = try Workspace.Doctor.Fixture(repositories: [
            .init(
                name: "swift-example",
                url: "https://github.com/swift-foundations/swift-example.git",
                organization: "swift-foundations",
                layer: .foundations
            )
        ])
        defer { fixture.remove() }

        let report = await fixture.doctor().run()

        #expect(report.status == 2)
        #expect(report.description.contains("unmeasured"))
        let census = report.outcomes.first { $0.check == "working-state" }
        #expect(
            census?.result
                == .unmeasured(reason: "empty population against an inventory of 1")
        )
    }

    @Test
    func `a run without Institute access reports notApplicable rather than unmeasured and exits 0`()
        async throws
    {
        let fixture = try Workspace.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        try Workspace.Xcode.write([], at: fixture.directory)

        let report = await fixture.doctor().run(access: .contributor)

        #expect(report.status == 0)
        #expect(!report.description.contains("unmeasured"))
        #expect(report.description.contains("not run (institute-internal)"))
        #expect(report.description.contains("doctor: passed"))
        let currency = report.outcomes.first { $0.check == "inventory-currency" }
        #expect(currency?.result == .notApplicable(scope: .instituteInternal))
    }

    @Test
    func `institute access measures inventory currency as ok when discovery matches`() async throws {
        let fixture = try Workspace.Doctor.Fixture(repositories: [
            .init(
                name: "swift-example",
                url: "https://github.com/swift-foundations/swift-example.git",
                organization: "swift-foundations",
                layer: .foundations
            )
        ])
        defer { fixture.remove() }
        let discovery = Workspace.Inventory.Discovery(
            repositories: [
                .init(
                    id: .init(1),
                    key: .init(owner: .init("swift-foundations"), name: .init("swift-example")),
                    layer: .foundations
                )
            ],
            exclusions: []
        )

        let report = await fixture.doctor().run(access: .institute(inventory: { discovery }))

        let currency = report.outcomes.first { $0.check == "inventory-currency" }
        #expect(currency?.result == .ok(population: 1))
    }

    @Test
    func `inventory drift is a measured error finding`() async throws {
        let fixture = try Workspace.Doctor.Fixture(repositories: [
            .init(
                name: "swift-example",
                url: "https://github.com/swift-foundations/swift-example.git",
                organization: "swift-foundations",
                layer: .foundations
            )
        ])
        defer { fixture.remove() }
        let discovery = Workspace.Inventory.Discovery(repositories: [], exclusions: [])

        let report = await fixture.doctor().run(access: .institute(inventory: { discovery }))

        let currency = report.outcomes.first { $0.check == "inventory-currency" }
        #expect(currency?.result == .finding(severity: .error, population: 1))
        #expect(
            currency?.findings.contains {
                $0.message.contains("in Workspace.json but not discovered on GitHub")
            } == true
        )
    }

    @Test
    func `a failed discovery is unmeasured, not a clean result`() async throws {
        let fixture = try Workspace.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        try Workspace.Xcode.write([], at: fixture.directory)

        let report = await fixture.doctor().run(
            access: .institute(inventory: { () throws(Workspace.Error) in
                throw .process("discovery transport failed")
            })
        )

        #expect(report.status == 2)
        let currency = report.outcomes.first { $0.check == "inventory-currency" }
        #expect(
            currency?.result
                == .unmeasured(
                    reason: "inventory discovery failed: discovery transport failed"
                )
        )
    }
}
