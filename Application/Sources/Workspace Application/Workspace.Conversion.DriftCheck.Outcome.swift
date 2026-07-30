public import JSON

extension Workspace.Conversion.DriftCheck {
    /// The closed set of outcomes a byte-compare drift check can record.
    public enum Outcome: Swift.String, Swift.CaseIterable, Equatable, Sendable, JSON.Serializable {
        case match
        case mismatch
        case unmeasured

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let outcome = Self(rawValue: value) else {
                throw .typeMismatch(expected: "drift check outcome", got: value)
            }
            return outcome
        }
    }
}
