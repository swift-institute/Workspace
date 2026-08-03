extension Workspace.Lint {
    /// The engine's always-on run summary, parsed.
    ///
    /// The engine emits one line to **standard error** at the end of
    /// every configured run, on both the prebuilt-runner path and the
    /// per-invocation eval path. Two wire forms are in circulation:
    ///
    /// ```
    /// swift-github · 93 active rules · 56 files linted · 10 violations
    /// swift-github · 93 active rules · 56 files linted · 10 violations · 12 findings
    /// ```
    ///
    /// The four-field form is every engine through
    /// swift-foundations/swift-linter#22; the five-field form, with the
    /// trailing `<N> findings` count, is swift-linter PR #24 and every
    /// engine after it. Both are accepted so that installing a #24-built
    /// engine before every consumer has adopted the new field does not
    /// read as UNMEASURED (swift-institute/Workspace#106) — the failure
    /// mode #105 already produced once, from a narrower skew. `findings`
    /// is `nil` when the engine that produced the line predates #24;
    /// consuming it for ledger parity is #104, not here.
    ///
    /// Both forms carry an optional `(−N excluded)` clause after the
    /// rule count when the consumer excludes rules from its bundle.
    ///
    /// ## Why this line is load-bearing
    ///
    /// This is the only positive control the tool offers. Exit status
    /// cannot serve: three distinct misconfigurations — a directory
    /// with no `Lint.swift`, a file path rather than a package root, and
    /// an empty directory — each exit zero having emitted nothing at
    /// all. A caller that trusts the exit code reports those three as
    /// clean.
    ///
    /// Absence of this line is therefore not a formatting inconvenience;
    /// it is the signal that nothing was measured, and
    /// ``Workspace/Lint/Measurement`` treats it as one.
    public struct Summary: Equatable, Sendable {
        /// The package name the engine reported, as it printed it.
        public let package: Swift.String

        /// Rules active after bundle composition and any exclusions —
        /// what actually ran, not what was declared.
        public let activeRules: Swift.Int

        /// Rules the consumer excluded from its bundle.
        public let excludedRules: Swift.Int

        /// Source files the engine actually visited.
        public let filesLinted: Swift.Int

        /// Findings emitted, at every severity.
        public let violations: Swift.Int

        /// The total surfaced-finding count, present only on the
        /// swift-linter PR #24 five-field wire form.
        ///
        /// `nil` on the four-field form — not zero, which would claim a
        /// clean-findings run the engine never reported.
        public let findings: Swift.Int?

        public init(
            package: Swift.String,
            activeRules: Swift.Int,
            excludedRules: Swift.Int,
            filesLinted: Swift.Int,
            violations: Swift.Int,
            findings: Swift.Int? = nil
        ) {
            self.package = package
            self.activeRules = activeRules
            self.excludedRules = excludedRules
            self.filesLinted = filesLinted
            self.violations = violations
            self.findings = findings
        }
    }
}

extension Workspace.Lint.Summary {
    /// The separator the engine writes between summary fields.
    ///
    /// A middle dot, not a hyphen: matched exactly, because a loose
    /// match risks accepting a line the engine did not write.
    static let separator: Swift.Character = "·"

    /// Finds and parses the summary line in a captured stderr stream.
    ///
    /// Returns `nil` when no line in `text` has the summary's shape —
    /// which is the answer for every unconfigured invocation, since
    /// those emit nothing whatsoever.
    ///
    /// Scans every line rather than assuming position: the engine writes
    /// its own diagnostics to the same stream, and a summary preceded by
    /// a warning must still be found.
    public static func parse(_ text: Swift.String) -> Self? {
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let summary = Self.parse(line: line) {
                return summary
            }
        }
        return nil
    }

    /// Parses either the four-field (pre-#24) or five-field
    /// (swift-linter PR #24) wire form; any other field count is
    /// refused rather than guessed at.
    static func parse(line: Swift.Substring) -> Self? {
        let fields = line.split(separator: Self.separator, omittingEmptySubsequences: false)
        guard fields.count == 4 || fields.count == 5 else { return nil }

        let package = Workspace.Lint.trimmed(fields[0])
        guard !package.isEmpty else { return nil }

        guard
            let rules = Self.rules(Workspace.Lint.trimmed(fields[1])),
            let files = Self.count(Workspace.Lint.trimmed(fields[2]), unit: "linted"),
            let violations = Self.count(
                Workspace.Lint.trimmed(fields[3]),
                singular: "violation",
                plural: "violations"
            )
        else {
            return nil
        }

        let findings: Swift.Int?
        if fields.count == 5 {
            guard
                let parsedFindings = Self.count(
                    Workspace.Lint.trimmed(fields[4]),
                    singular: "finding",
                    plural: "findings"
                )
            else {
                return nil
            }
            findings = parsedFindings
        } else {
            findings = nil
        }

        return .init(
            package: package,
            activeRules: rules.active,
            excludedRules: rules.excluded,
            filesLinted: files,
            violations: violations,
            findings: findings
        )
    }

    /// Parses `N active rules` or `N active rules (−M excluded)`.
    ///
    /// The excluded clause carries a Unicode minus sign, not a hyphen;
    /// the count is taken from the digits regardless, so the parse does
    /// not hinge on which one the engine emits.
    static func rules(_ field: Swift.String) -> (active: Swift.Int, excluded: Swift.Int)? {
        let words = field.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count >= 3, words[1] == "active", words[2] == "rules" else {
            return nil
        }
        guard let active = Swift.Int(words[0]) else { return nil }
        guard words.count > 3 else { return (active: active, excluded: 0) }

        // `(−M` then `excluded)`.
        guard
            words.count == 5,
            words[4] == "excluded)",
            let excluded = Swift.Int(words[3].filter(\.isNumber))
        else {
            return nil
        }
        return (active: active, excluded: excluded)
    }

    /// Parses `N files linted` / `N file linted`.
    ///
    /// The engine singularises the noun, so only the trailing `unit`
    /// keyword (`linted`) is matched literally; the leading integer and
    /// the field width are what identify the field otherwise.
    static func count(_ field: Swift.String, unit: Swift.String) -> Swift.Int? {
        let words = field.split(separator: " ", omittingEmptySubsequences: true)
        guard let first = words.first, let value = Swift.Int(first) else { return nil }
        guard words.count == 3, words.last == unit[...] else { return nil }
        return value
    }

    /// Parses a bare `N <plural>` / `N <singular>` field — `N
    /// violations` / `N violation`, or `N findings` / `N finding`.
    ///
    /// The engine singularises the noun, so both forms of the keyword
    /// must be accepted; the caller names which noun this field is, so
    /// a `violations` field can never be mistaken for a `findings` one.
    static func count(_ field: Swift.String, singular: Swift.String, plural: Swift.String) -> Swift.Int? {
        let words = field.split(separator: " ", omittingEmptySubsequences: true)
        guard let first = words.first, let value = Swift.Int(first) else { return nil }
        guard words.count == 2, words[1] == plural[...] || words[1] == singular[...] else { return nil }
        return value
    }
}
