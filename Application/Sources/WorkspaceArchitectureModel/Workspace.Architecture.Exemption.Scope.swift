extension Workspace.Architecture.Exemption {
    /// The violation class one exemption excuses; an exemption never
    /// excuses everything.
    public enum Scope: Sendable, Equatable, Hashable, CaseIterable {
        case duplicateSemanticOwner
        case forbiddenEdge
        case contradiction
    }
}

extension Workspace.Architecture.Exemption.Scope {
    public var name: Swift.String {
        switch self {
        case .duplicateSemanticOwner: "duplicate-semantic-owner"
        case .forbiddenEdge: "forbidden-edge"
        case .contradiction: "contradiction"
        }
    }
}
