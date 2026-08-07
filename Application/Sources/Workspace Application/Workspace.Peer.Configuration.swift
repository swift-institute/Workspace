public import JSON

extension Workspace.Peer {
    /// A peer institute's own package inventory — the per-ecosystem
    /// counterpart of `Institute.json`.
    ///
    /// The document lives inside the peer's tree at the peer-root-relative
    /// path its ``Workspace/Peer`` registry entry declares, so the peer
    /// owns its package records and this repository never carries them.
    /// `ecosystem` names the peer and must match the registry entry it is
    /// loaded for; `repositories` mirror ``Workspace/Repository`` minus
    /// `layer` (``Workspace/Peer/Repository``).
    public struct Configuration: Equatable, Sendable, JSON.Serializable {
        public let version: Int
        public let ecosystem: Swift.String
        public let repositories: [Repository]

        public init(
            version: Int,
            ecosystem: Swift.String,
            repositories: [Repository]
        ) {
            self.version = version
            self.ecosystem = ecosystem
            self.repositories = repositories
        }
    }
}

extension Workspace.Peer.Configuration {
    /// Validates the inventory for `peer`: a supported version, the
    /// declared ecosystem matching the registry entry, unique names,
    /// unique canonical keys, and every URL's owner matching the record's
    /// organization — the same discipline `Institute.json` is held to.
    public func validated(for peer: Workspace.Peer) throws(Workspace.Error) -> Self {
        guard version == 1 else {
            throw .configuration("unsupported peer inventory version \(version)")
        }
        guard ecosystem == peer.name else {
            throw .configuration(
                "peer inventory declares ecosystem \(ecosystem) but was loaded for \(peer.name)"
            )
        }
        var names = Set<Swift.String>()
        var keys = Set<Workspace.Repository.Key>()
        for repository in repositories {
            guard
                let key = Workspace.Repository.Key(url: repository.url),
                key.name.underlying == repository.name
            else {
                throw .configuration(
                    """
                    peer inventory repository \(repository.name) does not have its canonical \
                    owner/name URL
                    """
                )
            }
            guard names.insert(repository.name).inserted else {
                throw .configuration(
                    "peer inventory contains duplicate repository name \(repository.name)"
                )
            }
            guard keys.insert(key).inserted else {
                throw .configuration(
                    "peer inventory contains duplicate repository key \(repository.url)"
                )
            }
            guard key.owner.underlying == repository.organization else {
                throw .configuration(
                    """
                    peer inventory repository \(repository.name) declares organization \
                    \(repository.organization) but its URL owner is \(key.owner.underlying)
                    """
                )
            }
        }
        return self
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "ecosystem": value.ecosystem.json,
            "repositories": value.repositories.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Set<Swift.String> = ["version", "ecosystem", "repositories"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "peer inventory keys version, ecosystem, and repositories",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let ecosystem = object["ecosystem"] else { throw .missingKey("ecosystem") }
        guard let repositories = object["repositories"] else {
            throw .missingKey("repositories")
        }

        return try Self(
            version: Int(json: version),
            ecosystem: Swift.String(json: ecosystem),
            repositories: [Workspace.Peer.Repository](json: repositories)
        )
    }
}
