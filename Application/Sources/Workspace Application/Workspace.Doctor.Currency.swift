import Tagged_Primitives

extension Workspace.Doctor {
    /// One repository name's membership across the committed inventory
    /// and a live discovery.
    public struct Currency: Equatable, Sendable {
        public let name: Swift.String
        public let presence: Presence

        public init(name: Swift.String, presence: Presence) {
            self.name = name
            self.presence = presence
        }
    }
}

extension Workspace.Doctor {
    /// `Workspace.json` agrees with a live discovery of the Institute
    /// organizations. Needs Institute access: an authenticated GitHub
    /// client the contributor path does not carry.
    public static let currency = Check<Currency>(
        name: "inventory-currency",
        scope: .instituteInternal,
        controls: .init(
            positive: .init(name: "control", presence: .committed),
            negative: .init(name: "control", presence: .both)
        )
    ) { repository in
        switch repository.presence {
        case .both:
            []
        case .committed:
            [
                .init(
                    severity: .error,
                    message: "\(repository.name): in Workspace.json but not discovered on GitHub"
                )
            ]
        case .discovered:
            [
                .init(
                    severity: .error,
                    message: "\(repository.name): discovered on GitHub but missing from Workspace.json"
                )
            ]
        }
    }

    func currency(_ discovery: Workspace.Inventory.Discovery) -> Outcome {
        let committed = Set(configuration.repositories.map(\.name))
        let discovered = Set(discovery.repositories.map(\.key.name.underlying))
        return Self.currency.run(
            population: committed.union(discovered).sorted().map { name in
                .init(
                    name: name,
                    presence: committed.contains(name)
                        ? (discovered.contains(name) ? .both : .committed)
                        : .discovered
                )
            },
            inventory: configuration.repositories.count
        )
    }
}
