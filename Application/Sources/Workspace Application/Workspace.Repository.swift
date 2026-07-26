public import JSON

extension Workspace {
    public struct Repository: Equatable, Sendable, JSON.Serializable {
        public let name: Swift.String
        public let url: Swift.String
        public let organization: Swift.String
        public let layer: Layer

        public init(
            name: Swift.String,
            url: Swift.String,
            organization: Swift.String,
            layer: Layer
        ) {
            self.name = name
            self.url = url
            self.organization = organization
            self.layer = layer
        }
    }
}

extension Workspace.Repository {
    public static func serialize(_ value: Self) -> JSON {
        [
            "name": value.name.json,
            "url": value.url.json,
            "organization": value.organization.json,
            "layer": value.layer.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Set<Swift.String> = ["name", "url", "organization", "layer"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "repository keys name, url, organization, and layer",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let name = object["name"] else { throw .missingKey("name") }
        guard let url = object["url"] else { throw .missingKey("url") }
        guard let organization = object["organization"] else { throw .missingKey("organization") }
        guard let layer = object["layer"] else { throw .missingKey("layer") }

        return try Self(
            name: Swift.String(json: name),
            url: Swift.String(json: url),
            organization: Swift.String(json: organization),
            layer: Workspace.Layer(json: layer)
        )
    }
}
