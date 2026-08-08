internal import SPM_Standard

extension Workspace.Dependency {
    /// Reproducible, read-only measurement of direct manifest dependency
    /// origins over the Workspace inventory.
    struct Audit: Sendable {
        let repositories: [Workspace.Repository]
        let policy: Workspace.Inventory.Policy
        let client: Client
        let sanctioned: Set<Workspace.Repository.Key>
        let inventoryReference: Swift.String
        let inventoryRevision: Swift.String
        let parser: Package.Dependency.Declaration.Parser
        let fanout: Workspace.Fanout

        init(
            repositories: [Workspace.Repository],
            policy: Workspace.Inventory.Policy,
            client: Client,
            sanctioned: Set<Workspace.Repository.Key> = [],
            inventoryReference: Swift.String,
            inventoryRevision: Swift.String,
            parser: Package.Dependency.Declaration.Parser = .init(),
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
