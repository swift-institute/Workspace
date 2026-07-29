extension Workspace.Dependency {
    /// One repository tree at an exact source revision.
    public struct Source: Equatable, Sendable {
        public let reference: Swift.String
        public let revision: Swift.String
        public let manifests: [Blob]

        public init(
            reference: Swift.String,
            revision: Swift.String,
            manifests: [Blob]
        ) {
            self.reference = reference
            self.revision = revision
            self.manifests = manifests
        }
    }
}
