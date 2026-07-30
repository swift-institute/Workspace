extension Workspace.Dependency.Pending {
    struct Edge: Equatable, Sendable {
        let repository: Workspace.Repository.Key
        let manifest: Swift.String
        let reference: Swift.String
        let revision: Swift.String
        let line: Swift.Int
        let declaredURL: Swift.String
        let declared: Workspace.Repository.Key
    }
}
