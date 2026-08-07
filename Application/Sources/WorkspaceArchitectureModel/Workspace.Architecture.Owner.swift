extension Workspace.Architecture {
    /// The exact semantic owner of one package root: the organization and
    /// repository name that own a concept.
    ///
    /// Ownership is an identity, never a display string; two owners are the
    /// same exactly when both components match.
    public struct Owner: Sendable, Equatable, Hashable {
        public let organization: Swift.String
        public let name: Swift.String

        public init(organization: Swift.String, name: Swift.String) {
            self.organization = organization
            self.name = name
        }
    }
}

extension Workspace.Architecture.Owner: Comparable {
    public static func < (
        lhs: Workspace.Architecture.Owner,
        rhs: Workspace.Architecture.Owner
    ) -> Swift.Bool {
        (lhs.organization, lhs.name) < (rhs.organization, rhs.name)
    }
}

extension Workspace.Architecture.Owner: CustomStringConvertible {
    public var description: Swift.String {
        "\(organization)/\(name)"
    }
}
