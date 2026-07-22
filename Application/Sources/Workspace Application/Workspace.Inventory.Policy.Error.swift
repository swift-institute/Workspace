public import GitHub

extension Workspace.Inventory.Policy {
    public enum Error: Swift.Error, Equatable, Sendable {
        case organization(GitHub.Organization.Name)
        case deny(Workspace.Repository.Key)
    }
}
