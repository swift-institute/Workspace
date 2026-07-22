public import GitHub

extension Workspace.Repository {
    public struct Key: Equatable, Hashable, Sendable {
        public let owner: GitHub.Organization.Name
        public let name: GitHub.Repository.Name

        public init(owner: GitHub.Organization.Name, name: GitHub.Repository.Name) {
            self.owner = owner
            self.name = name
        }

        public var url: Swift.String {
            "https://github.com/\(owner.rawValue)/\(name.rawValue).git"
        }

        public init?(repository: Workspace.Repository) {
            let prefix = "https://github.com/"
            let suffix = ".git"
            guard repository.url.hasPrefix(prefix), repository.url.hasSuffix(suffix) else {
                return nil
            }

            let start = repository.url.index(repository.url.startIndex, offsetBy: prefix.count)
            let end = repository.url.index(repository.url.endIndex, offsetBy: -suffix.count)
            let components = repository.url[start..<end].split(separator: "/", omittingEmptySubsequences: false)
            guard
                components.count == 2,
                !components[0].isEmpty,
                !components[1].isEmpty,
                components[1] == repository.name
            else { return nil }

            self.init(
                owner: .init(rawValue: Swift.String(components[0])),
                name: .init(rawValue: Swift.String(components[1]))
            )
        }

        package static func precedes(_ lhs: Self, _ rhs: Self) -> Bool {
            if lhs.owner != rhs.owner {
                return lhs.owner.rawValue.utf8.lexicographicallyPrecedes(rhs.owner.rawValue.utf8)
            }
            return lhs.name.rawValue.utf8.lexicographicallyPrecedes(rhs.name.rawValue.utf8)
        }
    }
}
