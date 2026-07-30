public import JSON

extension Workspace.Pages {
    /// One selected repository's page enumeration.
    ///
    /// `materialization` renders ``Workspace/Doctor/Materialization/State``
    /// verbatim rather than importing it as a typed field, matching the
    /// doc-comment discipline ``Workspace/Coherence/Instrument`` already
    /// uses for `selection`. A repository whose state is not `.canonical`
    /// carries an empty `pages` — its state is recorded, never papered
    /// over with a directory walk this instrument is not entitled to make.
    public struct Repository: Equatable, Sendable, JSON.Serializable {
        public let organization: Swift.String
        public let name: Swift.String
        public let layer: Workspace.Layer
        public let materialization: Swift.String
        public let pages: [Page]

        public init(
            organization: Swift.String,
            name: Swift.String,
            layer: Workspace.Layer,
            materialization: Swift.String,
            pages: [Page]
        ) {
            self.organization = organization
            self.name = name
            self.layer = layer
            self.materialization = materialization
            self.pages = pages
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "organization": value.organization.json,
                "name": value.name.json,
                "layer": value.layer.json,
                "materialization": value.materialization.json,
                "pages": value.pages.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let organization = object["organization"] else { throw .missingKey("organization") }
            guard let name = object["name"] else { throw .missingKey("name") }
            guard let layer = object["layer"] else { throw .missingKey("layer") }
            guard let materialization = object["materialization"] else {
                throw .missingKey("materialization")
            }
            guard let pages = object["pages"] else { throw .missingKey("pages") }
            return try Self(
                organization: Swift.String(json: organization),
                name: Swift.String(json: name),
                layer: Workspace.Layer(json: layer),
                materialization: Swift.String(json: materialization),
                pages: [Page](json: pages)
            )
        }
    }
}
