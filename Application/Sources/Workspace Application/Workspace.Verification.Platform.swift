public import JSON

extension Workspace.Verification {
    /// The supported-platform scope a receipt records.
    ///
    /// `declared` is the caller-supplied `platform-support` input — the
    /// same typed `with:` key the programme's caller census already
    /// tracks across the fleet (§2.7) — carried verbatim, never
    /// reinterpreted. `measured` is the one platform this particular run
    /// actually executed on (``Workspace/Verification/Environment/currentOS``).
    /// A receipt whose `declared` names platforms this run never measured
    /// is not a defect in this type; it is the reader's signal that full
    /// platform coverage needs more than one receipt.
    public struct Platform: Equatable, Sendable, JSON.Serializable {
        public let declared: [Swift.String]
        public let measured: Swift.String

        public init(declared: [Swift.String], measured: Swift.String) {
            self.declared = declared
            self.measured = measured
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "declared": value.declared.json,
                "measured": value.measured.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let declared = object["declared"] else { throw .missingKey("declared") }
            guard let measured = object["measured"] else { throw .missingKey("measured") }
            return try Self(
                declared: [Swift.String](json: declared),
                measured: Swift.String(json: measured)
            )
        }
    }
}
