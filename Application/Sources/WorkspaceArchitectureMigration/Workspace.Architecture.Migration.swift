public import WorkspaceArchitectureModel

extension Workspace.Architecture {
    /// Migration epochs over semantic-owner state.
    ///
    /// An epoch is classified by its remaining consumers: with zero
    /// consumers it is terminal — the deletion gate's zero-reachability
    /// half is met and only the replacement receipt remains.
    public enum Migration {}
}

extension Workspace.Architecture.Migration {
    /// Classifies one epoch by its consumer population.
    public static func classify(_ epoch: Workspace.Architecture.Epoch) -> Phase {
        epoch.consumers.isEmpty ? .terminal : .active(consumers: epoch.consumers.count)
    }

    /// Produces the migration receipt for one epoch.
    public static func receipt(for epoch: Workspace.Architecture.Epoch) -> Receipt {
        .init(
            epoch: epoch.identifier,
            owner: epoch.owner,
            phase: classify(epoch),
            consumers: epoch.consumers.sorted()
        )
    }
}
