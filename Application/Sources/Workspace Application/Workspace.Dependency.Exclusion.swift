extension Workspace.Dependency {
    /// A direct declaration deliberately outside canonical repository-URL
    /// edges, or a malformed declaration that cannot become one.
    public struct Exclusion: Equatable, Sendable {
        public let repository: Workspace.Repository.Key
        public let manifest: Swift.String
        public let reference: Swift.String
        public let revision: Swift.String
        public let line: Swift.Int
        public let kind: Kind
        public let value: Swift.String?
        public let reason: Swift.String

        public init(
            repository: Workspace.Repository.Key,
            manifest: Swift.String,
            reference: Swift.String,
            revision: Swift.String,
            line: Swift.Int,
            kind: Kind,
            value: Swift.String?,
            reason: Swift.String
        ) {
            self.repository = repository
            self.manifest = manifest
            self.reference = reference
            self.revision = revision
            self.line = line
            self.kind = kind
            self.value = value
            self.reason = reason
        }
    }
}
