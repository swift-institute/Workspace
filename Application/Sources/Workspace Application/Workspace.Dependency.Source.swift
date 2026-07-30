extension Workspace.Dependency {
    /// One repository tree at an exact source revision.
    struct Source: Equatable, Sendable {
        let reference: Swift.String
        let revision: Swift.String
        let manifests: [Blob]

        init(
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
