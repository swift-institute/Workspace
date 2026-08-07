public import WorkspaceArchitectureModel

extension Workspace.Architecture.CLI {
    /// Why `workspace architecture validate` could not complete.
    public enum Error: Swift.Error, Sendable, Equatable {
        case noWorkspaceCheckout(searchedFrom: Swift.String)
        case derivation(Swift.String)
        case unstableIndex(first: Swift.String, second: Swift.String)
    }
}
