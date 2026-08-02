extension Workspace.Lint.Ledger {
    /// One complete-inventory ledger row.
    public struct Package: Equatable, Sendable {
        public let repository: Workspace.Repository.Key
        public let owner: Swift.String
        public let layer: Workspace.Layer
        public let state: State
        public let reason: Swift.String?
        public let prerequisite: Workspace.Lint.Prerequisite?
        public let summary: Workspace.Lint.Summary?
        public let errors: Swift.Int?
        public let advisories: [Advisory]
        public let verification: Verification?

        package init(
            repository: Workspace.Repository.Key,
            owner: Swift.String,
            layer: Workspace.Layer,
            state: State,
            reason: Swift.String?,
            prerequisite: Workspace.Lint.Prerequisite?,
            summary: Workspace.Lint.Summary?,
            errors: Swift.Int?,
            advisories: [Advisory],
            verification: Verification?
        ) {
            self.repository = repository
            self.owner = owner
            self.layer = layer
            self.state = state
            self.reason = reason
            self.prerequisite = prerequisite
            self.summary = summary
            self.errors = errors
            self.advisories = advisories.sorted { $0.rule < $1.rule }
            self.verification = verification
        }
    }
}
