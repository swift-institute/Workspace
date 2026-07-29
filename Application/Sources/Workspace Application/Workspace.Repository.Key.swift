public import GitHub
public import JSON
public import Tagged_Primitives

extension Workspace.Repository {
    public struct Key: Equatable, Hashable, Sendable, JSON.Serializable {
        public let owner: GitHub.Organization.Name
        public let name: GitHub.Repository.Name

        public init(owner: GitHub.Organization.Name, name: GitHub.Repository.Name) {
            self.owner = owner
            self.name = name
        }

        public init?(identity: Swift.String) {
            let components = identity.split(separator: "/", omittingEmptySubsequences: false)
            guard
                components.count == 2,
                !components[0].isEmpty,
                !components[1].isEmpty
            else { return nil }
            self.init(
                owner: .init(Swift.String(components[0])),
                name: .init(Swift.String(components[1]))
            )
        }

        public init?(url: Swift.String) {
            let prefix = "https://github.com/"
            let suffix = ".git"
            guard url.hasPrefix(prefix), url.hasSuffix(suffix) else {
                return nil
            }

            let start = url.index(url.startIndex, offsetBy: prefix.count)
            let end = url.index(url.endIndex, offsetBy: -suffix.count)
            self.init(identity: Swift.String(url[start..<end]))
        }

        public init?(repository: Workspace.Repository) {
            guard let key = Self(url: repository.url), key.name.underlying == repository.name else {
                return nil
            }
            self = key
        }
    }
}

extension Workspace.Repository.Key {
    public var identity: Swift.String {
        "\(owner.underlying)/\(name.underlying)"
    }

    public var url: Swift.String {
        "https://github.com/\(owner.underlying)/\(name.underlying).git"
    }

    package static func precedes(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.owner != rhs.owner {
            return lhs.owner.underlying.utf8.lexicographicallyPrecedes(rhs.owner.underlying.utf8)
        }
        return lhs.name.underlying.utf8.lexicographicallyPrecedes(rhs.name.underlying.utf8)
    }

    public static func serialize(_ value: Self) -> JSON {
        value.identity.json
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        let value = try Swift.String(json: json)
        guard let value = Self(identity: value) else {
            throw .typeMismatch(expected: "repository identity owner/name", got: value)
        }
        return value
    }
}
