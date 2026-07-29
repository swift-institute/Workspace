public import GitHub
public import JSON
public import Tagged_Primitives
private import RFC_3986

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
                Self.valid(components[0]),
                Self.valid(components[1])
            else { return nil }
            self.init(
                owner: .init(Swift.String(components[0])),
                name: .init(Swift.String(components[1]))
            )
        }

        public init?(url: Swift.String) {
            let uri: RFC_3986.URI
            do throws(RFC_3986.Error) {
                uri = try .init(url)
            } catch {
                return nil
            }
            guard
                uri.scheme?.value == "https",
                uri.userinfo == nil,
                uri.host == .registeredName("github.com"),
                uri.port == nil,
                uri.query == nil,
                uri.fragment == nil,
                let path = uri.path,
                path.isAbsolute,
                path.segments.count == 2,
                !path.segments.contains(where: { $0.contains("%") }),
                path.segments[1].hasSuffix(".git")
            else { return nil }

            let repository = path.segments[1].dropLast(".git".count)
            guard
                let key = Self(
                    identity: "\(path.segments[0])/\(repository)"
                ),
                key.url == url
            else { return nil }
            self = key
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
    private static func valid(_ component: some Swift.StringProtocol) -> Swift.Bool {
        guard !component.isEmpty, component != ".", component != ".." else {
            return false
        }
        return component.utf8.allSatisfy { byte in
            switch byte {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F:
                true
            default:
                false
            }
        }
    }

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
