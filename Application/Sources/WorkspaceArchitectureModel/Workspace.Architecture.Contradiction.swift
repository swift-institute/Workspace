extension Workspace.Architecture {
    /// A disagreement between two derived sources.
    ///
    /// Contradictions are found mechanically by comparing derivations —
    /// there is no authored assertion to contradict.
    public enum Contradiction: Sendable, Equatable, Hashable {
        /// A graph edge names an owner no derived fact describes.
        case unknownEdgeEndpoint(Edge, missing: Owner)
        /// The inventory and the derived model place one owner in two
        /// different layers.
        case layerDisagreement(owner: Owner, inventory: Layer, derived: Layer)
    }
}
