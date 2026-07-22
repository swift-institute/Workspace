public import JSON

extension Workspace {
    public enum Layer: Swift.String, Sendable, JSON.Serializable {
        case primitives
        case standards
        case foundations

        public static func serialize(_ value: Self) -> JSON {
            value.rawValue.json
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let layer = Self(rawValue: value) else {
                throw .typeMismatch(expected: "Institute layer", got: value)
            }
            return layer
        }
    }
}
