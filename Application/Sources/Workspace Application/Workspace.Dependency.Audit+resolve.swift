private import GitHub

extension Workspace.Dependency.Audit {
    func resolve(
        _ resolutions: [Workspace.Dependency.Resolution]
    ) -> (
        identities: [Workspace.Dependency.Identity],
        edges: [
            Workspace.Repository.Key:
                (
                    identity: Swift.String,
                    canonicalURL: Swift.String?,
                    state: Workspace.Dependency.State,
                    reason: Swift.String?
                )
        ]
    ) {
        let institute = Set(policy.organizations.map(\.name))
        var identities = [Workspace.Dependency.Identity]()
        var indices = [Swift.String: Swift.Int]()
        var edges = [
            Workspace.Repository.Key:
                (
                    identity: Swift.String,
                    canonicalURL: Swift.String?,
                    state: Workspace.Dependency.State,
                    reason: Swift.String?
                )
        ]()

        for resolution in resolutions {
            let declaredURL = resolution.declared.url
            switch resolution.fetch {
            case .available(let metadata):
                guard metadata.visibility == .public else {
                    append(
                        resolution.declared,
                        state: .unavailable,
                        reason: "resolved repository is not public",
                        identities: &identities,
                        indices: &indices,
                        edges: &edges
                    )
                    continue
                }
                let identity = metadata.key.identity
                let ownership: Workspace.Dependency.Ownership
                if sanctioned.contains(metadata.key) {
                    ownership = .sanctionedException
                } else if institute.contains(metadata.key.owner) {
                    ownership = .institute
                } else if metadata.ownerIsUser {
                    ownership = .personalOwner
                } else {
                    ownership = .thirdParty
                }
                if let index = indices[identity] {
                    let current = identities[index]
                    identities[index] = .init(
                        identity: current.identity,
                        canonicalURL: current.canonicalURL,
                        declaredURLs: Array(Set(current.declaredURLs + [declaredURL])).sorted(),
                        ownership: current.ownership,
                        state: current.state,
                        reason: current.reason
                    )
                } else {
                    indices[identity] = identities.count
                    identities.append(
                        .init(
                            identity: identity,
                            canonicalURL: metadata.key.url,
                            declaredURLs: [declaredURL],
                            ownership: ownership,
                            state: .measured
                        )
                    )
                }
                edges[resolution.declared] = (identity, metadata.key.url, .measured, nil)
            case .unavailable(let reason):
                append(
                    resolution.declared,
                    state: .unavailable,
                    reason: reason,
                    identities: &identities,
                    indices: &indices,
                    edges: &edges
                )
            case .rateLimited(let reason):
                append(
                    resolution.declared,
                    state: .rateLimited,
                    reason: reason,
                    identities: &identities,
                    indices: &indices,
                    edges: &edges
                )
            case .malformed(let reason):
                append(
                    resolution.declared,
                    state: .malformed,
                    reason: reason,
                    identities: &identities,
                    indices: &indices,
                    edges: &edges
                )
            case .unmeasured(let reason):
                append(
                    resolution.declared,
                    state: .unmeasured,
                    reason: reason,
                    identities: &identities,
                    indices: &indices,
                    edges: &edges
                )
            }
        }

        identities.sort { $0.identity < $1.identity }
        return (identities, edges)
    }

    private func append(
        _ declared: Workspace.Repository.Key,
        state: Workspace.Dependency.State,
        reason: Swift.String,
        identities: inout [Workspace.Dependency.Identity],
        indices: inout [Swift.String: Swift.Int],
        edges: inout [
            Workspace.Repository.Key:
                (
                    identity: Swift.String,
                    canonicalURL: Swift.String?,
                    state: Workspace.Dependency.State,
                    reason: Swift.String?
                )
        ]
    ) {
        let identity = declared.identity
        if indices[identity] == nil {
            indices[identity] = identities.count
            identities.append(
                .init(
                    identity: identity,
                    canonicalURL: nil,
                    declaredURLs: [declared.url],
                    ownership: .unmeasured,
                    state: state,
                    reason: reason
                )
            )
        }
        edges[declared] = (identity, nil, state, reason)
    }
}
