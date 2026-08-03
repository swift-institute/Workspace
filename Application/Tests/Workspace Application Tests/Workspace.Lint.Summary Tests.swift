import Testing

@testable import Workspace_Application

@Suite
struct `Workspace Lint Summary Tests` {
    /// The line below is a verbatim capture from the released macOS
    /// binary run against `swift-foundations/swift-github`, not a
    /// reconstruction from the reporter's source. A parser tested only
    /// against strings its author invented proves that the author is
    /// self-consistent.
    @Test
    func `parses a captured run summary`() throws {
        let summary = try #require(
            Workspace.Lint.Summary.parse(
                "swift-github · 93 active rules · 56 files linted · 10 violations\n"
            )
        )
        #expect(summary.package == "swift-github")
        #expect(summary.activeRules == 93)
        #expect(summary.excludedRules == 0)
        #expect(summary.filesLinted == 56)
        #expect(summary.violations == 10)
        // The engine that emitted this line predates swift-linter PR #24,
        // so it never reported a findings count — `nil`, not `0`.
        #expect(summary.findings == nil)
    }

    /// swift-foundations/swift-linter PR #24 (Refs #22) appends a fifth
    /// `<N> findings` field to the summary line. A machine carrying a
    /// #24-built engine must not read every package on it as UNMEASURED
    /// the moment that engine installs (swift-institute/Workspace#106) —
    /// the fleet-wide version of the skew #105 already produced once.
    @Test
    func `parses the swift-linter PR #24 five-field form`() throws {
        let summary = try #require(
            Workspace.Lint.Summary.parse(
                "swift-github · 93 active rules · 56 files linted · 10 violations · 12 findings\n"
            )
        )
        #expect(summary.package == "swift-github")
        #expect(summary.activeRules == 93)
        #expect(summary.excludedRules == 0)
        #expect(summary.filesLinted == 56)
        #expect(summary.violations == 10)
        #expect(summary.findings == 12)
    }

    /// The five-field form composes with the pre-existing excluded-rules
    /// clause — the two extensions are independent and must not
    /// interfere with each other's parse.
    @Test
    func `parses the five-field form with excluded rules`() throws {
        let summary = try #require(
            Workspace.Lint.Summary.parse(
                "swift-standard-library-extensions · 95 active rules (−1 excluded) · "
                    + "12 files linted · 3 violations · 9 findings"
            )
        )
        #expect(summary.activeRules == 95)
        #expect(summary.excludedRules == 1)
        #expect(summary.violations == 3)
        #expect(summary.findings == 9)
    }

    /// The five-field form singularises `finding` exactly as the other
    /// three counted fields do.
    @Test
    func `parses the five-field form's singular finding`() throws {
        let summary = try #require(
            Workspace.Lint.Summary.parse(
                "swift-tiny · 4 active rules · 1 file linted · 1 violation · 1 finding"
            )
        )
        #expect(summary.violations == 1)
        #expect(summary.findings == 1)
    }

    @Test
    func `parses the excluded-rules variant`() throws {
        let summary = try #require(
            Workspace.Lint.Summary.parse(
                "swift-standard-library-extensions · 95 active rules (−1 excluded) · "
                    + "12 files linted · 3 violations"
            )
        )
        #expect(summary.activeRules == 95)
        #expect(summary.excludedRules == 1)
    }

    /// The engine singularises its nouns, so a parser keyed to the
    /// plural silently fails on exactly the packages with the least to
    /// report — and a failed parse is an UNMEASURED verdict, which would
    /// make one-violation packages look broken.
    @Test
    func `parses singular nouns`() throws {
        let summary = try #require(
            Workspace.Lint.Summary.parse("swift-tiny · 4 active rules · 1 file linted · 1 violation")
        )
        #expect(summary.filesLinted == 1)
        #expect(summary.violations == 1)
    }

    @Test
    func `finds the summary among other stderr output`() throws {
        let summary = try #require(
            Workspace.Lint.Summary.parse(
                """
                [swift-linter] warning: something happened
                swift-ascii-primitives · 96 active rules · 35 files linted · 127 violations
                """
            )
        )
        #expect(summary.package == "swift-ascii-primitives")
    }

    /// This is the case that matters most: all three silent-zero
    /// invocations produce exactly this — nothing.
    @Test
    func `reports no summary for empty output`() {
        #expect(Workspace.Lint.Summary.parse("") == nil)
    }

    @Test(arguments: [
        "swift-github · 93 active rules · 56 files linted",
        "swift-github - 93 active rules - 56 files linted - 10 violations",
        "swift-github · many active rules · 56 files linted · 10 violations",
        "swift-github · 93 rules · 56 files linted · 10 violations",
        "swift-github · 93 active rules · 56 files · 10 violations",
        "swift-github · 93 active rules · 56 files linted · 10 findings",
        " · 93 active rules · 56 files linted · 10 violations",
        // Five fields, but not the PR #24 shape: a sixth field, a
        // non-numeric findings count, the wrong trailing noun, and the
        // violations/findings fields swapped. Tolerating the new field
        // count must not widen into tolerating garbage in it.
        "swift-github · 93 active rules · 56 files linted · 10 violations · 12 findings · extra",
        "swift-github · 93 active rules · 56 files linted · 10 violations · many findings",
        "swift-github · 93 active rules · 56 files linted · 10 violations · 12 issues",
        "swift-github · 93 active rules · 56 files linted · 10 findings · 12 violations",
    ])
    func `refuses lines that are not the engine's summary`(line: Swift.String) {
        #expect(Workspace.Lint.Summary.parse(line) == nil)
    }
}
