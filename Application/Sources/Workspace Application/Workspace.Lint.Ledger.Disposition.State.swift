extension Workspace.Lint.Ledger.Disposition {
    /// The terminal advisory-class dispositions admitted by Goal #90.
    public enum State: Swift.String, CaseIterable, Equatable, Sendable {
        case promotion
        case retention
        case change
        case removal
        case addition
        case relocation
        case remediation
    }
}

extension Workspace.Lint.Ledger.Disposition.State {
    /// The disposition wire token owned by this enum.
    public var token: Swift.String { rawValue }
}
