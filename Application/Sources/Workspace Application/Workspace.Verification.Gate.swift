public import JSON

extension Workspace.Verification {
    /// One required-layer-gate obligation and whether it was satisfied.
    ///
    /// The required set itself is caller-supplied (the control plane
    /// already knows which operations a subject's layer requires — see
    /// ``Run``'s documentation for why this instrument does not re-derive
    /// layer policy). What this type records is Workspace's own
    /// determination of whether that obligation was met: `name` names the
    /// ``Operation/Kind``, `satisfied` is `true` only when every result for
    /// that kind reached ``Operation/Outcome/isSatisfying``.
    public struct Gate: Equatable, Sendable, JSON.Serializable {
        public let name: Swift.String
        public let satisfied: Swift.Bool
        public let reason: Swift.String?

        public init(name: Swift.String, satisfied: Swift.Bool, reason: Swift.String? = nil) {
            self.name = name
            self.satisfied = satisfied
            self.reason = reason
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "name": value.name.json,
                "satisfied": value.satisfied.json,
                "reason": value.reason.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let name = object["name"] else { throw .missingKey("name") }
            guard let satisfied = object["satisfied"] else { throw .missingKey("satisfied") }
            return try Self(
                name: Swift.String(json: name),
                satisfied: Swift.Bool(json: satisfied),
                reason: Swift.String?(json: object["reason"] ?? .null)
            )
        }
    }
}
