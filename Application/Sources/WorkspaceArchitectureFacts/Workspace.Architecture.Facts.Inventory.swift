public import JSON
public import WorkspaceArchitectureModel

extension Workspace.Architecture.Facts {
    /// The `Institute.json` inventory, reduced to what derivation needs.
    ///
    /// Extra top-level keys (version, scope, toolchains) are the
    /// inventory's own concern and are ignored here.
    public struct Inventory: Sendable, Equatable, JSON.Serializable {
        public let rows: [Row]

        public init(rows: [Row]) {
            self.rows = rows
        }
    }
}

extension Workspace.Architecture.Facts.Inventory {
    public static func serialize(_ value: Self) -> JSON {
        ["repositories": value.rows.json]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let repositories = object["repositories"] else {
            throw .missingKey("repositories")
        }
        return try Self(rows: [Row](json: repositories))
    }
}
