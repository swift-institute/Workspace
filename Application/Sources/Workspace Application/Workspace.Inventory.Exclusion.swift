extension Workspace.Inventory {
    public struct Exclusion: Equatable, Sendable {
        public let repository: Workspace.Repository.Key
        public let reason: Eligibility.Reason

        public init(repository: Workspace.Repository.Key, reason: Eligibility.Reason) {
            self.repository = repository
            self.reason = reason
        }
    }
}
