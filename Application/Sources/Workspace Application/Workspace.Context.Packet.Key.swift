extension Workspace.Context.Packet {
    public struct Key: Equatable, Sendable {
        public let repository: Workspace.Repository.Key
        public let number: Swift.Int

        public init?(argument: Swift.String) {
            let parts = argument.split(separator: "#", omittingEmptySubsequences: false)
            guard
                parts.count == 2,
                let repository = Workspace.Repository.Key(identity: Swift.String(parts[0])),
                let number = Swift.Int(parts[1]), number > 0
            else { return nil }
            self.repository = repository
            self.number = number
        }

        public var identity: Swift.String { "\(repository.identity)#\(number)" }
    }
}
