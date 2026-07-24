public import GitHub
public import Tagged_Primitives

extension Workspace.Inventory {
    public struct Organization: Equatable, Hashable, Sendable {
        public let name: GitHub.Organization.Name
        public let layer: Workspace.Layer

        public init(name: GitHub.Organization.Name, layer: Workspace.Layer) {
            self.name = name
            self.layer = layer
        }
    }
}
