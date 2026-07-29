extension Workspace.Dependency {
    /// Repository ownership after URL redirects have been resolved.
    public enum Ownership: Swift.String, Equatable, Sendable {
        case institute
        case personalOwner = "personal-owner"
        case thirdParty = "third-party"
        case sanctionedException = "sanctioned-exception"
        case unmeasured
    }
}
