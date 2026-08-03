extension Workspace.Doctor.Peer {
    /// The state of one peer-checkout subject — a registered peer, or one
    /// repository a materialized peer's inventory declares.
    public enum State: Equatable, Sendable {
        /// The peer root is not materialized; the checkout has not opted
        /// in. A fact, never a finding.
        case optedOut
        /// The peer's inventory is loaded; its records became subjects of
        /// their own.
        case declared(repositories: Swift.Int)
        /// The peer root exists without an inventory at the declared
        /// path, so its packages cannot be resolved without tree
        /// inference — the state this mechanism exists to end.
        case unindexed(Swift.String)
        /// A declared repository is materialized as a Git repository at
        /// its peer-layout location.
        case canonical
        /// A declared repository is not materialized. Peers have no
        /// selection, so absence is a fact, never a finding.
        case absent
        /// A location could not be formed or safely inspected, or the
        /// inventory could not be decoded or validated.
        case invalid(Swift.String)
    }
}
