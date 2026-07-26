extension Workspace.Doctor {
    /// How serious a measured finding is.
    ///
    /// `warning` findings are advisory: they are reported but do not fail
    /// the run. `error` findings contribute exit code 1.
    public enum Severity: Comparable, Equatable, Sendable {
        case warning
        case error
    }
}

extension Workspace.Doctor.Severity: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .warning: "warning"
        case .error: "error"
        }
    }
}
