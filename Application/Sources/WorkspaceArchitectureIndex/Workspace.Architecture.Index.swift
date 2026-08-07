public import WorkspaceArchitectureGraph
public import WorkspaceArchitectureModel

extension Workspace.Architecture {
    /// The deterministic generated index over the derived model.
    ///
    /// Generation is a pure function of facts and graph: regenerating from
    /// the same inputs yields byte-identical rendering and therefore an
    /// identical digest. That reproducibility is the index's contract.
    public struct Index: Sendable, Equatable {
        public let entries: [Entry]

        public init(entries: [Entry]) {
            self.entries = entries.sorted { $0.owner < $1.owner }
        }
    }
}

extension Workspace.Architecture.Index {
    /// Generates the index from the derived model.
    public static func generate(
        facts: [Workspace.Architecture.Fact],
        graph: Workspace.Architecture.Graph
    ) -> Self {
        .init(
            entries: facts.map { (fact) in
                .init(
                    owner: fact.owner,
                    layer: fact.layer,
                    concept: fact.concept.identifier,
                    productCount: fact.products.count,
                    targetCount: fact.targets.count,
                    edgeCount: graph.edges(from: fact.owner).count
                )
            }
        )
    }

    /// The canonical text projection: one line per entry, sorted by owner.
    public var rendered: Swift.String {
        entries.map { (entry) in
            "\(entry.owner)\t\(entry.layer.name)\t\(entry.concept)"
                + "\tproducts=\(entry.productCount)\ttargets=\(entry.targetCount)"
                + "\tedges=\(entry.edgeCount)"
        }
        .joined(separator: "\n")
    }

    /// The digest of the canonical rendering.
    public var digest: Digest {
        .init(text: rendered)
    }
}
