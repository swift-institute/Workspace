extension Workspace.Lint.Ledger {
    /// One advisory rule class present in one repository.
    public struct Advisory: Equatable, Sendable {
        public let rule: Swift.String
        public let findings: [Workspace.Lint.Finding]
        public let disposition: Disposition?

        public init(
            rule: Swift.String,
            findings: [Workspace.Lint.Finding],
            disposition: Disposition?
        ) {
            self.rule = rule
            self.findings = findings.sorted(by: Workspace.Lint.Finding.precedes)
            self.disposition = disposition
        }
    }
}
