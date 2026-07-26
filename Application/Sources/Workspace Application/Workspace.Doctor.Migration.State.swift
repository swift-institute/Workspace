extension Workspace.Doctor.Migration {
    public enum State: Equatable, Sendable {
        /// A Git repository still sits at the flat `Packages/<name>`
        /// location.
        case flat
        /// No flat checkout remains.
        case clean
    }
}
