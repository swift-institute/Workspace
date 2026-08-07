public import JSON

extension Workspace.Pages {
    /// The content-addressed page inventory one `institute inventory pages`
    /// run emits.
    ///
    /// Sorted keys, no volatile ordering, no machine paths — the digest
    /// over ``Workspace/Receipt/Sealed/canonical`` is what freezes the
    /// observation, exactly the discipline
    /// ``Workspace/Coherence/Receipt`` uses. `repositories` is sorted by
    /// (`organization`, `name`); `organizationProfilePages` is sorted by
    /// (`organization`, `path`) — the one page kind that is not nested
    /// under a repository record.
    public struct Inventory: Equatable, Sendable, Workspace.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String
        public let instrument: Instrument
        public let repositories: [Repository]
        public let organizationProfilePages: [Page]

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "page-inventory",
            instrument: Instrument,
            repositories: [Repository],
            organizationProfilePages: [Page]
        ) {
            self.version = version
            self.kind = kind
            self.instrument = instrument
            self.repositories = repositories
            self.organizationProfilePages = organizationProfilePages
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "version": value.version.json,
                "kind": value.kind.json,
                "instrument": value.instrument.json,
                "repositories": value.repositories.json,
                "organizationProfilePages": value.organizationProfilePages.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let version = object["version"] else { throw .missingKey("version") }
            guard let kind = object["kind"] else { throw .missingKey("kind") }
            guard let instrument = object["instrument"] else { throw .missingKey("instrument") }
            guard let repositories = object["repositories"] else { throw .missingKey("repositories") }
            guard let organizationProfilePages = object["organizationProfilePages"] else {
                throw .missingKey("organizationProfilePages")
            }
            return try Self(
                version: Swift.Int(json: version),
                kind: Swift.String(json: kind),
                instrument: Instrument(json: instrument),
                repositories: [Repository](json: repositories),
                organizationProfilePages: [Page](json: organizationProfilePages)
            )
        }
    }
}

extension Workspace.Pages.Inventory {
    /// Whether every selected repository is `.canonical` — the command
    /// surface's exit-non-zero gate (issue #82): a partial enumeration's
    /// digest must never be mistaken for a fleet page inventory.
    public var isFullyCanonical: Swift.Bool {
        repositories.allSatisfy { $0.materialization == "canonical" }
    }

    /// How many selected repositories are not `.canonical`, keyed by their
    /// rendered materialization state — the detail the non-zero exit names.
    public var nonCanonicalCounts: [Swift.String: Swift.Int] {
        var counts = [Swift.String: Swift.Int]()
        for repository in repositories where repository.materialization != "canonical" {
            counts[repository.materialization, default: 0] += 1
        }
        return counts
    }
}
