extension Workspace.Inventory {
    public struct Discovery: Equatable, Sendable {
        public let repositories: [Repository]
        public let exclusions: [Exclusion]

        public init(repositories: [Repository], exclusions: [Exclusion]) {
            self.repositories = repositories
            self.exclusions = exclusions
        }
    }
}
