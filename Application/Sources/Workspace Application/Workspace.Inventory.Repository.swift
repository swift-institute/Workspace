public import GitHub
public import Tagged_Primitives

extension Workspace.Inventory {
    public struct Repository: Equatable, Sendable {
        public let id: GitHub.Repository.ID
        public let key: Workspace.Repository.Key
        public let layer: Workspace.Layer

        public init(
            id: GitHub.Repository.ID,
            key: Workspace.Repository.Key,
            layer: Workspace.Layer
        ) {
            self.id = id
            self.key = key
            self.layer = layer
        }
    }
}
