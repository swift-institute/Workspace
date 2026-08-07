public import WorkspaceArchitectureModel

extension Workspace.Architecture {
    /// The typed dependency graph over derived facts.
    ///
    /// Nodes are owners, edges are typed; both are held in canonical order
    /// so any projection of the graph is deterministic.
    public struct Graph: Sendable, Equatable {
        public let nodes: [Owner]
        public let edges: [Edge]
        public let layers: [Owner: Layer]

        public init(facts: [Fact], edges: [Edge]) {
            self.nodes = facts.map(\.owner).sorted()
            self.edges = edges.sorted()
            self.layers = Swift.Dictionary(
                uniqueKeysWithValues: facts.map { ($0.owner, $0.layer) }
            )
        }
    }
}

extension Workspace.Architecture.Graph {
    /// The edges leaving one owner, in canonical order.
    public func edges(from source: Workspace.Architecture.Owner) -> [Workspace.Architecture.Edge] {
        edges.filter { $0.source == source }
    }

    /// Edges whose destination sits in a higher layer than their source.
    ///
    /// Dependency direction is downward: a lower layer must never depend
    /// on a higher one. Provenance edges record derivation origin, not a
    /// dependency, and are never forbidden.
    public var forbiddenEdges:
        [(edge: Workspace.Architecture.Edge, source: Workspace.Architecture.Layer, destination: Workspace.Architecture.Layer)]
    {
        edges.compactMap { (edge) in
            guard
                edge.kind != .provenance,
                let source = layers[edge.source],
                let destination = layers[edge.destination],
                destination > source
            else { return nil }
            return (edge, source, destination)
        }
    }

    /// A dependency cycle if one exists, as the owners along it.
    ///
    /// Provenance edges are excluded: they record where a fact came from,
    /// not a build-time dependency, and the inventory root would otherwise
    /// appear inside every path.
    public func cycle() -> [Workspace.Architecture.Owner]? {
        var adjacency: [Workspace.Architecture.Owner: [Workspace.Architecture.Owner]] = [:]
        for edge in edges where edge.kind != .provenance {
            adjacency[edge.source, default: []].append(edge.destination)
        }
        var visited: Swift.Set<Workspace.Architecture.Owner> = []
        var stack: [Workspace.Architecture.Owner] = []
        var onStack: Swift.Set<Workspace.Architecture.Owner> = []

        func visit(_ node: Workspace.Architecture.Owner) -> [Workspace.Architecture.Owner]? {
            if onStack.contains(node) {
                if let start = stack.firstIndex(of: node) {
                    return Swift.Array(stack[start...])
                }
                return stack
            }
            if visited.contains(node) { return nil }
            visited.insert(node)
            onStack.insert(node)
            stack.append(node)
            for next in adjacency[node] ?? [] {
                if let found = visit(next) { return found }
            }
            stack.removeLast()
            onStack.remove(node)
            return nil
        }

        for node in nodes {
            if let found = visit(node) { return found }
        }
        return nil
    }
}
