public import GitHub
public import Tagged_Primitives

extension Workspace.Inventory {
    /// The committed public roster combined, in memory, with one live
    /// private-discovery pass — three ``Workspace/Configuration`` values
    /// sharing one schema, so each already carries its own digest via
    /// ``Workspace/Receipt/Sealed`` without this type inventing a second
    /// digesting path.
    ///
    /// **Why three, not one.** The programme requires "separate safe digests"
    /// for the committed public inventory and the runtime private extension,
    /// *plus* one combined digest a downstream verifier and caller generator
    /// can use as the single effective population. `public` is exactly the
    /// loaded `Workspace.json` — untouched, so its digest matches what is
    /// already committed. `private` exists only in memory: a private
    /// repository's coordinates never reach a public commit through this
    /// type. `combined` is `public` and `private` merged and re-sorted by
    /// the same (layer, key) order `Merge` already uses, so the same input
    /// population always canonicalizes to the same bytes regardless of the
    /// order discovery happened to observe it in.
    public struct Effective: Sendable {
        public let `public`: Workspace.Configuration
        public let `private`: Workspace.Configuration
        public let combined: Workspace.Configuration

        public init(
            public publicConfiguration: Workspace.Configuration,
            private discovery: Private.Discovery
        ) throws(Error) {
            let privateRepositories = Self.sorted(
                discovery.repositories.map { candidate in
                    Workspace.Repository(
                        name: candidate.key.name.underlying,
                        url: candidate.key.url,
                        organization: candidate.key.owner.underlying,
                        layer: candidate.layer
                    )
                }
            )

            var names = [GitHub.Repository.Name: Workspace.Repository.Key]()
            for repository in publicConfiguration.repositories {
                guard let key = Workspace.Repository.Key(repository: repository) else {
                    throw .annotation(repository)
                }
                names[key.name] = key
            }
            for repository in privateRepositories {
                guard let key = Workspace.Repository.Key(repository: repository) else {
                    throw .annotation(repository)
                }
                // A public repository and a private repository can never
                // share an owner/name — GitHub repository identity is
                // unique per owner regardless of visibility — but two
                // *different* owners, one public and one private, can still
                // publish the same repository *name*. That is exactly the
                // SwiftPM product-identity collision `Policy.denied`
                // documents for `swift-numerics`/`swift-metrics`, just
                // reachable from the opposite visibility this time, so it
                // gets the same fail-closed treatment here rather than a
                // silently ambiguous combined roster.
                if let existing = names[key.name], existing != key {
                    throw .collision(key.name, existing, key)
                }
                names[key.name] = key
            }

            self.public = publicConfiguration
            self.private = .init(
                version: publicConfiguration.version,
                scope: publicConfiguration.scope,
                swift: publicConfiguration.swift,
                xcode: publicConfiguration.xcode,
                repositories: privateRepositories
            )
            self.combined = .init(
                version: publicConfiguration.version,
                scope: publicConfiguration.scope,
                swift: publicConfiguration.swift,
                xcode: publicConfiguration.xcode,
                repositories: Self.sorted(publicConfiguration.repositories + privateRepositories)
            )
        }
    }
}

extension Workspace.Inventory.Effective {
    /// The same (layer order, then owner/name) precedence `Merge` sorts by —
    /// duplicated rather than shared, because sharing would mean this type
    /// depending on `Merge`'s annotation-preserving machinery for a plain
    /// sort it does not need.
    fileprivate static func sorted(_ repositories: [Workspace.Repository]) -> [Workspace.Repository] {
        repositories.sorted { lhs, rhs in
            if lhs.layer.order != rhs.layer.order {
                return lhs.layer.order < rhs.layer.order
            }
            guard
                let lhsKey = Workspace.Repository.Key(repository: lhs),
                let rhsKey = Workspace.Repository.Key(repository: rhs)
            else {
                return lhs.name < rhs.name
            }
            return Workspace.Repository.Key.precedes(lhsKey, rhsKey)
        }
    }
}

extension Workspace.Inventory.Effective {
    public enum Error: Swift.Error, Equatable, Sendable {
        /// A repository (public or private) does not have its canonical
        /// owner/name URL — the same ground `Workspace.Configuration.validated()`
        /// checks for the committed file, applied here to the in-memory
        /// private and combined configurations before they are digested.
        case annotation(Workspace.Repository)
        case collision(GitHub.Repository.Name, Workspace.Repository.Key, Workspace.Repository.Key)
    }
}
