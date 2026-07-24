public import GitHub
public import Tagged_Primitives

extension Workspace.Repository {
    public struct Key: Equatable, Hashable, Sendable {
        public let owner: GitHub.Organization.Name
        public let name: GitHub.Repository.Name

        public init(owner: GitHub.Organization.Name, name: GitHub.Repository.Name) {
            self.owner = owner
            self.name = name
        }

        public var url: Swift.String {
            "https://github.com/\(owner.underlying)/\(name.underlying).git"
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
                owner: .init(Swift.String(components[0])),
                name: .init(Swift.String(components[1]))
            )
        }

        package static func precedes(_ lhs: Self, _ rhs: Self) -> Bool {
            if lhs.owner != rhs.owner {
                return lhs.owner.underlying.utf8.lexicographicallyPrecedes(rhs.owner.underlying.utf8)
            }
            return lhs.name.underlying.utf8.lexicographicallyPrecedes(rhs.name.underlying.utf8)
        }
    }
}
