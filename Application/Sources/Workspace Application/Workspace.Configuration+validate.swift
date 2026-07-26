private import Tagged_Primitives

extension Workspace.Configuration {
    public func validated() throws(Workspace.Error) -> Self {
        guard version == 1 else {
            throw .configuration("unsupported Workspace.json version \(version)")
        }

        var names = Set<Swift.String>()
        var keys = Set<Workspace.Repository.Key>()
        for repository in repositories {
            guard let key = Workspace.Repository.Key(repository: repository) else {
                throw .configuration(
                    "Workspace.json repository \(repository.name) does not have its canonical owner/name URL"
                )
            }
            guard names.insert(repository.name).inserted else {
                throw .configuration("Workspace.json contains duplicate repository name \(repository.name)")
            }
            guard keys.insert(key).inserted else {
                throw .configuration(
                    "Workspace.json contains duplicate repository key \(repository.url)"
                )
            }
            guard key.owner.underlying == repository.organization else {
                throw .configuration(
                    """
                    Workspace.json repository \(repository.name) declares organization \
                    \(repository.organization) but its URL owner is \(key.owner.underlying)
                    """
                )
            }
        }

        return self
    }
}
