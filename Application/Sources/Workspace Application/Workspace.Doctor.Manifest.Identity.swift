extension Workspace.Doctor.Manifest {
    public enum Identity: Equatable, Sendable {
        case evaluated(Swift.String)
        case unevaluable(Swift.String)
    }
}
