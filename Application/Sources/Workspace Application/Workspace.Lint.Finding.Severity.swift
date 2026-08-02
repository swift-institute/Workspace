extension Workspace.Lint.Finding {
    /// SARIF's result-level vocabulary.
    public enum Severity: Swift.String, Equatable, Sendable {
        case error
        case warning
        case note
        case none
    }
}

extension Workspace.Lint.Finding.Severity {
    public var isError: Swift.Bool { self == .error }

    /// The SARIF level token owned by this enum.
    public var token: Swift.String { rawValue }
}
