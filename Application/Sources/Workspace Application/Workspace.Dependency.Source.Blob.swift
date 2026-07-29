extension Workspace.Dependency.Source {
    /// One manifest blob named by a repository tree.
    struct Blob: Equatable, Sendable {
        let path: Swift.String
        let object: Swift.String

        init(path: Swift.String, object: Swift.String) {
            self.path = path
            self.object = object
        }
    }
}
