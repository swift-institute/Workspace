public import File_System

extension Workspace.Inventory {
    public struct Application<Listing, Content>: Sendable
    where
        Listing: Swift.Error & Sendable,
        Content: Swift.Error & Sendable
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

        public func run(
            existing: Workspace.Configuration,
            dry: Bool
        ) async throws(Workspace.Inventory.Error<Listing, Content>) -> Workspace.Inventory.Writer.Plan {
            let discovery = try await client.discover(policy)
            let configuration: Workspace.Configuration
            do throws(Workspace.Inventory.Merge.Error) {
                configuration = try Workspace.Inventory.Merge()(discovery, into: existing)
            } catch {
                throw .merge(error)
            }

            do throws(Workspace.Error) {
                return try Workspace.Inventory.Writer(root: root).run(configuration, dry: dry)
            } catch {
                throw .workspace(error)
            }
        }
    }
}
