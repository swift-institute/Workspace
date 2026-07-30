public import JSON

extension Workspace.Pages {
    /// The three kinds of authored page this instrument enumerates.
    public enum Kind: Swift.String, Swift.CaseIterable, Equatable, Sendable, JSON.Serializable {
        case readme
        case docc
        case organizationProfile = "organization-profile"

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let kind = Self(rawValue: value) else {
                throw .typeMismatch(expected: "page kind", got: value)
            }
            return kind
        }
    }
}
