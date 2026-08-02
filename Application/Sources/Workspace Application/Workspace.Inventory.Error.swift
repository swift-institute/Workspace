public import GitHub
public import Tagged_Primitives

extension Workspace.Inventory {
    public enum Error<Content: Swift.Error>: Swift.Error, Sendable {
        case cancellation
        case repositories(
            GitHub.Organization.Name,
            Either<Async.Lifecycle.Error, GitHub.Organization.Repositories.Traversal.Error>
        )
        /// An organization listed zero public repositories without
        /// ``Workspace/Inventory/Policy/vacant`` declaring that it may.
        ///
        /// Measured 2026-07-28, every policy organization but one lists at
        /// least one public repository. So an undeclared empty listing is not a
        /// small organization; it is a listing that failed without saying so —
        /// a token that lost visibility of the organization, a rename, or a
        /// transport that turned a refusal into an empty page.
        ///
        /// This exists because the alternative is the worst outcome available
        /// here: discovery is deterministic, so a roster generated while one
        /// organization silently returned nothing is **byte-stable and wrong**.
        /// It diffs cleanly against itself and reads as a real ecosystem
        /// change. A missing roster is recoverable; a short one that looks
        /// correct is trusted.
        case empty(GitHub.Organization.Name)
        case content(Workspace.Repository.Key, Content)
        case collision(
            GitHub.Repository.Name,
            Workspace.Repository.Key,
            Workspace.Repository.Key
        )
        case path
        case merge(Workspace.Inventory.Merge.Error)
        case workspace(Workspace.Error)
    }
}
