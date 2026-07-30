extension Workspace.Dependency {
    /// Measurement status for one manifest at one repository revision.
    public struct Manifest: Equatable, Sendable {
        public let repository: Workspace.Repository.Key
        public let path: Swift.String
        public let reference: Swift.String
        public let revision: Swift.String
        public let state: State
        public let reason: Swift.String?

        public init(
            repository: Workspace.Repository.Key,
            path: Swift.String,
            reference: Swift.String,
            revision: Swift.String,
            state: State,
            reason: Swift.String? = nil
        ) {
            self.repository = repository
            self.path = path
            self.reference = reference
            self.revision = revision
            self.state = state
            self.reason = reason
        }
    }
}
