extension Workspace.Dependency {
    /// Whether an input was measured, deliberately excluded, or could not be
    /// measured for a named reason.
    public enum State: Swift.String, Equatable, Sendable {
        case measured
        case excluded
        case unavailable
        case rateLimited = "rate-limited"
        case malformed
        case unmeasured
    }
}
