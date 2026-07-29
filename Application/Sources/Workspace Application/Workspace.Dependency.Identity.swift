extension Workspace.Dependency {
    /// One distinct package repository reached by any number of direct edges.
    public struct Identity: Equatable, Sendable {
        public let identity: Swift.String
        public let canonicalURL: Swift.String?
        public let declaredURLs: [Swift.String]
        public let ownership: Ownership
        public let state: State
        public let reason: Swift.String?

        public init(
            identity: Swift.String,
            canonicalURL: Swift.String?,
            declaredURLs: [Swift.String],
            ownership: Ownership,
            state: State,
            reason: Swift.String? = nil
        ) {
            self.identity = identity
            self.canonicalURL = canonicalURL
            self.declaredURLs = declaredURLs
            self.ownership = ownership
            self.state = state
            self.reason = reason
        }
    }
}
