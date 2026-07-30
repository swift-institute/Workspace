public import JSON

extension Workspace.Conversion.Page {
    /// The closed set of outcomes one page's conversion can record.
    ///
    /// There is no fifth case and no free-text disposition: `unmeasured`
    /// is a recorded outcome, never an omission, and an unknown string
    /// fails deserialization rather than decoding to a default (issue #83
    /// Part 2's disposition-closure acceptance criterion).
    public enum Disposition: Swift.String, Swift.CaseIterable, Equatable, Sendable, JSON.Serializable {
        case converted
        case unchanged
        case notApplicable = "not-applicable"
        case unmeasured

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let disposition = Self(rawValue: value) else {
                throw .typeMismatch(expected: "page disposition", got: value)
            }
            return disposition
        }
    }
}
