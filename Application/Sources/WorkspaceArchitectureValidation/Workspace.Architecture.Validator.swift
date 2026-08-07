public import WorkspaceArchitectureGraph
public import WorkspaceArchitectureModel

extension Workspace.Architecture {
    /// Class I validation of the derived model.
    ///
    /// Every check is mechanically decidable from facts and graph alone:
    /// duplicate semantic owners, forbidden edges, and derived
    /// contradiction checks. Exemptions are derived-model exemptions —
    /// owner, reason, scope, expiry — and excuse exactly the violations
    /// whose scope and owner they name, until they expire.
    public struct Validator: Sendable {
        public let exemptions: [Exemption]

        public init(exemptions: [Exemption] = []) {
            self.exemptions = exemptions
        }
    }
}

extension Workspace.Architecture.Validator {
    /// Validates the derived model as of `today`.
    public func validate(
        facts: [Workspace.Architecture.Fact],
        graph: Workspace.Architecture.Graph,
        today: Workspace.Architecture.Exemption.Expiry
    ) -> Report {
        var violations: [Workspace.Architecture.Violation] = []

        var claims:
            [Workspace.Architecture.Concept.Identifier: [Workspace.Architecture.Owner]] = [:]
        for fact in facts {
            claims[fact.concept.identifier, default: []].append(fact.owner)
        }
        for (concept, owners) in claims.sorted(by: { $0.key < $1.key }) where owners.count > 1 {
            violations.append(
                .duplicateSemanticOwner(concept: concept, owners: owners.sorted())
            )
        }

        for forbidden in graph.forbiddenEdges {
            violations.append(
                .forbiddenEdge(
                    forbidden.edge,
                    source: forbidden.source,
                    destination: forbidden.destination
                )
            )
        }

        let known = Swift.Set(facts.map(\.owner))
        for edge in graph.edges {
            if !known.contains(edge.source) {
                violations.append(
                    .contradiction(.unknownEdgeEndpoint(edge, missing: edge.source))
                )
            }
            if !known.contains(edge.destination), edge.kind != .provenance {
                violations.append(
                    .contradiction(.unknownEdgeEndpoint(edge, missing: edge.destination))
                )
            }
        }
        for fact in facts {
            if let placed = graph.layers[fact.owner], placed != fact.layer {
                violations.append(
                    .contradiction(
                        .layerDisagreement(
                            owner: fact.owner,
                            inventory: fact.layer,
                            derived: placed
                        )
                    )
                )
            }
        }

        var outstanding: [Workspace.Architecture.Violation] = []
        var excused: [Workspace.Architecture.Violation] = []
        for violation in violations {
            let covered = exemptions.contains { (exemption) in
                exemption.scope == violation.scope
                    && violation.owners.contains(exemption.owner)
                    && exemption.expiry >= today
            }
            if covered {
                excused.append(violation)
            } else {
                outstanding.append(violation)
            }
        }
        return .init(violations: outstanding, excused: excused)
    }
}
