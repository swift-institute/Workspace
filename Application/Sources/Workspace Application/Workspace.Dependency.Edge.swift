extension Workspace.Dependency {
    /// One direct URL declaration. Repeated declarations remain repeated edges.
    public struct Edge: Equatable, Sendable {
        public let repository: Workspace.Repository.Key
        public let manifest: Swift.String
        public let reference: Swift.String
        public let revision: Swift.String
        public let line: Swift.Int
        public let declaredURL: Swift.String
        public let canonicalURL: Swift.String?
        public let identity: Swift.String
        public let state: State
        public let reason: Swift.String?

        public init(
            repository: Workspace.Repository.Key,
            manifest: Swift.String,
            reference: Swift.String,
            revision: Swift.String,
            line: Swift.Int,
            declaredURL: Swift.String,
            canonicalURL: Swift.String?,
            identity: Swift.String,
            state: State,
            reason: Swift.String? = nil
        ) {
            self.repository = repository
            self.manifest = manifest
            self.reference = reference
            self.revision = revision
            self.line = line
            self.declaredURL = declaredURL
            self.canonicalURL = canonicalURL
            self.identity = identity
            self.state = state
            self.reason = reason
        }
    }
}
