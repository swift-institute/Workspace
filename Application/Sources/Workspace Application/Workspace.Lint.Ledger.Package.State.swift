extension Workspace.Lint.Ledger.Package {
    /// Whether one inventory repository produced usable structured evidence.
    public enum State: Swift.String, Equatable, Sendable {
        case measured
        case unmeasured
    }
}

extension Workspace.Lint.Ledger.Package.State {
    /// The ledger-state wire token owned by this enum.
    public var token: Swift.String { rawValue }
}
