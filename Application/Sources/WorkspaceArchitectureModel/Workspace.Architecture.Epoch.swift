extension Workspace.Architecture {
    /// One migration epoch: a semantic-owner state and the consumers still
    /// standing on it.
    public struct Epoch: Sendable, Equatable, Hashable {
        public let identifier: Identifier
        public let owner: Owner
        public let consumers: [Owner]

        public init(identifier: Identifier, owner: Owner, consumers: [Owner]) {
            self.identifier = identifier
            self.owner = owner
            self.consumers = consumers
        }
    }
}
