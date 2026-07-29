extension Workspace.Dependency.Source {
    /// One manifest blob named by a repository tree.
    public struct Blob: Equatable, Sendable {
        public let path: Swift.String
        public let object: Swift.String

        public init(path: Swift.String, object: Swift.String) {
            self.path = path
            self.object = object
        }
    }
}
