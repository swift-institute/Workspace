extension Workspace.Dependency.Exclusion {
    public enum Kind: Swift.String, Equatable, Sendable {
        case path
        case registry
        case malformed
    }
}
