extension Workspace.Architecture {
    /// One of the three realised Institute layers.
    ///
    /// Dependency edges point from higher layers to lower layers; the
    /// ``rank`` orders the layers so an edge's legality is a single
    /// comparison.
    public enum Layer: Sendable, Equatable, Hashable, CaseIterable {
        case primitives
        case standards
        case foundations
    }
}

extension Workspace.Architecture.Layer {
    /// The layer's height: a target may depend only on layers whose rank is
    /// less than or equal to its own.
    public var rank: Swift.Int {
        switch self {
        case .primitives: 1
        case .standards: 2
        case .foundations: 3
        }
    }

    /// The inventory spelling, exactly as `Institute.json` records it.
    public var name: Swift.String {
        switch self {
        case .primitives: "primitives"
        case .standards: "standards"
        case .foundations: "foundations"
        }
    }

    public init?(name: Swift.String) {
        switch name {
        case "primitives": self = .primitives
        case "standards": self = .standards
        case "foundations": self = .foundations
        default: return nil
        }
    }
}

extension Workspace.Architecture.Layer: Comparable {
    public static func < (
        lhs: Workspace.Architecture.Layer,
        rhs: Workspace.Architecture.Layer
    ) -> Swift.Bool {
        lhs.rank < rhs.rank
    }
}
