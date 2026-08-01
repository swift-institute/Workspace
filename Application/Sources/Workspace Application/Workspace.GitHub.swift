extension Workspace {
    /// Local GitHub credential capability.
    ///
    /// The Institute's automation identity is a GitHub App installed on every
    /// organization. Each installation carries its own REST and GraphQL rate
    /// pools, so machine reads issued under an installation token do not spend
    /// the principal's single shared pool.
    ///
    /// This namespace mints those tokens locally, from an App private key the
    /// operator installed themselves. Nothing here embeds an application
    /// identity, a key, or a key location: every one of those is resolved at
    /// run time from an argument, the environment, or the operator's
    /// configuration directory.
    public enum GitHub {}
}
