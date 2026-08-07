public import WorkspaceArchitectureModel

extension Workspace.Architecture.Migration {
    /// Where one epoch stands.
    public enum Phase: Sendable, Equatable, Hashable {
        /// Consumers remain; the epoch must be preserved.
        case active(consumers: Swift.Int)
        /// Zero consumers: the epoch is deletable once its replacement
        /// receipt exists.
        case terminal
    }
}
