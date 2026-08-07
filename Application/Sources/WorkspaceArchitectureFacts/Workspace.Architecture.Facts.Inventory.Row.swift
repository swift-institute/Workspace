public import JSON
public import WorkspaceArchitectureModel

extension Workspace.Architecture.Facts.Inventory {
    /// One inventory row: the coordinate and layer `Institute.json` records
    /// for a package root.
    public struct Row: Sendable, Equatable, JSON.Serializable {
        public let organization: Swift.String
        public let name: Swift.String
        public let layer: Workspace.Architecture.Layer
        public let url: Swift.String

        public init(
            organization: Swift.String,
            name: Swift.String,
            layer: Workspace.Architecture.Layer,
            url: Swift.String
        ) {
            self.organization = organization
            self.name = name
            self.layer = layer
            self.url = url
        }
    }
}

extension Workspace.Architecture.Facts.Inventory.Row {
    public var owner: Workspace.Architecture.Owner {
        .init(organization: organization, name: name)
    }
}

extension Workspace.Architecture.Facts.Inventory.Row {
    public static func serialize(_ value: Self) -> JSON {
        [
            "layer": value.layer.name.json,
            "name": value.name.json,
            "organization": value.organization.json,
            "url": value.url.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let layer = object["layer"] else { throw .missingKey("layer") }
        guard let name = object["name"] else { throw .missingKey("name") }
        guard let organization = object["organization"] else {
            throw .missingKey("organization")
        }
        guard let url = object["url"] else { throw .missingKey("url") }
        let layerName = try Swift.String(json: layer)
        guard let parsed = Workspace.Architecture.Layer(name: layerName) else {
            throw .typeMismatch(
                expected: "primitives, standards, or foundations",
                got: layerName
            )
        }
        return try Self(
            organization: Swift.String(json: organization),
            name: Swift.String(json: name),
            layer: parsed,
            url: Swift.String(json: url)
        )
    }
}
