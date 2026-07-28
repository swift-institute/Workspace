public import GitHub

extension Workspace.Inventory.Eligibility {
    /// Why a repository in a policy organization is not on the roster.
    ///
    /// **There is deliberately no `fork` case.** One existed until 2026-07-28
    /// and excluded three load-bearing packages —
    /// `swift-primitives/swift-tagged-primitives` (the most-depended-on package
    /// in the tree), `swift-foundations/swift-url-routing`, and
    /// `swift-foundations/swift-structured-queries-postgres`. Consumers went on
    /// resolving them from their remotes instead of from local source, which
    /// defeats the workspace: an edit to a member is invisible to a member that
    /// fetches the same package from GitHub.
    ///
    /// **Ruled 2026-07-28, principal:** *"admit institute-owned forks to the
    /// roster. All swift-institute packages regardless of whether they're
    /// forks."*
    ///
    /// Discovery only ever enumerates repositories *inside*
    /// ``Workspace/Inventory/Policy/organizations``, so every repository this
    /// type judges is institute-owned by construction and the ruling admits all
    /// of them. Do not reintroduce the case without a new ruling; to keep one
    /// specific fork off the roster, name it in
    /// ``Workspace/Inventory/Policy/denied``, which is what that set is for.
    ///
    /// **The ruling covers forks only.** It says nothing about `private`
    /// repositories, and `visibility` still excludes them.
    public enum Reason: Equatable, Sendable {
        case archived
        case disabled
        case visibility(GitHub.Repository.Visibility)
        case denied
        case absent
        case kind(GitHub.Repository.Content.Kind)
    }
}
