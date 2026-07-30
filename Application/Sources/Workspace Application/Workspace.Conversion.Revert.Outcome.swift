public import JSON

extension Workspace.Conversion.Revert {
    public enum Outcome: Swift.String, Swift.CaseIterable, Equatable, Sendable, JSON.Serializable {
        case restored
        case failed

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let outcome = Self(rawValue: value) else {
                throw .typeMismatch(expected: "revert outcome", got: value)
            }
            return outcome
        }
    }
}
