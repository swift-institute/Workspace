extension Workspace.Architecture {
    /// A Class I finding: mechanically decidable from the derived model
    /// alone.
    public enum Violation: Sendable, Equatable, Hashable {
        /// Two derived facts claim the same semantic concept.
        case duplicateSemanticOwner(
            concept: Concept.Identifier,
            owners: [Owner]
        )
        /// An edge points from a lower layer to a higher layer.
        case forbiddenEdge(Edge, source: Layer, destination: Layer)
        /// Two derivations disagree.
        case contradiction(Contradiction)
    }
}

extension Workspace.Architecture.Violation {
    /// The exemption scope that may excuse this violation.
    public var scope: Workspace.Architecture.Exemption.Scope {
        switch self {
        case .duplicateSemanticOwner: .duplicateSemanticOwner
        case .forbiddenEdge: .forbiddenEdge
        case .contradiction: .contradiction
        }
    }

    /// The owners the violation implicates, for exemption matching.
    public var owners: [Workspace.Architecture.Owner] {
        switch self {
        case .duplicateSemanticOwner(_, let owners): owners
        case .forbiddenEdge(let edge, _, _): [edge.source]
        case .contradiction(.unknownEdgeEndpoint(let edge, _)): [edge.source]
        case .contradiction(.layerDisagreement(let owner, _, _)): [owner]
        }
    }
}
