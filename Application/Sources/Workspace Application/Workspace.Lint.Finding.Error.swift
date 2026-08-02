extension Workspace.Lint.Finding {
    /// Why a purported structured finding document cannot be consumed.
    package enum Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        case malformed(Swift.String)
    }
}

extension Workspace.Lint.Finding.Error {
    package var description: Swift.String {
        switch self {
        case .malformed(let reason): reason
        }
    }
}
