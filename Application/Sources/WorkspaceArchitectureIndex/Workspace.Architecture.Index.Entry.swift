public import WorkspaceArchitectureModel

extension Workspace.Architecture.Index {
    /// One index row: the derived summary of a single package root.
    public struct Entry: Sendable, Equatable {
        public let owner: Workspace.Architecture.Owner
        public let layer: Workspace.Architecture.Layer
        public let concept: Workspace.Architecture.Concept.Identifier
        public let productCount: Swift.Int
        public let targetCount: Swift.Int
        public let edgeCount: Swift.Int

        public init(
            owner: Workspace.Architecture.Owner,
            layer: Workspace.Architecture.Layer,
            concept: Workspace.Architecture.Concept.Identifier,
            productCount: Swift.Int,
            targetCount: Swift.Int,
            edgeCount: Swift.Int
        ) {
            self.owner = owner
            self.layer = layer
            self.concept = concept
            self.productCount = productCount
            self.targetCount = targetCount
            self.edgeCount = edgeCount
        }
    }
}
