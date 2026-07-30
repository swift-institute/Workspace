public import JSON

extension Workspace.Conversion {
    /// One retained derived block's byte-compare drift check — the check
    /// Goal #126's completion criteria require of every retained derived
    /// block.
    public struct DriftCheck: Equatable, Sendable, JSON.Serializable {
        public let coordinate: Workspace.Repository.Key
        public let path: Swift.String
        public let canonicalSource: Workspace.Repository.Key
        public let outcome: Outcome

        public init(
            coordinate: Workspace.Repository.Key,
            path: Swift.String,
            canonicalSource: Workspace.Repository.Key,
            outcome: Outcome
        ) {
            self.coordinate = coordinate
            self.path = path
            self.canonicalSource = canonicalSource
            self.outcome = outcome
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "coordinate": value.coordinate.json,
                "path": value.path.json,
                "canonicalSource": value.canonicalSource.json,
                "outcome": value.outcome.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let coordinate = object["coordinate"] else { throw .missingKey("coordinate") }
            guard let path = object["path"] else { throw .missingKey("path") }
            guard let canonicalSource = object["canonicalSource"] else {
                throw .missingKey("canonicalSource")
            }
            guard let outcome = object["outcome"] else { throw .missingKey("outcome") }
            return try Self(
                coordinate: Workspace.Repository.Key(json: coordinate),
                path: Swift.String(json: path),
                canonicalSource: Workspace.Repository.Key(json: canonicalSource),
                outcome: Outcome(json: outcome)
            )
        }
    }
}

extension Workspace.Conversion.DriftCheck {
    /// Sorted by (`coordinate`, `path`) — the receipt's drift-check
    /// ordering.
    package static func precedes(_ lhs: Self, _ rhs: Self) -> Swift.Bool {
        if lhs.coordinate != rhs.coordinate {
            return Workspace.Repository.Key.precedes(lhs.coordinate, rhs.coordinate)
        }
        return lhs.path < rhs.path
    }
}
