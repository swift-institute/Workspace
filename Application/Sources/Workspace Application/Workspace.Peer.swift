public import JSON

extension Workspace {
    /// One peer institute declared in the committed `Peers.json` registry.
    ///
    /// A peer institute is a sibling ecosystem — its checkout root sits
    /// beside this hierarchy root under one entry directory, carrying the
    /// peer's own name. The peer owns its package inventory: `inventory`
    /// is the peer-root-relative path of a per-ecosystem inventory file
    /// (``Workspace/Peer/Configuration``) that lives inside the peer's own
    /// control-plane checkout, so declaring a peer here publishes no peer
    /// package data and adopting the peer remains opt-in per checkout —
    /// a checkout without the peer root materialized has simply not
    /// opted in.
    public struct Peer: Equatable, Sendable, JSON.Serializable {
        public let name: Swift.String
        public let inventory: Swift.String

        public init(name: Swift.String, inventory: Swift.String) {
            self.name = name
            self.inventory = inventory
        }
    }
}

extension Workspace.Peer {
    public static func serialize(_ value: Self) -> JSON {
        [
            "name": value.name.json,
            "inventory": value.inventory.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Set<Swift.String> = ["name", "inventory"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "peer keys name and inventory",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let name = object["name"] else { throw .missingKey("name") }
        guard let inventory = object["inventory"] else { throw .missingKey("inventory") }

        return try Self(
            name: Swift.String(json: name),
            inventory: Swift.String(json: inventory)
        )
    }
}
