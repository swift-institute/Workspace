public import JSON

extension Workspace.Conversion {
    /// One authored page's conversion record.
    ///
    /// `postConversionBlob` is `nil` until the canary run converts the
    /// page. `disposition` is the closed ``Disposition`` enum — see that
    /// type for the closure discipline.
    public struct Page: Equatable, Sendable, JSON.Serializable {
        public let coordinate: Workspace.Repository.Key
        public let kind: Workspace.Pages.Kind
        public let path: Swift.String
        public let preConversionBlob: Swift.String
        public let postConversionBlob: Swift.String?
        public let disposition: Disposition

        public init(
            coordinate: Workspace.Repository.Key,
            kind: Workspace.Pages.Kind,
            path: Swift.String,
            preConversionBlob: Swift.String,
            postConversionBlob: Swift.String? = nil,
            disposition: Disposition
        ) {
            self.coordinate = coordinate
            self.kind = kind
            self.path = path
            self.preConversionBlob = preConversionBlob
            self.postConversionBlob = postConversionBlob
            self.disposition = disposition
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "coordinate": value.coordinate.json,
                "kind": value.kind.json,
                "path": value.path.json,
                "preConversionBlob": value.preConversionBlob.json,
                "postConversionBlob": value.postConversionBlob.json,
                "disposition": value.disposition.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let coordinate = object["coordinate"] else { throw .missingKey("coordinate") }
            guard let kind = object["kind"] else { throw .missingKey("kind") }
            guard let path = object["path"] else { throw .missingKey("path") }
            guard let preConversionBlob = object["preConversionBlob"] else {
                throw .missingKey("preConversionBlob")
            }
            guard let disposition = object["disposition"] else { throw .missingKey("disposition") }
            return try Self(
                coordinate: Workspace.Repository.Key(json: coordinate),
                kind: Workspace.Pages.Kind(json: kind),
                path: Swift.String(json: path),
                preConversionBlob: Swift.String(json: preConversionBlob),
                postConversionBlob: Swift.String?(json: object["postConversionBlob"] ?? .null),
                disposition: Disposition(json: disposition)
            )
        }
    }
}

extension Workspace.Conversion.Page {
    /// Sorted by (`coordinate`, `kind`, `path`) — the receipt's page
    /// ordering.
    package static func precedes(_ lhs: Self, _ rhs: Self) -> Swift.Bool {
        if lhs.coordinate != rhs.coordinate {
            return Workspace.Repository.Key.precedes(lhs.coordinate, rhs.coordinate)
        }
        if lhs.kind != rhs.kind {
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return lhs.path < rhs.path
    }
}
