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

extension Workspace.Doctor.Materialization.State {
    /// The verbatim rendering `Workspace.Pages.Repository.materialization`
    /// carries (issue #82) — a string rather than a re-exported typed
    /// field, matching that type's doc-comment discipline.
    public var rendered: Swift.String {
        switch self {
        case .canonical: "canonical"
        case .legacy: "legacy"
        case .both: "both"
        case .absent: "absent"
        case .invalid(let message): "invalid: \(message)"
        }
    }
}
