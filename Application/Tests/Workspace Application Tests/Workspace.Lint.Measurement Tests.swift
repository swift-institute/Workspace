import File_System
import Foundation
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

    /// An engine that refuses a run says why on standard error. The
    /// rendering must reproduce that account: a coordinator that
    /// swallowed `fix target-root channel is unset` turned a
    /// self-diagnosing refusal into a fleet-blocking mystery (#105).
    @Test
    func `an unmeasured rendering shows what the engine said`() {
        let refusal =
            "[Lint] error: fix target-root channel is unset; "
            + "target membership must be supplied by the package manifest"
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/whatever",
            status: 1,
            standardOutput: "",
            standardError: refusal
        )
        #expect(measurement.verdict.isUnmeasured)
        #expect(measurement.description.contains(refusal))
    }

    /// A measured run's standard error is its summary line, which the
    /// rendering already reproduces; repeating it verbatim would print
    /// every number twice.
    @Test
    func `a measured rendering does not repeat standard error`() {
        let measurement = Workspace.Lint.adjudicate(
            package: "/tmp/whatever",
            status: 0,
            standardOutput: "",
            standardError: "swift-quiet · 93 active rules · 17 files linted · 0 violations"
        )
        #expect(measurement.verdict == .clean)
        #expect(measurement.unmeasuredDiagnostics.isEmpty)
        #expect(
            measurement.description
                == "swift-quiet · 93 active rules · 17 files linted · 0 violations\nclean"
        )
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

    /// The configured dispatcher accepts exclusions only through its public
    /// fix invocation. This fixture records the argv at the process boundary,
    /// so a valid in-memory argument list cannot mask a rejected invocation.
    @Test
    func `a configured dry run passes target roots and exclusions through the fix CLI`() throws {
        let fixture = try FixProcessFixture()
        defer { fixture.remove() }

        let measurement = Workspace.Lint(hierarchy: fixture.package).measure(
            try .resolve(fixture.package.description),
            using: try fixture.installation(),
            default: nil,
            fix: .dryRun,
            excluding: ["PLAT-ARCH-022"]
        )

        #expect(measurement.verdict == .clean)
        #expect(
            try fixture.arguments() == [
                fixture.package.description,
                "--exit-policy", "strict",
                "--fix",
                "--dry-run",
                "--target-root", fixture.sources.description,
                "--fix-excluding", "PLAT-ARCH-022",
            ]
        )
        #expect(try fixture.format() == "text")
    }

    @Test
    func `a configured structured run passes SARIF through argv and environment`() throws {
        let fixture = try FixProcessFixture()
        defer { fixture.remove() }

        let measurement = Workspace.Lint(hierarchy: fixture.package).measure(
            try .resolve(fixture.package.description),
            using: try fixture.installation(),
            default: nil,
            format: .sarif
        )

        #expect(measurement.verdict == .clean)
        #expect(measurement.structured == [])
        #expect(
            try fixture.arguments() == [
                fixture.package.description,
                "--exit-policy", "strict",
                "--format", "sarif",
            ]
        )
        #expect(try fixture.format() == "sarif")
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

private struct FixProcessFixture {
    let base: URL
    let package: File.Directory
    let sources: File.Directory
    private let executable: File
    private let runner: File
    private let capture: File
    private let formatCapture: File

    init() throws {
        base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        package = try File.Directory(validating: base.appending(path: "swift-affine-algebra-primitives").path)
        sources = package[directory: "Sources"][directory: "Affine Algebra Primitives"]
        executable = package[directory: ".fixture"][file: "swift-linter"]
        runner = package[directory: ".fixture"][file: "swift-linter-runner"]
        capture = package[file: ".swift-linter-arguments"]
        formatCapture = package[file: ".swift-linter-format"]

        try sources.create.recursive()
        try package[file: "Package.swift"].write.atomic(
            """
            // swift-tools-version: 6.3
            import PackageDescription

            let package = Package(
                name: "swift-affine-algebra-primitives",
                targets: [.target(name: "Affine Algebra Primitives")]
            )
            """
        )
        try package[file: "Lint.swift"].write.atomic("// configured fixture\n")
        try sources[file: "Affine.swift"].write.atomic("public enum Affine {}\n")
        try executable.write.atomic(
            """
            #!/bin/sh
            printf '%s\\n' "$@" > .swift-linter-arguments
            printf '%s' "${SWIFT_LINTER_FORMAT:-}" > .swift-linter-format
            if [ "${SWIFT_LINTER_FORMAT:-}" = sarif ]; then
              printf '%s\\n' '{"version":"2.1.0","runs":[{"results":[]}]}'
            fi
            printf '%s\\n' 'swift-affine-algebra-primitives · 1 active rules · 1 files linted · 0 violations' >&2
            """
        )
        try File.System.Metadata.Permissions.set(.executable, at: executable.path)
        try runner.write.atomic("runner\n")
    }

    func installation() throws -> Workspace.Lint.Installation {
        .init(
            manifest: try .parse("digest=96", label: "fixture"),
            executable: executable,
            runner: runner
        )
    }

    func arguments() throws -> [Swift.String] {
        try Swift.String(contentsOfFile: capture.description, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(Swift.String.init)
    }

    func format() throws -> Swift.String {
        try Swift.String(contentsOfFile: formatCapture.description, encoding: .utf8)
    }

    func remove() {
        try? FileManager.default.removeItem(at: base)
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

    /// The sweep rendering owes each unmeasured package the same
    /// account the single-package rendering shows: the reason, then the
    /// engine's standard error verbatim.
    @Test
    func `the sweep rendering shows what the engine said for each unmeasured package`() {
        let refusal = "[Lint] error: fix target-root channel is unset"
        let unmeasured = Workspace.Lint.Measurement(
            package: "/tmp/pkg",
            verdict: .unmeasured(reason: "the engine emitted no run summary"),
            summary: nil,
            plan: nil,
            findings: [],
            diagnostics: refusal,
            status: 1
        )
        let report = Workspace.Lint.Report(
            scope: .all,
            inventory: 1,
            unmaterialized: [],
            considered: 1,
            measurements: [unmeasured]
        )
        #expect(report.description.contains(refusal))
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
