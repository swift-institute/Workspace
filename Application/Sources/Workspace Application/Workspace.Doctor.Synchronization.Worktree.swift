extension Workspace.Doctor.Synchronization {
    public enum Worktree: Equatable, Sendable {
        case clean
        case dirty
    }
}
