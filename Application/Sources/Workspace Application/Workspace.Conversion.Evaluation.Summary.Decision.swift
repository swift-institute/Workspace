public import JSON

extension Workspace.Conversion.Evaluation.Summary {
    /// Protocol §6's decision mapping, closed to exactly its four outcomes.
    public enum Decision: Swift.String, Swift.CaseIterable, Equatable, Sendable, JSON.Serializable {
        case proceed
        case abort
        case inconclusive
        case invalid

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let decision = Self(rawValue: value) else {
                throw .typeMismatch(expected: "evaluation decision", got: value)
            }
            return decision
        }
    }
}
