import Testing

@testable import Workspace_Application

extension Workspace.Lint.Ledger {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Workspace.Lint.Ledger.Test.Unit {
    @Test
    func `ledger is a complete census with exact residual and ownership state`() throws {
        let repositories = Workspace.Lint.Ledger.Test.repositories
        let disposition = try #require(
            Workspace.Lint.Ledger.Disposition(
                argument: "PLAT-ARCH-022=remediation@swift-foundations/swift-linter#20"
            )
        )
        let verification = try #require(
            Workspace.Lint.Ledger.Verification(
                argument: "swift-primitives/swift-alpha@"
                    + Swift.String(repeating: "A", count: 40)
                    + "=https://github.com/swift-primitives/swift-alpha/actions/runs/42"
            )
        )
        let report = try Workspace.Lint.Ledger.Report(
            repositories: repositories,
            report: Workspace.Lint.Ledger.Test.sweep(repositories: repositories),
            dispositions: [disposition],
            verifications: [verification]
        )

        #expect(
            report.packages.map(\.repository.identity) == [
                "swift-primitives/swift-alpha",
                "swift-primitives/swift-beta",
                "swift-standards/swift-gamma",
            ]
        )
        #expect(report.packages.count == repositories.count)
        #expect(report.packages[0].errors == 1)
        #expect(report.packages[1].errors == 0)
        #expect(report.packages[2].state == .unmeasured)
        #expect(report.packages[2].reason?.contains("not materialized") == true)
        #expect(report.packages[0].advisories[0].disposition?.state == .remediation)
        #expect(report.packages[0].verification?.revision == Swift.String(repeating: "a", count: 40))
        #expect(report.packages[1].verification == nil)
        #expect(report.batches.count == 1)
        #expect(report.batches[0].rule == "PLAT-ARCH-022")
        #expect(report.batches[0].owner.identity == "swift-foundations/swift-linter")
        #expect(
            report.batches[0].repositories.map(\.identity) == [
                "swift-primitives/swift-alpha",
                "swift-primitives/swift-beta",
            ]
        )
        #expect(report.batches[0].findings == 2)
        #expect(report.status == 2)
        #expect(report.json.contains(#""state": "unknown""#))
        #expect(report.json.contains(#""terminal": true"#))
        #expect(report.description.contains("UNMEASURED  swift-standards/swift-gamma"))
        #expect(report.description.contains("PLAT-ARCH-022 · 1 · remediation"))
    }

    @Test
    func `complete measured evidence distinguishes errors from compliance`() throws {
        let disposition = try #require(
            Workspace.Lint.Ledger.Disposition(
                argument: "PLAT-ARCH-022=remediation@swift-foundations/swift-linter#20"
            )
        )
        let repositories = Array(Workspace.Lint.Ledger.Test.repositories.prefix(2))
        let noncompliant = try Workspace.Lint.Ledger.Report(
            repositories: repositories,
            report: Workspace.Lint.Ledger.Test.sweep(repositories: repositories),
            dispositions: [disposition],
            verifications: []
        )
        let compliantRepository = repositories[1]
        let compliant = try Workspace.Lint.Ledger.Report(
            repositories: [compliantRepository],
            report: Workspace.Lint.Ledger.Test.sweep(
                repositories: [compliantRepository]
            ),
            dispositions: [disposition],
            verifications: []
        )

        #expect(noncompliant.errors == 1)
        #expect(noncompliant.status == 1)
        #expect(compliant.errors == 0)
        #expect(compliant.status == 0)
    }

    @Test
    func `human and JSON encodings are deterministic across input order`() throws {
        let repositories = Workspace.Lint.Ledger.Test.repositories
        let disposition = try #require(
            Workspace.Lint.Ledger.Disposition(
                argument: "PLAT-ARCH-022=retention@swift-foundations/swift-linter#20"
            )
        )
        let forward = try Workspace.Lint.Ledger.Report(
            repositories: repositories,
            report: Workspace.Lint.Ledger.Test.sweep(repositories: repositories),
            dispositions: [disposition],
            verifications: []
        )
        let reverseSweep = Workspace.Lint.Ledger.Test.sweep(repositories: repositories)
        let reverse = try Workspace.Lint.Ledger.Report(
            repositories: Array(repositories.reversed()),
            report: .init(
                scope: .all,
                inventory: reverseSweep.inventory,
                unmaterialized: Array(reverseSweep.unmaterialized.reversed()),
                considered: reverseSweep.considered,
                measurements: Array(reverseSweep.measurements.reversed())
            ),
            dispositions: [disposition],
            verifications: []
        )

        #expect(forward.json == reverse.json)
        #expect(forward.description == reverse.description)
    }
}

extension Workspace.Lint.Ledger.Test.`Edge Case` {
    @Test
    func `an empty inventory is incomplete and exits nonzero`() throws {
        let report = try Workspace.Lint.Ledger.Report(
            repositories: [],
            report: .init(
                scope: .all,
                inventory: 0,
                unmaterialized: [],
                considered: 0,
                measurements: []
            ),
            dispositions: [],
            verifications: []
        )

        #expect(report.status == 2)
        #expect(report.json.contains(#""status": "incomplete""#))
        #expect(report.description.contains("lint residual ledger: incomplete — 0"))
        #expect(!report.description.contains("lint residual ledger: compliant"))
    }

    @Test
    func `a wholly unmaterialized inventory still emits every row`() throws {
        let repositories = Array(Workspace.Lint.Ledger.Test.repositories.prefix(2))
        let report = try Workspace.Lint.Ledger.Report(
            repositories: repositories,
            report: .init(
                scope: .all,
                inventory: repositories.count,
                unmaterialized: repositories.compactMap {
                    Workspace.Repository.Key(repository: $0)?.identity
                },
                considered: 0,
                measurements: []
            ),
            dispositions: [],
            verifications: []
        )

        #expect(report.packages.count == 2)
        #expect(report.packages.allSatisfy { $0.state == .unmeasured })
        #expect(report.status == 2)
    }

    @Test
    func `missing structured evidence is an explicit blocked row`() throws {
        let repository = Workspace.Lint.Ledger.Test.repositories[0]
        let key = try #require(Workspace.Repository.Key(repository: repository))
        let measurement = Workspace.Lint.Measurement(
            repository: key,
            package: "/tmp/swift-alpha",
            verdict: .clean,
            summary: .init(
                package: "swift-alpha",
                activeRules: 2,
                excludedRules: 0,
                filesLinted: 1,
                violations: 0
            ),
            plan: nil,
            findings: [],
            diagnostics: "",
            status: 0
        )
        let report = try Workspace.Lint.Ledger.Report(
            repositories: [repository],
            report: .init(
                scope: .all,
                inventory: 1,
                unmaterialized: [],
                considered: 1,
                measurements: [measurement]
            ),
            dispositions: [],
            verifications: []
        )

        #expect(report.packages[0].state == .unmeasured)
        #expect(report.packages[0].reason?.contains("swift-linter/issues/20") == true)
        #expect(report.packages[0].prerequisite == .sarif)
        #expect(report.blocked)
        #expect(report.status == 2)
    }

    @Test
    func `typed prerequisite state is independent of arbitrary reason prose`() throws {
        let typed = try Workspace.Lint.Ledger.Test.unmeasured(
            reason: "wording can change without changing machine state",
            prerequisite: .sarif
        )
        let prose = try Workspace.Lint.Ledger.Test.unmeasured(
            reason:
                "structured findings and \(Workspace.Lint.Ledger.Report.prerequisite) appear only "
                + "in arbitrary human prose",
            prerequisite: nil
        )

        #expect(typed.blocked)
        #expect(typed.packages[0].prerequisite == .sarif)
        #expect(typed.json.contains(#""kind": "sarif""#))
        #expect(typed.json.contains(#""state": "blocked""#))
        #expect(
            typed.description.contains(
                "prerequisite: sarif · \(Workspace.Lint.Ledger.Report.prerequisite)"
            )
        )
        #expect(!prose.blocked)
        #expect(prose.packages[0].prerequisite == nil)
        #expect(prose.json.contains(#""state": "satisfied""#))
    }

    @Test
    func `an advisory without a terminal disposition remains incomplete`() throws {
        let repositories = Array(Workspace.Lint.Ledger.Test.repositories.prefix(2))
        let report = try Workspace.Lint.Ledger.Report(
            repositories: repositories,
            report: Workspace.Lint.Ledger.Test.sweep(repositories: repositories),
            dispositions: [],
            verifications: []
        )

        #expect(report.unresolved == 2)
        #expect(report.status == 2)
        #expect(report.json.contains(#""state": "unresolved""#))
        #expect(report.json.contains(#""terminal": false"#))
    }
}

extension Workspace.Lint.Ledger.Test {
    fileprivate static let repositories = [
        Workspace.Repository(
            name: "swift-alpha",
            url: "https://github.com/swift-primitives/swift-alpha.git",
            organization: "swift-primitives",
            layer: .primitives
        ),
        Workspace.Repository(
            name: "swift-beta",
            url: "https://github.com/swift-primitives/swift-beta.git",
            organization: "swift-primitives",
            layer: .primitives
        ),
        Workspace.Repository(
            name: "swift-gamma",
            url: "https://github.com/swift-standards/swift-gamma.git",
            organization: "swift-standards",
            layer: .standards
        ),
    ]

    fileprivate static func sweep(
        repositories: [Workspace.Repository]
    ) -> Workspace.Lint.Report {
        let materialized = repositories.filter { $0.name != "swift-gamma" }
        let measurements = materialized.map { repository in
            guard let key = Workspace.Repository.Key(repository: repository) else {
                preconditionFailure("invalid repository fixture")
            }
            let findings =
                [
                    Workspace.Lint.Finding(
                        rule: "PLAT-ARCH-022",
                        severity: .warning,
                        message: "Advisory",
                        path: "Sources/Feature.swift",
                        line: 1,
                        column: 1
                    )
                ]
                + (repository.name == "swift-alpha"
                    ? [
                        Workspace.Lint.Finding(
                            rule: "IMPL-001",
                            severity: .error,
                            message: "Error",
                            path: "Sources/Feature.swift",
                            line: 2,
                            column: 1
                        )
                    ] : [])
            return Workspace.Lint.Measurement(
                repository: key,
                package: "/tmp/\(repository.name)",
                verdict: .violations(
                    count: findings.count,
                    failing: findings.contains { $0.severity.isError }
                ),
                summary: .init(
                    package: repository.name,
                    activeRules: 2,
                    excludedRules: 0,
                    filesLinted: 1,
                    violations: findings.count
                ),
                plan: nil,
                findings: [],
                structured: findings,
                diagnostics: "",
                status: findings.contains { $0.severity.isError } ? 1 : 0
            )
        }
        return .init(
            scope: .all,
            inventory: repositories.count,
            unmaterialized: repositories.filter { $0.name == "swift-gamma" }.compactMap {
                Workspace.Repository.Key(repository: $0)?.identity
            },
            considered: materialized.count,
            measurements: measurements
        )
    }

    fileprivate static func unmeasured(
        reason: Swift.String,
        prerequisite: Workspace.Lint.Prerequisite?
    ) throws -> Workspace.Lint.Ledger.Report {
        let repository = repositories[0]
        guard let key = Workspace.Repository.Key(repository: repository) else {
            preconditionFailure("invalid repository fixture")
        }
        let measurement = Workspace.Lint.Measurement(
            repository: key,
            package: "/tmp/swift-alpha",
            verdict: .unmeasured(reason: reason),
            summary: nil,
            plan: nil,
            findings: [],
            prerequisite: prerequisite,
            diagnostics: "",
            status: 2
        )
        return try .init(
            repositories: [repository],
            report: .init(
                scope: .all,
                inventory: 1,
                unmaterialized: [],
                considered: 1,
                measurements: [measurement]
            ),
            dispositions: [],
            verifications: []
        )
    }
}
