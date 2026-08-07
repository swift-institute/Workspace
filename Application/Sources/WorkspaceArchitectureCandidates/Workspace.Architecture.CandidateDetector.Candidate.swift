public import WorkspaceArchitectureModel

extension Workspace.Architecture.CandidateDetector {
    /// One advisory finding: name-similar owners with distinct concept
    /// identities.
    ///
    /// A candidate proposes a human look; it never merges concepts.
    public struct Candidate: Sendable, Equatable {
        public let stem: Swift.String
        public let owners: [Workspace.Architecture.Owner]
        public let concepts: [Workspace.Architecture.Concept.Identifier]

        public init(
            stem: Swift.String,
            owners: [Workspace.Architecture.Owner],
            concepts: [Workspace.Architecture.Concept.Identifier]
        ) {
            self.stem = stem
            self.owners = owners
            self.concepts = concepts
        }
    }
}
