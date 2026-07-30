public import JSON

extension Workspace.Pages {
    /// One authored page: a repository-relative location and what kind of
    /// page it is.
    ///
    /// `name` is empty and `layer` is `nil` for ``Kind/organizationProfile``
    /// — that page attributes to `<organization>/.github`, a coordinate
    /// this instrument never materializes and never claims a layer for.
    /// `present` records whether the page exists rather than filtering it
    /// out: a page this instrument could not or did not find on disk is
    /// still named, with `present: false`, never silently omitted (issue
    /// #82's derivation rule 5).
    public struct Page: Equatable, Sendable, JSON.Serializable {
        public let organization: Swift.String
        public let name: Swift.String
        public let layer: Workspace.Layer?
        public let kind: Kind
        public let path: Swift.String
        public let present: Swift.Bool

        public init(
            organization: Swift.String,
            name: Swift.String,
            layer: Workspace.Layer?,
            kind: Kind,
            path: Swift.String,
            present: Swift.Bool
        ) {
            self.organization = organization
            self.name = name
            self.layer = layer
            self.kind = kind
            self.path = path
            self.present = present
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "organization": value.organization.json,
                "name": value.name.json,
                "layer": value.layer.json,
                "kind": value.kind.json,
                "path": value.path.json,
                "present": value.present.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let organization = object["organization"] else { throw .missingKey("organization") }
            guard let name = object["name"] else { throw .missingKey("name") }
            guard let kind = object["kind"] else { throw .missingKey("kind") }
            guard let path = object["path"] else { throw .missingKey("path") }
            guard let present = object["present"] else { throw .missingKey("present") }
            return try Self(
                organization: Swift.String(json: organization),
                name: Swift.String(json: name),
                layer: Workspace.Layer?(json: object["layer"] ?? .null),
                kind: Kind(json: kind),
                path: Swift.String(json: path),
                present: Swift.Bool(json: present)
            )
        }
    }
}
