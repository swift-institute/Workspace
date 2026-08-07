extension Workspace.Architecture {
    /// A semantic concept a package root owns.
    ///
    /// Names are presentation; the ``Identifier`` is the identity. Two
    /// similarly named packages are the same concept only when their
    /// identifiers match — never on name similarity alone.
    public struct Concept: Sendable, Equatable, Hashable {
        public let identifier: Identifier
        public let name: Swift.String

        public init(identifier: Identifier, name: Swift.String) {
            self.identifier = identifier
            self.name = name
        }
    }
}
