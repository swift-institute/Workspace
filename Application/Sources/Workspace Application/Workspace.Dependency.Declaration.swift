extension Workspace.Dependency {
    /// One `.package(...)` call found in a manifest.
    public enum Declaration: Equatable, Sendable {
        case url(Swift.String, line: Swift.Int)
        case path(Swift.String?, line: Swift.Int)
        case registry(Swift.String?, line: Swift.Int)
        case malformed(Swift.String, line: Swift.Int)
    }
}

extension Workspace.Dependency.Declaration {
    public var line: Swift.Int {
        switch self {
        case .url(_, let line), .path(_, let line), .registry(_, let line),
            .malformed(_, let line):
            line
        }
    }
}
