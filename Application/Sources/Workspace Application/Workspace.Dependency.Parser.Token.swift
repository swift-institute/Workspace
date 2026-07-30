extension Workspace.Dependency.Parser {
    struct Token: Equatable, Sendable {
        let kind: Kind
        let line: Swift.Int
        let offset: Swift.Int
    }
}
