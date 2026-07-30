internal import GitHub

extension Workspace.Dependency {
    /// Live repository metadata needed to establish eligibility and ownership.
    struct Metadata: Equatable, Sendable {
        let key: Workspace.Repository.Key
        let ownerIsUser: Swift.Bool
        let visibility: GitHub.Repository.Visibility
        let archived: Swift.Bool
        let disabled: Swift.Bool
        let defaultBranch: Swift.String

        init(
            key: Workspace.Repository.Key,
            ownerIsUser: Swift.Bool,
            visibility: GitHub.Repository.Visibility,
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
