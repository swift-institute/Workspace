extension Workspace.Doctor.Materialization {
    public enum State: Equatable, Sendable {
        /// A Git repository exists at the repository's path.
        case materialized
        /// Nothing (or something that is not a Git repository) is at
        /// the repository's path.
        case absent
        /// The inventory name cannot form a path component.
        case invalid(Swift.String)
    }
}
