public import JSON

extension Workspace.Conversion {
    /// One cohort repository's conversion record.
    ///
    /// `preConversionHead` is the pinned `main` SHA the receipt seals
    /// against; `postConversionHead` and `remoteStateSnapshotDigest` are
    /// `nil` until the canary run converts and snapshots the repository —
    /// recorded as absent, never guessed or backfilled by this type.
    public struct Repository: Equatable, Sendable, JSON.Serializable {
        public let coordinate: Workspace.Repository.Key
        public let layer: Workspace.Layer
        public let cloneURL: Swift.String
        public let preConversionHead: Swift.String
        public let postConversionHead: Swift.String?
        public let remoteStateSnapshotDigest: Swift.String?

        public init(
            coordinate: Workspace.Repository.Key,
            layer: Workspace.Layer,
            cloneURL: Swift.String,
            preConversionHead: Swift.String,
            postConversionHead: Swift.String? = nil,
            remoteStateSnapshotDigest: Swift.String? = nil
        ) {
            self.coordinate = coordinate
            self.layer = layer
            self.cloneURL = cloneURL
            self.preConversionHead = preConversionHead
            self.postConversionHead = postConversionHead
            self.remoteStateSnapshotDigest = remoteStateSnapshotDigest
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "coordinate": value.coordinate.json,
                "layer": value.layer.json,
                "cloneURL": value.cloneURL.json,
                "preConversionHead": value.preConversionHead.json,
                "postConversionHead": value.postConversionHead.json,
                "remoteStateSnapshotDigest": value.remoteStateSnapshotDigest.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let coordinate = object["coordinate"] else { throw .missingKey("coordinate") }
            guard let layer = object["layer"] else { throw .missingKey("layer") }
            guard let cloneURL = object["cloneURL"] else { throw .missingKey("cloneURL") }
            guard let preConversionHead = object["preConversionHead"] else {
                throw .missingKey("preConversionHead")
            }
            return try Self(
                coordinate: Workspace.Repository.Key(json: coordinate),
                layer: Workspace.Layer(json: layer),
                cloneURL: Swift.String(json: cloneURL),
                preConversionHead: Swift.String(json: preConversionHead),
                postConversionHead: Swift.String?(json: object["postConversionHead"] ?? .null),
                remoteStateSnapshotDigest: Swift.String?(
                    json: object["remoteStateSnapshotDigest"] ?? .null
                )
            )
        }
    }
}

extension Workspace.Conversion.Repository {
    package static func precedes(_ lhs: Self, _ rhs: Self) -> Swift.Bool {
        Workspace.Repository.Key.precedes(lhs.coordinate, rhs.coordinate)
    }
}
