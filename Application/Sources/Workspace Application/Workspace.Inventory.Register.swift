extension Workspace.Inventory {
    /// The committed name → organization → materialized-path register.
    ///
    /// This is a view of the already loaded ``Workspace/Configuration``.
    /// It performs no discovery and has no write capability.
    public struct Register: Equatable, Sendable {
        public let repositories: [Workspace.Repository]

        public init(repositories: [Workspace.Repository]) {
            self.repositories = repositories
        }
    }
}

extension Workspace.Inventory.Register: CustomStringConvertible {
    public var description: Swift.String {
        (
            [
                "inventory: \(repositories.count) repositories "
                    + "(name → organization → path)"
            ]
            + repositories.map { repository in
                "  \(repository.name) → \(repository.organization) → "
                    + Workspace.Layout.reference(for: repository)
            }
        )
        .joined(separator: "\n")
    }
}
