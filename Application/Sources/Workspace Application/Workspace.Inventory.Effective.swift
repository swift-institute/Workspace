public import GitHub
public import JSON
public import Tagged_Primitives

extension Workspace.Inventory {
    /// The committed public roster combined, in memory, with one live
    /// private-discovery pass.
    ///
    /// **Why three populations, not one.** The programme requires "separate
    /// safe digests" for the committed public inventory and the runtime
    /// private extension, *plus* one combined digest a downstream verifier
    /// and caller generator can use as the single effective population.
    /// `public` is exactly `publicConfiguration.repositories` as loaded from
    /// `Institute.json` — untouched, so its digest matches what is already
    /// committed. `private` exists only in memory: a private repository's
    /// coordinates never reach a public commit through this type. `combined`
    /// is `public` and `private` merged and re-sorted by the same (layer,
    /// key) order `Merge` already uses, so the same input population always
    /// canonicalizes to the same bytes regardless of the order discovery
    /// happened to observe it in.
    ///
    /// **Why `Population`, not `Workspace.Configuration`, is the digested
    /// shape.** `Workspace.Configuration` is the committed file's own type,
    /// used everywhere in this module; conforming *it* to
    /// ``Workspace/Receipt/Sealed`` would add a capability to a pervasive
    /// existing type well beyond this task's three named files, for a need
    /// only this type has. `Population` is new, scoped to this file, and
    /// reuses `Sealed`'s one canonicalization-and-digest discipline exactly
    /// the way `Workspace.Pages.Inventory` already does for a different
    /// content-addressed observation — the established pattern for a new
    /// digested shape, not a retrofit of an old one.
    public struct Effective: Sendable {
        public let `public`: Population
        public let `private`: Population
        public let combined: Population

        public init(
            public publicConfiguration: Workspace.Configuration,
            private discovery: Private.Discovery
        ) throws(Error) {
            try self.init(
                public: publicConfiguration,
                privateCoordinates: discovery.repositories.map { ($0.key, $0.layer) }
            )
        }

        /// The one place a private population becomes part of this type,
        /// whichever way the caller obtained it.
        ///
        /// Both the live pass (``init(public:private:)``) and a
        /// caller-supplied ``Roster`` (``init(public:roster:)``) funnel
        /// here, and neither may derive a repository's fields its own way:
        /// the mapping from a coordinate to a ``Workspace/Repository`` is
        /// written once, below, so the digested preimage is byte-identical
        /// no matter which path produced the population. That identity is
        /// the whole point of the roster path — a digest computed from a
        /// supplied roster is comparable with one computed from a live
        /// pass only if the two share this code, not merely this intent.
        init(
            public publicConfiguration: Workspace.Configuration,
            privateCoordinates: [(key: Workspace.Repository.Key, layer: Workspace.Layer)]
        ) throws(Error) {
            let privateRepositories = Self.sorted(
                privateCoordinates.map { candidate in
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

            self.public = .init(repositories: publicConfiguration.repositories)
            self.private = .init(repositories: privateRepositories)
            self.combined = .init(
                repositories: Self.sorted(publicConfiguration.repositories + privateRepositories)
            )
        }
    }
}

extension Workspace.Inventory.Effective {
    /// One digested population: sorted repository coordinates, nothing else.
    /// `version`/`scope`/`swift`/`xcode` are committed-file metadata, not
    /// population facts, so they are deliberately absent — three digests
    /// over the same three metadata fields plus a differing repository list
    /// would still differ, but including fields no verifier needs to compare
    /// only widens what a future edit to `Workspace.Configuration` could
    /// silently change this type's digest by way of.
    public struct Population: Equatable, Sendable, Workspace.Receipt.Sealed {
        public let repositories: [Workspace.Repository]

        public init(repositories: [Workspace.Repository]) {
            self.repositories = repositories
        }

        public static func serialize(_ value: Self) -> JSON {
            ["repositories": value.repositories.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let repositories = object["repositories"] else {
                throw .missingKey("repositories")
            }
            return Self(repositories: try [Workspace.Repository](json: repositories))
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
        /// private and combined populations.
        case annotation(Workspace.Repository)
        case collision(GitHub.Repository.Name, Workspace.Repository.Key, Workspace.Repository.Key)
        /// A supplied roster (``Roster``) named a repository in an
        /// organization ``Workspace/Inventory/Policy`` does not cover, so
        /// no layer can be derived for it the way the live pass derives
        /// one — and no live pass could have produced it.
        case unpolicedOrganization(Workspace.Repository.Key)
    }
}

extension Workspace.Inventory.Effective {
    /// Combines the committed public roster with a private population the
    /// caller already discovered — see ``Roster`` for why that seam exists.
    ///
    /// Identical to ``init(public:private:)`` in everything that reaches
    /// the digest: both delegate to
    /// ``init(public:privateCoordinates:)``, so the same population
    /// produces the same canonical bytes and therefore the same digest
    /// whichever way it was obtained.
    public init(
        public publicConfiguration: Workspace.Configuration,
        roster: Roster,
        policy: Workspace.Inventory.Policy
    ) throws(Error) {
        var layers = [GitHub.Organization.Name: Workspace.Layer]()
        for organization in policy.organizations {
            layers[organization.name] = organization.layer
        }

        var coordinates = [(key: Workspace.Repository.Key, layer: Workspace.Layer)]()
        for key in roster.repositories {
            // The live pass never sees a repository outside a policy
            // organization — it only walks `policy.organizations` — so a
            // roster naming one could only widen the population beyond
            // anything a live pass could produce. Refused, not silently
            // dropped: a silently dropped row is a population the caller
            // believes it supplied and the digest does not cover.
            guard let layer = layers[key.owner] else { throw .unpolicedOrganization(key) }
            // `denied` is applied identically on both paths (see
            // `Client.privateReason`), so a denied coordinate is excluded
            // rather than refused — the live pass excludes it too.
            guard !policy.denied.contains(key) else { continue }
            coordinates.append((key, layer))
        }

        try self.init(public: publicConfiguration, privateCoordinates: coordinates)
    }
}
