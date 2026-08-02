public import JSON

extension Workspace {
    public enum Layer: Swift.String, Swift.CaseIterable, Sendable, JSON.Serializable {
        case primitives
        case standards
        case foundations
        case components
        case applications
    }
}

extension Workspace.Layer {
    /// The stable inventory wire token owned by this enum.
    public var token: Swift.String { rawValue }

    /// The GitHub organization that is this layer's root: the directory
    /// a layer's packages materialize under, and the organization whose
    /// repositories sit directly in it. Organizations that are not a
    /// layer root — specification authorities, vendors, jurisdictions —
    /// nest under their layer's root per ruling 139.
    public var organization: Swift.String {
        switch self {
        case .primitives: "swift-primitives"
        case .standards: "swift-standards"
        case .foundations: "swift-foundations"
        case .components: "swift-components"
        case .applications: "swift-applications"
        }
    }

    package var order: Int {
        switch self {
        case .primitives: 1
        case .standards: 2
        case .foundations: 3
        case .components: 4
        case .applications: 5
        }
    }

    public static func serialize(_ value: Self) -> JSON {
        value.token.json
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        let value = try Swift.String(json: json)
        guard let layer = Self(rawValue: value) else {
            throw .typeMismatch(expected: "Institute layer", got: value)
        }
        return layer
    }
}
