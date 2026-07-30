extension Workspace.Dependency {
    /// Resolution of one declared key through GitHub repository redirects.
    struct Resolution: Sendable {
        let declared: Workspace.Repository.Key
        let fetch: Fetch<Metadata>
    }
}
