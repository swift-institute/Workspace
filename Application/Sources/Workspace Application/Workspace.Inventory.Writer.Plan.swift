extension Workspace.Inventory.Writer {
    public enum Plan: Equatable, Sendable {
        case current
        case replace(Swift.String)
    }
}
