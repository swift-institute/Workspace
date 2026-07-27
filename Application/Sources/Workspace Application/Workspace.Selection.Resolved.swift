extension Workspace.Selection {
    public struct Resolved: Equatable, Sendable {
        public let repositories: [Workspace.Repository]

        package init(repositories: [Workspace.Repository]) {
            self.repositories = repositories
        }
    }
}
