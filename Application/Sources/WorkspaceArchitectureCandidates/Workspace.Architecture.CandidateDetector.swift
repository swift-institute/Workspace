public import WorkspaceArchitectureModel

extension Workspace.Architecture {
    /// Advisory detection of possible concept overlap.
    ///
    /// Similar names are a prompt for a human, never an identity: two
    /// facts are the same concept only when their concept identifiers
    /// match, and this detector reports name-similar groups precisely
    /// because their identifiers differ.
    public struct CandidateDetector: Sendable {
        public init() {}
    }
}

extension Workspace.Architecture.CandidateDetector {
    /// Groups facts whose normalised name stem coincides while their
    /// concept identifiers differ.
    public func detect(in facts: [Workspace.Architecture.Fact]) -> [Candidate] {
        var groups: [Swift.String: [Workspace.Architecture.Fact]] = [:]
        for fact in facts {
            groups[Self.stem(of: fact.owner.name), default: []].append(fact)
        }
        return groups
            .filter { (_, members) in
                members.count > 1
                    && Swift.Set(members.map(\.concept.identifier)).count > 1
            }
            .map { (stem, members) in
                .init(
                    stem: stem,
                    owners: members.map(\.owner).sorted(),
                    concepts: members.map(\.concept.identifier).sorted()
                )
            }
            .sorted { $0.stem < $1.stem }
    }

    /// Normalises a repository name to its concept stem: the `swift-`
    /// prefix and the layer suffix are packaging, not concept.
    public static func stem(of name: Swift.String) -> Swift.String {
        var stem = Swift.Substring(name)
        if stem.hasPrefix("swift-") { stem = stem.dropFirst(6) }
        for suffix in ["-primitives", "-standard", "-standards", "-foundation", "-foundations"] {
            if stem.hasSuffix(suffix) {
                stem = stem.dropLast(suffix.count)
                break
            }
        }
        return Swift.String(stem)
    }
}
