public import JSON

extension Workspace.Peer {
    /// One repository record in a peer institute's inventory.
    ///
    /// The record mirrors ``Workspace/Repository`` minus `layer`: peer
    /// institutes are organized org-per-domain directly under their root,
    /// not through this Institute's layer structure, so a peer record's
    /// location is a pure function of `organization` and `name`
    /// (``Workspace/Peer/Layout``).
    public struct Repository: Equatable, Sendable, JSON.Serializable {
        public let name: Swift.String
        public let url: Swift.String
        public let organization: Swift.String

        public init(
            name: Swift.String,
            url: Swift.String,
            organization: Swift.String
        ) {
            self.name = name
            self.url = url
            self.organization = organization
        }
    }
}

extension Workspace.Peer.Repository {
    public static func serialize(_ value: Self) -> JSON {
        [
            "name": value.name.json,
            "url": value.url.json,
            "organization": value.organization.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Set<Swift.String> = ["name", "url", "organization"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "peer repository keys name, url, and organization",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let name = object["name"] else { throw .missingKey("name") }
        guard let url = object["url"] else { throw .missingKey("url") }
        guard let organization = object["organization"] else { throw .missingKey("organization") }

        return try Self(
            name: Swift.String(json: name),
            url: Swift.String(json: url),
            organization: Swift.String(json: organization)
        )
    }
}
