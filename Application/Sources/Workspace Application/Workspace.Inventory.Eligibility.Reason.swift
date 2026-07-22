public import GitHub

extension Workspace.Inventory.Eligibility {
    public enum Reason: Equatable, Sendable {
        case archived
        case disabled
        case fork
        case visibility(GitHub.Repository.Visibility)
        case denied
        case absent
        case kind(GitHub.Repository.Content.Kind)
    }
}
