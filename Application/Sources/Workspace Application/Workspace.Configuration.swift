public import File_System
public import JSON

extension Workspace {
    public struct Configuration: Equatable, Sendable, JSON.Serializable {
        public let version: Int
        public let scope: Swift.String
        public let swift: Swift.String
        public let xcode: Swift.String
        public let repositories: [Repository]

        public init(version: Int, scope: Swift.String, swift: Swift.String, xcode: Swift.String, repositories: [Repository]) {
            self.version = version
            self.scope = scope
            self.swift = swift
            self.xcode = xcode
            self.repositories = repositories
        }
    }
}

extension Workspace.Configuration {
    public static func load(at root: File.Directory) throws(Workspace.Error) -> Self {
        try Document.load(at: root).configuration
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "scope": value.scope.json,
            "swift": value.swift.json,
            "xcode": value.xcode.json,
            "repositories": value.repositories.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Set<Swift.String> = ["version", "scope", "swift", "xcode", "repositories"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "Workspace keys version, scope, swift, xcode, and repositories",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let scope = object["scope"] else { throw .missingKey("scope") }
        guard let swift = object["swift"] else { throw .missingKey("swift") }
        guard let xcode = object["xcode"] else { throw .missingKey("xcode") }
        guard let repositories = object["repositories"] else {
            throw .missingKey("repositories")
        }

        return try Self(
            version: Int(json: version),
            scope: Swift.String(json: scope),
            swift: Swift.String(json: swift),
            xcode: Swift.String(json: xcode),
            repositories: [Workspace.Repository](json: repositories)
        )
    }
}
