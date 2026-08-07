private import Tagged_Primitives

extension Workspace.Configuration {
    public func validated() throws(Workspace.Error) -> Self {
        guard version == 1 else {
            throw .configuration("unsupported Institute.json version \(version)")
        }

        var names = Set<Swift.String>()
        var keys = Set<Workspace.Repository.Key>()
        for repository in repositories {
            guard let key = Workspace.Repository.Key(repository: repository) else {
                throw .configuration(
                    "Institute.json repository \(repository.name) does not have its canonical owner/name URL"
                )
            }
            guard names.insert(repository.name).inserted else {
                throw .configuration("Institute.json contains duplicate repository name \(repository.name)")
            }
            guard keys.insert(key).inserted else {
                throw .configuration(
                    "Institute.json contains duplicate repository key \(repository.url)"
                )
            }
            guard key.owner.underlying == repository.organization else {
                throw .configuration(
                    """
                    Institute.json repository \(repository.name) declares organization \
                    \(repository.organization) but its URL owner is \(key.owner.underlying)
                    """
                )
            }
            // A repository sitting directly in a layer's *root* organization
            // (swift-primitives, swift-standards, swift-foundations) must
            // declare that same layer. Sub-organizations nested under a root
            // per ruling 139 (swift-ietf, swift-arm-ltd, and so on) are not
            // roots themselves and are exempt — `Layer.organization` only
            // names the three roots, so this loop is a no-op for every
            // other organization by construction. This never reads or
            // writes `orgs.yaml`: the check is entirely over `Layer`, a
            // Workspace-owned fact, and the organization string already
            // present on the repository record.
            if let root = Workspace.Layer.allCases.first(where: { $0.organization == repository.organization }),
                root != repository.layer
            {
                throw .configuration(
                    """
                    Institute.json repository \(repository.name) sits in \(repository.organization), \
                    the \(root.token) layer root, but declares layer \(repository.layer.token)
                    """
                )
            }
        }

        return self
    }
}
