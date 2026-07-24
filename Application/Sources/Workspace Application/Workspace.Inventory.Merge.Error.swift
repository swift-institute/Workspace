public import GitHub
public import Tagged_Primitives

extension Workspace.Inventory.Merge {
    public enum Error: Swift.Error, Equatable, Sendable {
        case annotation(Workspace.Repository)
        case duplicate(Workspace.Repository.Key)
        case collision(
            GitHub.Repository.Name,
            Workspace.Repository.Key,
            Workspace.Repository.Key
        )
        case transfer(
            GitHub.Repository.Name,
            Workspace.Repository.Key,
            Workspace.Repository.Key,
            annotation: Workspace.Layer,
            default: Workspace.Layer
        )
    }
}
