public import WorkspaceArchitectureModel

extension Workspace.Architecture.Migration {
    /// The durable record of one epoch's classification.
    public struct Receipt: Sendable, Equatable {
        public let epoch: Workspace.Architecture.Epoch.Identifier
        public let owner: Workspace.Architecture.Owner
        public let phase: Phase
        public let consumers: [Workspace.Architecture.Owner]

        public init(
            epoch: Workspace.Architecture.Epoch.Identifier,
            owner: Workspace.Architecture.Owner,
            phase: Phase,
            consumers: [Workspace.Architecture.Owner]
        ) {
            self.epoch = epoch
            self.owner = owner
            self.phase = phase
            self.consumers = consumers
        }
    }
}
