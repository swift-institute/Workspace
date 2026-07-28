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
    ])
    func `refuses lines that are not the engine's summary`(line: Swift.String) {
        #expect(Workspace.Lint.Summary.parse(line) == nil)
    }
}
