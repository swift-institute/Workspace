extension Workspace.Architecture.Exemption {
    /// Why an exemption could not be constructed.
    public enum Error: Swift.Error, Sendable, Equatable {
        case emptyReason(owner: Workspace.Architecture.Owner)
        case malformedExpiry(Swift.String)
    }
}
