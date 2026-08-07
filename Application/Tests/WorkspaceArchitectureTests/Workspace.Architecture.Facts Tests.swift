import JSON
import Testing
import WorkspaceArchitectureFacts
import WorkspaceArchitectureGraph
import WorkspaceArchitectureIndex
import WorkspaceArchitectureModel

private let inventory = Workspace.Architecture.Facts.Inventory(rows: [
    .init(
        organization: "swift-primitives",
        name: "swift-byte-primitives",
        layer: .primitives,
        url: "https://github.com/swift-primitives/swift-byte-primitives.git"
    ),
    .init(
        organization: "swift-foundations",
        name: "swift-console",
        layer: .foundations,
        url: "https://github.com/swift-foundations/swift-console.git"
    ),
])

private let manifest = Workspace.Architecture.Facts.Manifest.scan(
    """
    let package = Package(
        name: "swift-console",
        products: [
            .library(
                name: "Console",
                targets: ["Console"]
            ),
        ],
        dependencies: [
            .package(url: "https://github.com/swift-primitives/swift-byte-primitives.git", branch: "main"),
        ],
        targets: [
            .target(
                name: "Console"
            ),
            .testTarget(
                name: "Console Tests",
                dependencies: ["Console"]
            ),
        ]
    )
    """
)

@Suite
struct `Workspace Architecture Facts Tests` {
    @Suite
    struct Unit {
        @Test
        func `scans a manifest for targets, products and dependency URLs`() {
            #expect(manifest.products == ["Console"])
            #expect(manifest.targets == ["Console"])
            #expect(
                manifest.dependencyURLs
                    == ["https://github.com/swift-primitives/swift-byte-primitives.git"]
            )
        }

        @Test
        func `derives facts, provenance edges and runtime edges`() {
            let consoleOwner = Workspace.Architecture.Owner(
                organization: "swift-foundations",
                name: "swift-console"
            )
            let derived = Workspace.Architecture.Facts.derive(
                inventory: inventory,
                manifests: [consoleOwner: manifest]
            )
            #expect(derived.facts.count == 2)
            #expect(
                derived.edges.contains { (edge) in
                    edge.kind == .provenance
                        && edge.destination == Workspace.Architecture.Facts.inventoryOwner
                }
            )
            #expect(
                derived.edges.contains(
                    .init(
                        source: consoleOwner,
                        destination: .init(
                            organization: "swift-primitives",
                            name: "swift-byte-primitives"
                        ),
                        kind: .runtime
                    )
                )
            )
            // The console fact carries manifest-derived products.
            let console = derived.facts.first { $0.owner == consoleOwner }
            #expect(console?.products == ["Console"])
            #expect(console?.classification == .exposesPublicAPI)
        }
    }

    @Suite
    struct `Edge Case` {
        @Test
        func `decodes an inventory document and ignores unrelated keys`() throws {
            let decoded = try Workspace.Architecture.Facts.Inventory(
                jsonString: """
                    {
                      "repositories": [
                        {
                          "layer": "standards",
                          "name": "swift-spm-standard",
                          "organization": "swift-standards",
                          "url": "https://github.com/swift-standards/swift-spm-standard.git"
                        }
                      ],
                      "scope": "proof",
                      "swift": "6.3.3",
                      "version": 1,
                      "xcode": "26.6"
                    }
                    """
            )
            #expect(decoded.rows.count == 1)
            #expect(decoded.rows.first?.layer == .standards)
            #expect(
                decoded.rows.first?.owner
                    == .init(organization: "swift-standards", name: "swift-spm-standard")
            )
        }
    }

    @Suite
    struct Integration {
        @Test
        func `derivation is deterministic across repeated runs`() {
            let consoleOwner = Workspace.Architecture.Owner(
                organization: "swift-foundations",
                name: "swift-console"
            )
            let first = Workspace.Architecture.Facts.derive(
                inventory: inventory,
                manifests: [consoleOwner: manifest]
            )
            let second = Workspace.Architecture.Facts.derive(
                inventory: inventory,
                manifests: [consoleOwner: manifest]
            )
            #expect(first == second)
            let graph = Workspace.Architecture.Graph(facts: first.facts, edges: first.edges)
            #expect(
                Workspace.Architecture.Index.generate(facts: first.facts, graph: graph).digest
                    == Workspace.Architecture.Index.generate(
                        facts: second.facts,
                        graph: graph
                    )
                    .digest
            )
        }
    }
}
