extension Workspace.Architecture.Concept {
    /// The concept's identity.
    ///
    /// Derived deterministically from the owning coordinate
    /// (`organization/name`); it is the only ground on which two facts may
    /// be judged to describe the same concept.
    public struct Identifier: Sendable, Equatable, Hashable, RawRepresentable {
        public let rawValue: Swift.String

        public init(rawValue: Swift.String) {
            self.rawValue = rawValue
        }

        public init(owner: Workspace.Architecture.Owner) {
            self.rawValue = "\(owner.organization)/\(owner.name)"
        }
    }
}

extension Workspace.Architecture.Concept.Identifier: CustomStringConvertible {
    public var description: Swift.String {
        rawValue
    }
}

extension Workspace.Architecture.Concept.Identifier: Comparable {
    public static func < (
        lhs: Workspace.Architecture.Concept.Identifier,
        rhs: Workspace.Architecture.Concept.Identifier
    ) -> Swift.Bool {
        lhs.rawValue < rhs.rawValue
    }
}
