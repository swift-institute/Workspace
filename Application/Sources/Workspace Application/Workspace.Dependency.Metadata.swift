extension Workspace.Dependency {
    /// Live repository metadata needed to establish eligibility and ownership.
    public struct Metadata: Equatable, Sendable {
        public let key: Workspace.Repository.Key
        public let ownerIsUser: Swift.Bool
        public let visibility: Swift.String
        public let archived: Swift.Bool
        public let disabled: Swift.Bool
        public let defaultBranch: Swift.String

        public init(
            key: Workspace.Repository.Key,
            ownerIsUser: Swift.Bool,
            visibility: Swift.String,
            archived: Swift.Bool,
            disabled: Swift.Bool,
            defaultBranch: Swift.String
        ) {
            self.key = key
            self.ownerIsUser = ownerIsUser
            self.visibility = visibility
            self.archived = archived
            self.disabled = disabled
            self.defaultBranch = defaultBranch
        }
    }
}
