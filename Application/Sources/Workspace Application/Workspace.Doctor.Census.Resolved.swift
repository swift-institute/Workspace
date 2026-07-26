extension Workspace.Doctor.Census {
    /// Whether a repository's resolved-state file (`Package.resolved`)
    /// is present, and if present whether it is ignored.
    ///
    /// Resolved state is generated: an ignored file is the healthy
    /// present state, and a present file that is tracked or untracked —
    /// `exposed` — is one commit away from freezing generated state
    /// into history.
    public enum Resolved: Equatable, Sendable {
        /// No resolved-state file on disk.
        case absent
        /// Present and ignored — the healthy present state.
        case ignored
        /// Present and not ignored: tracked, or untracked and one
        /// `git add` away from being committed.
        case exposed
    }
}
