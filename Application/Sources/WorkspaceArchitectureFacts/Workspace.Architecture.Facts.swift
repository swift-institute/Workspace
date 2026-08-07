public import WorkspaceArchitectureModel

extension Workspace.Architecture {
    /// The derived model: every fact and every typed edge, in canonical
    /// order.
    ///
    /// Derivation is pure and deterministic — the same inventory and the
    /// same manifests always produce the same `Facts`, which is what makes
    /// the generated index and projection reproducible.
    public struct Facts: Sendable, Equatable {
        public let facts: [Fact]
        public let edges: [Edge]

        public init(facts: [Fact], edges: [Edge]) {
            self.facts = facts.sorted()
            self.edges = edges.sorted()
        }
    }
}

extension Workspace.Architecture.Facts {
    /// The inventory coordinate every provenance edge points at: the
    /// package root whose `Institute.json` supplied the rows.
    public static let inventoryOwner = Workspace.Architecture.Owner(
        organization: "swift-institute",
        name: "Workspace"
    )

    /// Derives the model from a decoded inventory and the manifests that
    /// were locally readable.
    ///
    /// Every inventory row yields one fact and one provenance edge; a row
    /// whose manifest was readable additionally yields its runtime edges
    /// toward other inventory owners.
    public static func derive(
        inventory: Inventory,
        manifests: [Workspace.Architecture.Owner: Manifest]
    ) -> Self {
        let owners = Swift.Dictionary(
            uniqueKeysWithValues: inventory.rows.map { (row) in
                ("\(row.organization)/\(row.name)", row.owner)
            }
        )
        var facts: [Workspace.Architecture.Fact] = []
        var edges: [Workspace.Architecture.Edge] = []
        for row in inventory.rows {
            let manifest = manifests[row.owner]
            facts.append(
                .init(
                    owner: row.owner,
                    layer: row.layer,
                    concept: .init(
                        identifier: .init(owner: row.owner),
                        name: row.name
                    ),
                    products: manifest?.products ?? [],
                    targets: manifest?.targets ?? []
                )
            )
            edges.append(
                .init(source: row.owner, destination: inventoryOwner, kind: .provenance)
            )
            for url in manifest?.dependencyURLs ?? [] {
                guard
                    let coordinate = Manifest.coordinate(url: url),
                    let destination = owners[coordinate],
                    destination != row.owner
                else { continue }
                edges.append(
                    .init(source: row.owner, destination: destination, kind: .runtime)
                )
            }
        }
        return .init(facts: facts, edges: Swift.Array(Swift.Set(edges)))
    }
}
