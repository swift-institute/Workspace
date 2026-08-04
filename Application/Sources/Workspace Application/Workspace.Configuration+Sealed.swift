/// `Workspace.Configuration` already satisfies `JSON.Serializable` — the
/// only requirement `Sealed` adds — so conforming costs nothing beyond this
/// declaration and gives ``Workspace/Inventory/Effective`` its three digests
/// (public, private, combined) through the module's one existing SHA-256
/// spawn site rather than a second one. See ``Workspace/Receipt/Sealed``.
extension Workspace.Configuration: Workspace.Receipt.Sealed {}
