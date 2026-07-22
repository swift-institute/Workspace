public import GitHub

extension Workspace.Inventory {
    public enum Error<Listing, Content>: Swift.Error, Sendable
    where
        Listing: Swift.Error & Sendable,
        Content: Swift.Error & Sendable
    {
        case cancellation
        case repositories(
            GitHub.Organization.Name,
            GitHub.Organization.Repositories.Traversal.Error<Listing>
        )
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
