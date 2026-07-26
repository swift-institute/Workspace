extension Workspace.Doctor.Census {
    /// Where a repository's HEAD is: on a named branch, or detached.
    public enum Head: Equatable, Sendable {
        case branch(Swift.String)
        case detached
    }
}
