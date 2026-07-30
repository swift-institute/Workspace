public import JSON

extension Workspace.Conversion.Evaluation.Trial {
    /// Protocol §1's two arms, named exactly as the protocol names them.
    public enum Arm: Swift.String, Swift.CaseIterable, Equatable, Sendable, JSON.Serializable {
        case legacy = "L"
        case converted = "C"

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let arm = Self(rawValue: value) else {
                throw .typeMismatch(expected: "trial arm", got: value)
            }
            return arm
        }
    }
}
