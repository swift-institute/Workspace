extension Workspace.Lint.Ledger {
    /// A deterministic same-rule, same-owner remediation batch.
    public struct Batch: Equatable, Sendable {
        public let rule: Swift.String
        public let owner: Workspace.Repository.Key
        public let issue: Swift.String
        public let repositories: [Workspace.Repository.Key]
        public let findings: Swift.Int

        package init(
            rule: Swift.String,
            owner: Workspace.Repository.Key,
            issue: Swift.String,
            repositories: [Workspace.Repository.Key],
            findings: Swift.Int
        ) {
            self.rule = rule
            self.owner = owner
            self.issue = issue
            self.repositories = repositories.sorted(by: Workspace.Repository.Key.precedes)
            self.findings = findings
        }
    }
}
