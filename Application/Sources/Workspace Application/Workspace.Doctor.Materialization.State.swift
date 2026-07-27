extension Workspace.Doctor.Materialization {
    public enum State: Equatable, Sendable {
        /// A Git repository exists only at the active sibling location.
        case canonical
        /// A Git repository exists only at the superseded in-checkout location.
        case legacy
        /// Git repositories exist at both locations; the sibling is active.
        case both
        /// Neither location holds a Git repository.
        case absent
        /// A location could not be formed or safely inspected.
        case invalid(Swift.String)
    }
}
