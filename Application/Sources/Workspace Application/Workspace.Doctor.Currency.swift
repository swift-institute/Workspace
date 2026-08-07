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
    /// `Institute.json` agrees with a live discovery of the Institute
    /// organizations. Needs Institute access: an authenticated GitHub
    /// client the contributor path does not carry.
    ///
    /// ## The join key is the full coordinate, not the bare name
    ///
    /// Joining on `name` alone made two drift shapes invisible: a
    /// repository moved across organizations still matched by name while
    /// its recorded `organization` (and `url`) went stale, and any wrong
    /// `organization`/`layer`/`url` paired with a correct `name` never
    /// reached a comparison at all. Flagged in the gating ruling on #43
    /// (comment 5134728718), fixed here as Workspace#84.
    ///
    /// The coordinate is `(organization, name)`. A name that matches at
    /// one coordinate on the committed side and a different coordinate on
    /// the discovered side is a cross-org move (``Presence/moved(from:to:)``),
    /// reported with both organizations named rather than as two
    /// unrelated orphans. A name that matches at the same coordinate on
    /// both sides is compared field by field: ``Workspace/Layer`` can
    /// disagree (an org's policy layer changed, or the committed
    /// annotation is stale) and is reported as
    /// ``Presence/mismatch(field:committed:discovered:)``.
    ///
    /// `url` is not compared here even though the issue names it: this
    /// runs over a `Workspace.Configuration` that has already passed
    /// `validated()`, which refuses to load a repository whose `url`
    /// disagrees with its own `name`/`organization` — so once the
    /// coordinate matches, `url` is provably equal by construction. The
    /// coordinate join *is* the url validation.
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
                    message: "\(repository.name): in Institute.json but not discovered on GitHub"
                )
            ]
        case .discovered:
            [
                .init(
                    severity: .error,
                    message: "\(repository.name): discovered on GitHub but missing from Institute.json"
                )
            ]
        case .moved(let from, let to):
            [
                .init(
                    severity: .error,
                    message:
                        "\(repository.name): organization mismatch — Institute.json has \(from), GitHub discovery has \(to)"
                )
            ]
        case .mismatch(let field, let committed, let discovered):
            [
                .init(
                    severity: .error,
                    message:
                        "\(repository.name): \(field) mismatch — Institute.json has \(committed), GitHub discovery has \(discovered)"
                )
            ]
        }
    }

    func currency(_ discovery: Workspace.Inventory.Discovery) -> Outcome {
        struct Coordinate: Hashable {
            let organization: Swift.String
            let name: Swift.String
        }

        var committedByCoordinate: [Coordinate: Workspace.Repository] = [:]
        for repository in configuration.repositories {
            committedByCoordinate[.init(organization: repository.organization, name: repository.name)] =
                repository
        }

        var discoveredByCoordinate: [Coordinate: Workspace.Inventory.Repository] = [:]
        for repository in discovery.repositories {
            let coordinate = Coordinate(
                organization: repository.key.owner.underlying,
                name: repository.key.name.underlying
            )
            discoveredByCoordinate[coordinate] = repository
        }

        let matched = Set(committedByCoordinate.keys).intersection(discoveredByCoordinate.keys)

        var population: [Currency] = matched.map { coordinate in
            let committed = committedByCoordinate[coordinate]!
            let discovered = discoveredByCoordinate[coordinate]!
            guard committed.layer == discovered.layer else {
                return .init(
                    name: coordinate.name,
                    presence: .mismatch(
                        field: "layer",
                        committed: committed.layer.rawValue,
                        discovered: discovered.layer.rawValue
                    )
                )
            }
            return .init(name: coordinate.name, presence: .both)
        }

        let committedOnly = committedByCoordinate.filter { !matched.contains($0.key) }
        var discoveredOnly = discoveredByCoordinate.filter { !matched.contains($0.key) }

        // A name orphaned on both sides at different coordinates is a
        // cross-org move, not two unrelated findings — pair them before
        // falling back to plain orphans.
        for (coordinate, committed) in committedOnly {
            guard
                let partner = discoveredOnly.first(where: { $0.key.name == coordinate.name })
            else {
                population.append(.init(name: coordinate.name, presence: .committed))
                continue
            }
            population.append(
                .init(
                    name: coordinate.name,
                    presence: .moved(from: committed.organization, to: partner.key.organization)
                )
            )
            discoveredOnly.removeValue(forKey: partner.key)
        }
        for (coordinate, _) in discoveredOnly {
            population.append(.init(name: coordinate.name, presence: .discovered))
        }

        return Self.currency.run(
            population: population.sorted { $0.name < $1.name },
            inventory: configuration.repositories.count
        )
    }
}
