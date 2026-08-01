internal import Standard_Library_Extensions

extension Workspace.Lint.Fix {
    /// The engine's exact, parseable dry-run publication plan.
    ///
    /// A fixer reports unified diffs on standard output. Each diff hunk names
    /// the rule or rules that contributed its rewrite, which is the engine's
    /// only source of truth for a rule-to-site plan. Workspace preserves that
    /// boundary rather than attempting to derive sites from findings or from
    /// the source tree after the run.
    public struct Plan: Equatable, Sendable {
        /// One planned source-file replacement.
        public struct Site: Equatable, Sendable {
            /// The exact file the engine would replace.
            public let path: Swift.String

            /// The canonical rules contributing to this replacement.
            public let rules: [Swift.String]

            public init(path: Swift.String, rules: [Swift.String]) {
                self.path = path
                self.rules = rules
            }
        }

        /// Every exact source-file replacement in engine output order.
        public let sites: [Site]

        public init(sites: [Site]) {
            self.sites = sites
        }
    }
}

extension Workspace.Lint.Fix.Plan {
    /// Parses the engine's unified-diff publication plan.
    ///
    /// A fix summary's final count is the number of changed files. Requiring
    /// this parse to account for that exact count prevents a report from
    /// describing a non-empty safe plan without naming every rewrite site.
    static func parse(_ text: Swift.String, changes: Swift.Int) -> Self? {
        guard changes >= 0 else { return nil }
        guard changes > 0 else {
            return text.split(separator: "\n", omittingEmptySubsequences: true).isEmpty
                ? .init(sites: [])
                : nil
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var sites = [Site]()
        var index = 0
        while index < lines.count {
            guard lines[index].hasPrefix("--- "), index + 2 < lines.count else { return nil }
            let original = Swift.String(lines[index].dropFirst(4))
            guard lines[index + 1].hasPrefix("+++ ") else { return nil }
            let path = Swift.String(lines[index + 1].dropFirst(4))
            guard path == original, lines[index + 2].hasPrefix("@@ ") else { return nil }

            var hunk = lines[index + 2].dropFirst(3)
            guard let closing = hunk.range(of: "@@") else { return nil }
            hunk = hunk[closing.upperBound...]
            let rules = hunk
                .split(separator: ",", omittingEmptySubsequences: false)
                .map(Workspace.Lint.trimmed)
            guard !rules.isEmpty, rules.allSatisfy({ !$0.isEmpty }) else { return nil }
            sites.append(.init(path: path, rules: rules))

            index += 3
            while index < lines.count, !lines[index].hasPrefix("--- ") {
                index += 1
            }
        }
        guard sites.count == changes else { return nil }
        return .init(sites: sites)
    }

    /// The rules with one or more exact rewrite sites, sorted for stable
    /// report rendering.
    var rules: [Swift.String] {
        Swift.Set(sites.flatMap(\.rules)).sorted()
    }

    /// Exact planned rewrite sites for `rule`, in engine output order.
    func sites(for rule: Swift.String) -> [Swift.String] {
        sites.filter { $0.rules.contains(rule) }.map(\.path)
    }
}
