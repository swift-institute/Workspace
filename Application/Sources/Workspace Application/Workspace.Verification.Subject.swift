public import GitHub
public import JSON

extension Workspace.Verification {
    /// A repository's visibility as recorded on a receipt.
    ///
    /// Caller-supplied, never interrogated live: minting an authenticated
    /// GitHub read on every seal would make this instrument's offline,
    /// fast, credential-free posture into a network dependency for a fact
    /// the control plane dispatching verification already resolved from
    /// the effective inventory. ``unmeasured`` exists because "the caller
    /// did not know" must be representable without silently defaulting to
    /// either visibility.
    public enum Visibility: Swift.String, Equatable, Sendable, JSON.Serializable {
        case `public`
        case `private`
        case unmeasured

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let visibility = Self(rawValue: value) else {
                throw .typeMismatch(expected: "public, private, or unmeasured", got: value)
            }
            return visibility
        }
    }
}

extension Workspace.Verification {
    /// The subject one verification run measured: its stable coordinate
    /// and visibility, its default branch, and the commit it was claimed
    /// and observed to be standing on.
    ///
    /// ``claimedHead`` and ``observedHead`` are carried separately, on
    /// purpose, even though a sealed receipt can only exist when they are
    /// equal (``Workspace/Verification/Run`` refuses to seal otherwise):
    /// keeping both fields lets a reader confirm the equality from the
    /// receipt itself, rather than trusting a producer's unfalsifiable
    /// claim to have checked it.
    public struct Subject: Equatable, Sendable, JSON.Serializable {
        public let coordinate: Workspace.Repository.Key
        public let visibility: Visibility
        public let visibilityReason: Swift.String?
        public let defaultBranch: Swift.String
        public let claimedHead: Swift.String
        public let observedHead: Swift.String
        public let dirty: Swift.Bool

        public init(
            coordinate: Workspace.Repository.Key,
            visibility: Visibility,
            visibilityReason: Swift.String? = nil,
            defaultBranch: Swift.String,
            claimedHead: Swift.String,
            observedHead: Swift.String,
            dirty: Swift.Bool
        ) {
            self.coordinate = coordinate
            self.visibility = visibility
            self.visibilityReason = visibilityReason
            self.defaultBranch = defaultBranch
            self.claimedHead = claimedHead
            self.observedHead = observedHead
            self.dirty = dirty
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "coordinate": value.coordinate.json,
                "visibility": value.visibility.json,
                "visibilityReason": value.visibilityReason.json,
                "defaultBranch": value.defaultBranch.json,
                "claimedHead": value.claimedHead.json,
                "observedHead": value.observedHead.json,
                "dirty": value.dirty.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let coordinate = object["coordinate"] else { throw .missingKey("coordinate") }
            guard let visibility = object["visibility"] else { throw .missingKey("visibility") }
            guard let defaultBranch = object["defaultBranch"] else { throw .missingKey("defaultBranch") }
            guard let claimedHead = object["claimedHead"] else { throw .missingKey("claimedHead") }
            guard let observedHead = object["observedHead"] else { throw .missingKey("observedHead") }
            guard let dirty = object["dirty"] else { throw .missingKey("dirty") }
            return try Self(
                coordinate: Workspace.Repository.Key(json: coordinate),
                visibility: Visibility(json: visibility),
                visibilityReason: Swift.String?(json: object["visibilityReason"] ?? .null),
                defaultBranch: Swift.String(json: defaultBranch),
                claimedHead: Swift.String(json: claimedHead),
                observedHead: Swift.String(json: observedHead),
                dirty: Swift.Bool(json: dirty)
            )
        }
    }
}
