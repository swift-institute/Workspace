import Testing

@testable import Workspace_Application

@Suite
struct `Workspace Lint Allowlist Tests` {
    static func repository(_ name: Swift.String) -> Workspace.Repository {
        .init(
            name: name,
            url: "https://github.com/swift-primitives/\(name).git",
            organization: "swift-primitives",
            layer: .primitives
        )
    }

    static let listed = repository("swift-percent-primitives")
    static let configured = repository("swift-ascii-primitives")

    /// The property that answers the two-sources-of-truth objection.
    /// Without it, a package that gains a `Lint.swift` keeps its excuse
    /// forever and the allowlist silently stops describing reality.
    @Test
    func `an entry for a package that now has a configuration is an error`() {
        let allowlist = Workspace.Lint.Allowlist(
            unconfigured: ["swift-primitives/swift-percent-primitives"]
        )
        let findings = allowlist.diagnostics(
            against: [Self.listed],
            configured: { _ in true }
        )
        #expect(findings.count == 1)
        #expect(findings[0].contains("no longer needs"))
    }

    @Test
    func `an entry for a package still lacking a configuration is fine`() {
        let allowlist = Workspace.Lint.Allowlist(
            unconfigured: ["swift-primitives/swift-percent-primitives"]
        )
        #expect(
            allowlist.diagnostics(against: [Self.listed], configured: { _ in false }).isEmpty
        )
    }

    /// A typo, or a package renamed or removed, excuses nothing while
    /// looking like it excuses something.
    @Test
    func `an entry naming a package outside the inventory is an error`() {
        let allowlist = Workspace.Lint.Allowlist(
            unconfigured: ["swift-primitives/swift-does-not-exist"]
        )
        let findings = allowlist.diagnostics(
            against: [Self.listed],
            configured: { _ in false }
        )
        #expect(findings.count == 1)
        #expect(findings[0].contains("not in the inventory"))
    }

    @Test
    func `a duplicated entry is an error`() {
        let allowlist = Workspace.Lint.Allowlist(
            unconfigured: [
                "swift-primitives/swift-percent-primitives",
                "swift-primitives/swift-percent-primitives",
            ]
        )
        let findings = allowlist.diagnostics(
            against: [Self.listed],
            configured: { _ in false }
        )
        #expect(findings.contains { $0.contains("listed more than once") })
    }

    /// Every fault is reported at once. A list corrected one error per
    /// run is a list nobody finishes correcting.
    @Test
    func `all faults are reported together`() {
        let allowlist = Workspace.Lint.Allowlist(
            unconfigured: [
                "swift-primitives/swift-does-not-exist",
                "swift-primitives/swift-ascii-primitives",
            ]
        )
        let findings = allowlist.diagnostics(
            against: [Self.listed, Self.configured],
            configured: { $0 == Self.configured }
        )
        #expect(findings.count == 2)
    }

    @Test
    func `membership is by organization and name`() {
        let allowlist = Workspace.Lint.Allowlist(
            unconfigured: ["swift-primitives/swift-percent-primitives"]
        )
        #expect(allowlist.records(Self.listed))
        #expect(!allowlist.records(Self.configured))
    }
}

@Suite
struct `Workspace Lint Unconfigured Verdict Tests` {
    /// A recorded gap does not fail the sweep — that is the whole point
    /// of recording it — but it is never counted as coverage either.
    /// Folding it into `clean` would overstate what was measured.
    @Test
    func `a recorded gap does not fail and is not clean`() {
        let verdict = Workspace.Lint.Measurement.Verdict.unconfigured(recorded: "Lint.json")
        #expect(!verdict.fails)
        #expect(verdict != .clean)
        #expect(verdict.isUnconfigured)
        #expect(!verdict.isUnmeasured)
    }

    /// An unrecorded gap still fails. The allowlist removes chronic red,
    /// not the alarm.
    @Test
    func `an unrecorded gap still fails`() {
        let verdict = Workspace.Lint.Measurement.Verdict.unmeasured(reason: "no Lint.swift")
        #expect(verdict.fails)
    }

    @Test
    func `a sweep of only recorded gaps exits zero`() {
        let report = Workspace.Lint.Report(
            scope: .all,
            inventory: 2,
            unmaterialized: [],
            considered: 2,
            measurements: [
                .init(
                    package: "/tmp/a",
                    verdict: .unconfigured(recorded: "Lint.json"),
                    summary: nil,
                    findings: [],
                    diagnostics: "",
                    status: 0
                )
            ]
        )
        #expect(report.status == 0)
        #expect(report.unconfigured.count == 1)
        #expect(report.clean.isEmpty)
        #expect(report.filesLinted == 0)
    }
}
