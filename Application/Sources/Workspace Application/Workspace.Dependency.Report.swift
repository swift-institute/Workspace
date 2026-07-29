extension Workspace.Dependency {
    /// Deterministic dependency-origin evidence for one exact population.
    public struct Report: Equatable, Sendable {
        public let inventoryReference: Swift.String
        public let inventoryRevision: Swift.String
        public let sanctioned: [Workspace.Repository.Key]
        public let controls: Controls
        public let subjects: [Subject]
        public let manifests: [Manifest]
        public let edges: [Edge]
        public let identities: [Identity]
        public let exclusions: [Exclusion]

        public init(
            inventoryReference: Swift.String,
            inventoryRevision: Swift.String,
            sanctioned: [Workspace.Repository.Key],
            controls: Controls,
            subjects: [Subject],
            manifests: [Manifest],
            edges: [Edge],
            identities: [Identity],
            exclusions: [Exclusion]
        ) {
            self.inventoryReference = inventoryReference
            self.inventoryRevision = inventoryRevision
            self.sanctioned = sanctioned
            self.controls = controls
            self.subjects = subjects
            self.manifests = manifests
            self.edges = edges
            self.identities = identities
            self.exclusions = exclusions
        }
    }
}
