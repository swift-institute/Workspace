import File_System
import Testing

@testable import Workspace_Application

/// The UNMEASURED guard, exercised at the adjudication boundary.
///
/// These cover the decision; they do not cover the whole path. A rule
/// that passes a fixture and fails through the real base is the failure
/// mode this fleet has already shipped once, so the three silent-zero
/// invocations are also driven end to end through the built executable —
/// see the acceptance record in `Research`.
@Suite
struct `Workspace Lint Measurement Tests` {
    static let summary =
        "swift-github · 93 active rules · 56 files linted · 10 violations"

    /// Exit zero with no output at all. Produced by a directory with no
    /// `Lint.swift`, by a file path, and by an empty directory — the
    /// three invocations that make exit status useless as a control.
    @Test
    func `silence is unmeasured, never clean`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/whatever",
            status: 0,
            standardOutput: "",
            standardError: ""
        )
        #expect(measurement.verdict.isUnmeasured)
        #expect(measurement.verdict.fails)
        #expect(measurement.verdict != .clean)
    }

    @Test
    func `zero active rules is unmeasured`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/whatever",
            status: 0,
            standardOutput: "",
            standardError: "swift-empty · 0 active rules · 12 files linted · 0 violations"
        )
        #expect(measurement.verdict.isUnmeasured)
    }

    @Test
    func `zero files linted is unmeasured`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/whatever",
            status: 0,
            standardOutput: "",
            standardError: "swift-empty · 93 active rules · 0 files linted · 0 violations"
        )
        #expect(measurement.verdict.isUnmeasured)
    }

    @Test
    func `rules over files with nothing found is clean`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/whatever",
            status: 0,
            standardOutput: "",
            standardError: "swift-quiet · 93 active rules · 17 files linted · 0 violations"
        )
        #expect(measurement.verdict == .clean)
        #expect(!measurement.verdict.fails)
    }

    /// Under `--exit-policy strict` the engine exits non-zero exactly
    /// when a finding carries `error` severity. A non-zero exit
    /// accompanied by a valid summary is therefore a real result, not a
    /// tool failure — collapsing the two would turn every gating
    /// violation into an UNMEASURED.
    @Test
    func `warnings are measured and do not fail`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/whatever",
            status: 0,
            standardOutput: "a.swift:1:1: warning: something",
            standardError: Self.summary
        )
        #expect(measurement.verdict == .violations(count: 10, failing: false))
        #expect(!measurement.verdict.fails)
    }

    @Test
    func `error severity fails`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/whatever",
            status: 1,
            standardOutput: "a.swift:1:1: error: something",
            standardError: Self.summary
        )
        #expect(measurement.verdict == .violations(count: 10, failing: true))
        #expect(measurement.verdict.fails)
    }

    @Test
    func `a fix summary retains its active-rule file control and exact rule plan`() throws {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/pkg",
            status: 0,
            standardOutput: """
                --- /tmp/pkg/Sources/Feature.swift
                +++ /tmp/pkg/Sources/Feature.swift
                @@ -1,1 +1,1 @@ IMPL-033, PLAT-ARCH-021
                -let old = 1
                +let new = 1
                """,
            standardError: "swift-pkg · 93 active rules · 12 files linted · 1 violation",
            fix: .dryRun
        )

        let plan = try #require(measurement.plan)
        #expect(measurement.summary?.activeRules == 93)
        #expect(measurement.summary?.filesLinted == 12)
        #expect(plan.rules == ["IMPL-033", "PLAT-ARCH-021"])
        #expect(plan.sites(for: "IMPL-033") == ["/tmp/pkg/Sources/Feature.swift"])
        #expect(plan.sites(for: "PLAT-ARCH-021") == ["/tmp/pkg/Sources/Feature.swift"])
    }

    @Test
    func `a fix summary without every reported rewrite site is unmeasured`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/pkg",
            status: 0,
            standardOutput: "",
            standardError: "swift-pkg · 93 active rules · 12 files linted · 1 violation",
            fix: .dryRun
        )

        #expect(measurement.verdict.isUnmeasured)
        #expect(measurement.plan == nil)
    }

    /// A file's findings are narrowed out of the package's; the
    /// package's verdict is not recomputed. A file with no findings
    /// inside a failing package has not been shown to be clean, and
    /// saying so would be the same lie in miniature.
    @Test
    func `restricting to a file narrows findings but keeps the verdict`() throws {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/pkg",
            status: 1,
            standardOutput: """
                /tmp/pkg/Sources/A.swift:1:1: error: one
                /tmp/pkg/Sources/B.swift:2:1: error: two
                """,
            standardError: Self.summary
        )
        let narrowed = measurement.restricted(to: try File.Path("/tmp/pkg/Sources/A.swift"))
        #expect(narrowed.findings.count == 1)
        #expect(narrowed.verdict == measurement.verdict)
    }
}

@Suite
struct `Workspace Lint Report Tests` {
    static func measurement(_ verdict: Workspace.Lint.Measurement.Verdict) -> Workspace.Lint.Measurement {
        .init(
            package: "/tmp/pkg",
            verdict: verdict,
            summary: .init(
                package: "pkg",
                activeRules: 93,
                excludedRules: 0,
                filesLinted: 10,
                violations: 0
            ),
            plan: nil,
            findings: [],
            diagnostics: "",
            status: 0
        )
    }

    /// An unmeasured package outranks a violation. A violation is a fact
    /// about the code; an unmeasured package is the absence of any fact,
    /// and a sweep that reported it as the lesser result would let one
    /// unscanned package hide behind another package's findings.
    @Test
    func `unmeasured outranks violations in the exit status`() {
        let report = Workspace.Lint.Report(
            scope: .all,
            inventory: 3,
            unmaterialized: [],
            considered: 3,
            measurements: [
                Self.measurement(.clean),
                Self.measurement(.violations(count: 2, failing: true)),
                Self.measurement(.unmeasured(reason: "no summary")),
            ]
        )
        #expect(report.status == 2)
        #expect(report.unmeasured.count == 1)
        #expect(report.clean.count == 1)
        #expect(report.violations.count == 1)
    }

    @Test
    func `error severity alone exits one`() {
        let report = Workspace.Lint.Report(
            scope: .all,
            inventory: 2,
            unmaterialized: [],
            considered: 2,
            measurements: [
                Self.measurement(.clean),
                Self.measurement(.violations(count: 2, failing: true)),
            ]
        )
        #expect(report.status == 1)
    }

    @Test
    func `advisory findings alone exit zero`() {
        let report = Workspace.Lint.Report(
            scope: .all,
            inventory: 1,
            unmaterialized: [],
            considered: 1,
            measurements: [Self.measurement(.violations(count: 9, failing: false))]
        )
        #expect(report.status == 0)
    }

    /// The sweep-scale half of the positive control. A report naming
    /// hundreds of clean packages over a handful of files has measured
    /// almost nothing, and the count is what makes that legible.
    @Test
    func `reports the files actually visited`() {
        let report = Workspace.Lint.Report(
            scope: .all,
            inventory: 2,
            unmaterialized: [],
            considered: 2,
            measurements: [Self.measurement(.clean), Self.measurement(.clean)]
        )
        #expect(report.filesLinted == 20)
    }

    @Test
    func `a fix report renders every active-rule file summary and groups sites by rule`() {
        let measured = Workspace.Lint.Measurement(
            package: "/tmp/pkg",
            verdict: .violations(count: 1, failing: false),
            summary: .init(
                package: "pkg",
                activeRules: 93,
                excludedRules: 0,
                filesLinted: 12,
                violations: 1
            ),
            plan: .init(sites: [
                .init(path: "/tmp/pkg/Sources/Feature.swift", rules: ["IMPL-033", "PLAT-ARCH-021"])
            ]),
            findings: [],
            diagnostics: "",
            status: 0
        )
        let report = Workspace.Lint.Report(
            scope: .all,
            inventory: 1,
            unmaterialized: [],
            considered: 1,
            measurements: [measured],
            fix: .dryRun
        )

        let text = report.description
        #expect(text.contains("/tmp/pkg · 93 active rules · 12 files linted · 1 rewrite site"))
        #expect(text.contains("      IMPL-033\n        /tmp/pkg/Sources/Feature.swift"))
        #expect(text.contains("      PLAT-ARCH-021\n        /tmp/pkg/Sources/Feature.swift"))
    }
}
