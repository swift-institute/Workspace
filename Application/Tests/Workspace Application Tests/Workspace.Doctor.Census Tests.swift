import Testing

@testable import Workspace_Application

// MARK: - Working-state census (W3)

extension Workspace.Doctor.Test.Unit {
    private static func census(
        head: Workspace.Doctor.Census.Head = .branch("main"),
        upstream: Swift.String = "origin/main",
        ahead: Int = 0,
        behind: Int = 0,
        dirty: Int = 0,
        untracked: Int = 0,
        resolved: Workspace.Doctor.Census.Resolved = .ignored
    ) -> Workspace.Doctor.Census {
        .init(
            name: "swift-example",
            url: "https://example.com/swift-example.git",
            origin: "https://example.com/swift-example.git",
            head: head,
            upstream: upstream,
            ahead: ahead,
            behind: behind,
            dirty: dirty,
            untracked: untracked,
            resolved: resolved
        )
    }

    @Test
    func `a clean repository on main with an ignored resolved state measures ok`() {
        let outcome = Workspace.Doctor.census.run(population: [Self.census()], inventory: 1)

        #expect(outcome.result == .ok(population: 1))
    }

    /// Deliberately a warning. `doctor` does not fetch, so this compares
    /// against a remote-tracking ref of unknown age; erroring on it blocks a
    /// checkout on a divergence that a `git fetch` may show does not exist.
    @Test
    func `divergence from the resolved upstream is a warning naming the staleness`() {
        let outcome = Workspace.Doctor.census.run(
            population: [Self.census(ahead: 1, behind: 2)],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .warning, population: 1))
        #expect(outcome.findings.contains { $0.message.contains("diverges") })
        // The reader has to be told the measurement is against a cache, or
        // they cannot tell a phantom from a real one.
        #expect(outcome.findings.contains { $0.message.contains("may be stale") })
        #expect(outcome.findings.allSatisfy { $0.severity != .error })
    }

    @Test
    func `dirty entries, untracked entries, and a feature branch are warnings that never raise the exit`() {
        let outcome = Workspace.Doctor.census.run(
            population: [
                Self.census(head: .branch("feature/x"), dirty: 3, untracked: 2)
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .warning, population: 1))
        #expect(outcome.findings.count == 3)
        #expect(outcome.findings.allSatisfy { $0.severity == .warning })
        #expect(outcome.findings.contains { $0.message.contains("3 dirty entries") })
        #expect(outcome.findings.contains { $0.message.contains("2 untracked entries") })
        #expect(Workspace.Doctor.Report(outcomes: [outcome]).status == 0)
    }

    @Test
    func `a detached HEAD is a warning`() {
        let outcome = Workspace.Doctor.census.run(
            population: [Self.census(head: .detached)],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .warning, population: 1))
        #expect(outcome.findings.contains { $0.message.contains("HEAD is detached") })
    }

    @Test
    func `an exposed resolved-state file is a warning naming it generated state`() {
        let outcome = Workspace.Doctor.census.run(
            population: [Self.census(resolved: .exposed)],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .warning, population: 1))
        #expect(outcome.findings.contains { $0.message.contains("never commit it") })
    }

    @Test
    func `an absent resolved-state file is not a finding`() {
        let outcome = Workspace.Doctor.census.run(
            population: [Self.census(resolved: .absent)],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
    }

    @Test
    func `a census reading zero repositories against a non-empty inventory is unmeasured`() {
        let outcome = Workspace.Doctor.census.run(population: [], inventory: 4)

        #expect(outcome.result == .unmeasured(reason: "empty population against an inventory of 4"))
    }
}

// MARK: - Stale-pin sub-check (W3)

extension Workspace.Doctor.Test.Unit {
    @Test
    func `a stale pin warns, naming the dependency, the pinned revision, the tip, and re-resolution`() {
        let outcome = Workspace.Doctor.pins.run(
            population: [
                .init(
                    package: "swift-example",
                    dependency: "swift-json",
                    branch: "main",
                    pinned: "0000000000000000000000000000000000000000",
                    tip: "1111111111111111111111111111111111111111"
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .warning, population: 1))
        let message = outcome.findings.first?.message ?? ""
        #expect(message.contains("swift-json"))
        #expect(message.contains("000000000000"))
        #expect(message.contains("111111111111"))
        #expect(message.contains("re-resolve"))
        #expect(message.contains("never hand-edit"))
    }

    @Test
    func `a pin at its branch tip is not a finding`() {
        let outcome = Workspace.Doctor.pins.run(
            population: [
                .init(
                    package: "swift-example",
                    dependency: "swift-json",
                    branch: "main",
                    pinned: "0000000000000000000000000000000000000000",
                    tip: "0000000000000000000000000000000000000000"
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
    }

    @Test
    func `parsing resolved state yields branch pins and passes over version pins`() throws {
        let records = try Workspace.Doctor.Pin.Record.parse(Self.resolved)

        #expect(records.count == 1)
        #expect(records.first?.dependency == "swift-json")
        #expect(records.first?.location == "https://github.com/swift-foundations/swift-json.git")
        #expect(records.first?.branch == "main")
        #expect(records.first?.revision == "0000000000000000000000000000000000000000")
    }

    @Test
    func `resolved state without a pins array is unparseable, never an empty result`() {
        #expect(throws: Workspace.Error.self) {
            try Workspace.Doctor.Pin.Record.parse(#"{"version": 3}"#)
        }
    }

    static let resolved = #"""
        {
          "originHash" : "0f00",
          "pins" : [
            {
              "identity" : "swift-json",
              "kind" : "remoteSourceControl",
              "location" : "https://github.com/swift-foundations/swift-json.git",
              "state" : {
                "branch" : "main",
                "revision" : "0000000000000000000000000000000000000000"
              }
            },
            {
              "identity" : "swift-syntax",
              "kind" : "remoteSourceControl",
              "location" : "https://github.com/swiftlang/swift-syntax.git",
              "state" : {
                "revision" : "2222222222222222222222222222222222222222",
                "version" : "602.0.0"
              }
            }
          ],
          "version" : 3
        }
        """#
}

extension Workspace.Doctor.Test.Integration {
    private static let repository = Workspace.Repository(
        name: "swift-example",
        url: "https://github.com/swift-foundations/swift-example.git",
        organization: "swift-foundations",
        layer: .foundations
    )

    @Test
    func `a repository whose state cannot be read is unmeasured, never folded into clean`()
        async throws
    {
        let fixture = try Workspace.Doctor.Fixture(repositories: [Self.repository])
        defer { fixture.remove() }
        try Workspace.Xcode.write([Self.repository], at: fixture.directory)
        try fixture.materialize("swift-example")

        let report = await fixture.doctor().run()

        #expect(report.status == 2)
        let census = report.outcomes.first { $0.check == "working-state" }
        guard case .unmeasured(let reason) = census?.result else {
            Issue.record("expected unmeasured, got \(String(describing: census?.result))")
            return
        }
        #expect(reason.contains("swift-example"))
    }

    @Test
    func `a stale pin is measured through the checkout and warns`() async throws {
        let fixture = try Workspace.Doctor.Fixture(repositories: [Self.repository])
        defer { fixture.remove() }
        try fixture.materialize("swift-example")
        try fixture.write(
            Workspace.Doctor.Test.Unit.resolved,
            to: "swift-foundations/swift-example/Package.resolved"
        )

        let report = await fixture.doctor(tool: {
            (executable, arguments) throws(Workspace.Error) -> Swift.String in
            if executable == "git", arguments.first == "ls-remote" {
                return "1111111111111111111111111111111111111111\trefs/heads/main\n"
            }
            return Workspace.Doctor.Fixture.interrogation(executable, arguments)
        }).run()

        let pins = report.outcomes.first { $0.check == "resolved-pins" }
        #expect(pins?.result == .finding(severity: .warning, population: 1))
        #expect(pins?.findings.contains { $0.message.contains("swift-json") } == true)
    }

    @Test
    func `pins without the network are unmeasured, never fresh`() async throws {
        let fixture = try Workspace.Doctor.Fixture(repositories: [Self.repository])
        defer { fixture.remove() }
        try fixture.materialize("swift-example")
        try fixture.write(
            Workspace.Doctor.Test.Unit.resolved,
            to: "swift-foundations/swift-example/Package.resolved"
        )

        let report = await fixture.doctor(tool: {
            (executable, arguments) throws(Workspace.Error) -> Swift.String in
            if executable == "git", arguments.first == "ls-remote" {
                throw .process("could not resolve host")
            }
            return Workspace.Doctor.Fixture.interrogation(executable, arguments)
        }).run()

        #expect(report.status == 2)
        let pins = report.outcomes.first { $0.check == "resolved-pins" }
        guard case .unmeasured(let reason) = pins?.result else {
            Issue.record("expected unmeasured, got \(String(describing: pins?.result))")
            return
        }
        #expect(reason.contains("never fresh"))
    }

    @Test
    func `no resolved state anywhere is a proven zero, not a failure`() async throws {
        let fixture = try Workspace.Doctor.Fixture(repositories: [Self.repository])
        defer { fixture.remove() }
        try fixture.materialize("swift-example")

        let report = await fixture.doctor().run()

        let pins = report.outcomes.first { $0.check == "resolved-pins" }
        #expect(pins?.result == .ok(population: 0))
    }
}
