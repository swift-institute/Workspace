extension Workspace.Doctor.Currency {
    public enum Presence: Equatable, Sendable {
        /// In `Workspace.json` but not discovered on GitHub.
        case committed
        /// Discovered on GitHub but missing from `Workspace.json`.
        case discovered
        /// In both — current.
        case both
    }
}
