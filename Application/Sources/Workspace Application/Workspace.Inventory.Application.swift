public import File_System
public import Git_Foundation

extension Workspace.Inventory {
    public struct Application<Content: Swift.Error>: Sendable {
        public let root: File.Directory
        public let policy: Workspace.Inventory.Policy
        public let client: Workspace.Inventory.Client<Content>
        public let git: Git.Client

        public init(
            root: File.Directory,
            policy: Workspace.Inventory.Policy,
            client: Workspace.Inventory.Client<Content>,
            git: Git.Client = .init()
        ) {
            self.root = root
            self.policy = policy
            self.client = client
            self.git = git
        }
    }
}

extension Workspace.Inventory.Application {
    public func run(
        existing: Workspace.Configuration.Document,
        dry: Bool
    ) async throws(Workspace.Inventory.Error<Content>) -> Workspace.Inventory.Writer.Plan {
        if !dry {
            try preflight()
        }
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

    /// Refuses publication from a dirty or uninspectable Workspace worktree.
    ///
    /// This runs before discovery, rather than after its hundreds of requests,
    /// so a command that cannot safely publish fails before paying for a live
    /// census. ``Workspace/Inventory/Writer/run(_:replacing:)`` separately
    /// rejects a change to `Institute.json` that races discovery.
    private func preflight() throws(Workspace.Inventory.Error<Content>) {
        let changes: [Git.Status.Entry]
        do throws(Git.Client.Error) {
            changes = try git.status(at: root.description)
        } catch {
            throw .workspace(
                .repository(
                    "inventory regeneration cannot inspect the Workspace worktree: \(error)"
                )
            )
        }

        guard changes.isEmpty else {
            throw .workspace(
                .repository(
                    "inventory regeneration requires a clean Workspace worktree; found "
                        + "\(changes.count) changed path\(changes.count == 1 ? "" : "s")"
                )
            )
        }
    }
}
