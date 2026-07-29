extension Workspace.Dependency {
    /// Reproducible, read-only measurement of direct manifest dependency
    /// origins over the Workspace inventory.
    public struct Audit: Sendable {
        public let repositories: [Workspace.Repository]
        public let policy: Workspace.Inventory.Policy
        public let client: Client
        public let sanctioned: Set<Workspace.Repository.Key>
        public let inventoryReference: Swift.String
        public let inventoryRevision: Swift.String
        public let parser: Parser
        public let fanout: Workspace.Fanout

        public init(
            repositories: [Workspace.Repository],
            policy: Workspace.Inventory.Policy,
            client: Client,
            sanctioned: Set<Workspace.Repository.Key> = [],
            inventoryReference: Swift.String,
            inventoryRevision: Swift.String,
            parser: Parser = .init(),
            fanout: Workspace.Fanout = .init()
        ) {
            self.repositories = repositories
            self.policy = policy
            self.client = client
            self.sanctioned = sanctioned
            self.inventoryReference = inventoryReference
            self.inventoryRevision = inventoryRevision
            self.parser = parser
            self.fanout = fanout
        }
    }
}
