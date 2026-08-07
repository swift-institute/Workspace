extension Workspace.Architecture.Epoch {
    /// The epoch's identity within its owner's migration history.
    public struct Identifier: Sendable, Equatable, Hashable, RawRepresentable {
        public let rawValue: Swift.String

        public init(rawValue: Swift.String) {
            self.rawValue = rawValue
        }
    }
}

extension Workspace.Architecture.Epoch.Identifier: Comparable {
    public static func < (
        lhs: Workspace.Architecture.Epoch.Identifier,
        rhs: Workspace.Architecture.Epoch.Identifier
    ) -> Swift.Bool {
        lhs.rawValue < rhs.rawValue
    }
}
