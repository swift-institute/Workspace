import GitHub
import Tagged_Primitives

extension Workspace.Inventory {
    public struct Merge: Sendable {
        public init() {}
    }
}

extension Workspace.Inventory.Merge {
    public func callAsFunction(
        _ discovery: Workspace.Inventory.Discovery,
        into existing: Workspace.Configuration
    ) throws(Error) -> Workspace.Configuration {
        var annotations = [Workspace.Repository.Key: Workspace.Repository]()
        var oldNames = [GitHub.Repository.Name: Workspace.Repository.Key]()
        for repository in existing.repositories {
            guard let key = Workspace.Repository.Key(repository: repository) else {
                throw .annotation(repository)
            }
            guard annotations[key] == nil else { throw .duplicate(key) }
            if let first = oldNames[key.name], first != key {
                throw .collision(key.name, first, key)
            }
            annotations[key] = repository
            oldNames[key.name] = key
        }

        var keys = Set<Workspace.Repository.Key>()
        var newNames = [GitHub.Repository.Name: Workspace.Repository.Key]()
        var repositories = [(key: Workspace.Repository.Key, value: Workspace.Repository)]()
        for candidate in discovery.repositories {
            guard keys.insert(candidate.key).inserted else {
                throw .duplicate(candidate.key)
            }
            if let first = newNames[candidate.key.name], first != candidate.key {
                throw .collision(candidate.key.name, first, candidate.key)
            }
            newNames[candidate.key.name] = candidate.key

            if let previous = oldNames[candidate.key.name], previous != candidate.key {
                guard let annotation = annotations[previous] else {
                    preconditionFailure("An indexed annotation is missing")
                }
                throw .transfer(
                    candidate.key.name,
                    previous,
                    candidate.key,
                    annotation: annotation.layer,
                    default: candidate.layer
                )
            }

            let layer = annotations[candidate.key]?.layer ?? candidate.layer
            repositories.append(
                (
                    candidate.key,
                    .init(
                        name: candidate.key.name.underlying,
                        url: candidate.key.url,
                        organization: candidate.key.owner.underlying,
                        layer: layer
                    )
                )
            )
        }

        repositories.sort { lhs, rhs in
            if lhs.value.layer.order != rhs.value.layer.order {
                return lhs.value.layer.order < rhs.value.layer.order
            }
            return Workspace.Repository.Key.precedes(lhs.key, rhs.key)
        }

        return .init(
            version: existing.version,
            scope: existing.scope,
            swift: existing.swift,
            xcode: existing.xcode,
            repositories: repositories.map(\.value)
        )
    }
}
