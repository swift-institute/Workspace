extension Workspace.Inventory.Private {
    /// The result of one authenticated private-visibility discovery pass —
    /// the private mirror of ``Workspace/Inventory/Discovery``, with a third
    /// population `discover(_:)` structurally cannot produce:
    /// ``unmeasured``.
    public struct Discovery: Equatable, Sendable {
        public let repositories: [Workspace.Inventory.Repository]
        public let exclusions: [Workspace.Inventory.Exclusion]
        public let unmeasured: [Unmeasured]

        public init(
            repositories: [Workspace.Inventory.Repository],
            exclusions: [Workspace.Inventory.Exclusion],
            unmeasured: [Unmeasured]
        ) {
            self.repositories = repositories
            self.exclusions = exclusions
            self.unmeasured = unmeasured
        }
    }
}
