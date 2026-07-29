extension Workspace.Dependency {
    /// One remote read, preserving every failure class the audit reports.
    enum Fetch<Value: Sendable>: Sendable {
        case available(Value)
        case unavailable(Swift.String)
        case rateLimited(Swift.String)
        case malformed(Swift.String)
        case unmeasured(Swift.String)
    }
}

extension Workspace.Dependency.Fetch {
    var failure: (state: Workspace.Dependency.State, reason: Swift.String)? {
        switch self {
        case .available:
            nil
        case .unavailable(let reason):
            (.unavailable, reason)
        case .rateLimited(let reason):
            (.rateLimited, reason)
        case .malformed(let reason):
            (.malformed, reason)
        case .unmeasured(let reason):
            (.unmeasured, reason)
        }
    }
}
