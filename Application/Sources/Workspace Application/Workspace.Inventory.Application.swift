public import File_System

extension Workspace.Inventory {
    public struct Application<Listing, Content>: Sendable
    where
        Listing: Swift.Error,
        Content: Swift.Error
    {
        public let root: File.Directory
        public let policy: Workspace.Inventory.Policy
        public let client: Workspace.Inventory.Client<Listing, Content>

        public init(
            root: File.Directory,
            policy: Workspace.Inventory.Policy,
            client: Workspace.Inventory.Client<Listing, Content>
        ) {
            self.root = root
            self.policy = policy
            self.client = client
        }
    }
}

extension Workspace.Inventory.Application {
    public func run(
        existing: Workspace.Configuration.Document,
        dry: Bool
    ) async throws(Workspace.Inventory.Error<Listing, Content>) -> Workspace.Inventory.Writer.Plan {
        let discovery = try await client.discover(policy)
        let configuration: Workspace.Configuration
        do throws(Workspace.Inventory.Merge.Error) {
            configuration = try Workspace.Inventory.Merge()(
                discovery,
                into: existing.configuration
            )
        } catch {
            throw .merge(error)
        }

        do throws(Workspace.Error) {
            let writer = Workspace.Inventory.Writer(root: root)
            return try dry
                ? writer.plan(configuration)
                : writer.run(configuration, replacing: existing)
        } catch {
            throw .workspace(error)
        }
    }
}
