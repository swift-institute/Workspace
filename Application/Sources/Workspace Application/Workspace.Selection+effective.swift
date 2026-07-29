public import File_System

extension Workspace.Selection {
    /// The selection in effect for this checkout: the committed document,
    /// with the local override applied over it when one exists, resolved
    /// against the inventory.
    ///
    /// This is the only path any command takes to a selection. The merged
    /// document goes through the same ``Workspace/Selection/validated()``
    /// and ``Workspace/Selection/resolved(in:origin:)`` the committed
    /// document alone goes through — version, emptiness, duplication and
    /// inventory presence are decided on the *result*, not on the committed
    /// half. Being local buys no exemption from a guarantee.
    public static func effective(
        at root: File.Directory,
        in configuration: Workspace.Configuration
    ) throws(Workspace.Error) -> Resolved {
        let committed = try load(at: root)
        guard let override = try Override.load(at: root) else {
            return try committed.resolved(
                in: configuration,
                origin: .committed(count: committed.repositories.count)
            )
        }
        return try override.applied(to: committed).resolved(
            in: configuration,
            origin: .overridden(
                committed: committed.repositories.count,
                added: override.add,
                removed: override.remove
            )
        )
    }
}
