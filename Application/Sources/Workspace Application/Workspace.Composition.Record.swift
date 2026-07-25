public import JSON

extension Workspace.Composition {
    /// One active composition: a consumer whose dependency has been redirected
    /// to a local mutable source, and the two facts that cannot be re-derived
    /// once the manifest is rewritten.
    ///
    /// Per ADR-001, only what cannot be re-inspected is persisted:
    ///
    /// - ``declared`` — the exact `.package(url: …)` clause the manifest carried
    ///   before composition. This is the *declared source*. Once the manifest
    ///   is overwritten it is gone, and it must return **byte-identical**, so
    ///   the verbatim text is the one thing that has to be kept.
    /// - ``planned`` — the exact `.package(path: …)` clause written in its
    ///   place. This is Workspace's own *planned source*. Keeping the verbatim
    ///   text SwiftPM was handed lets ``restore`` match it exactly and refuse
    ///   loudly if a developer hand-edited the composed clause, rather than
    ///   re-deriving a spelling that might silently diverge.
    ///
    /// Everything else — the resolved revision, the compiled tree, the pins —
    /// is re-read from SwiftPM's own state and is never stored here. Neither
    /// field carries a machine path: ``declared`` holds a URL, ``planned`` holds
    /// a path that is local by nature and lives only in this record and the
    /// (uncommitted) consumer manifest.
    public struct Record: Swift.Equatable, Swift.Sendable, JSON.Serializable {
        /// The workspace repository whose manifest was rewritten.
        public let consumer: Swift.String

        /// The workspace repository the consumer was redirected to.
        public let dependency: Swift.String

        /// The exact `.package(url: …)` clause the manifest declared.
        public let declared: Swift.String

        /// The exact `.package(path: …)` clause written in its place.
        public let planned: Swift.String

        public init(
            consumer: Swift.String,
            dependency: Swift.String,
            declared: Swift.String,
            planned: Swift.String
        ) {
            self.consumer = consumer
            self.dependency = dependency
            self.declared = declared
            self.planned = planned
        }
    }
}

extension Workspace.Composition.Record {
    public static func serialize(_ value: Self) -> JSON {
        [
            "consumer": value.consumer.json,
            "dependency": value.dependency.json,
            "declared": value.declared.json,
            "planned": value.planned.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Set<Swift.String> = ["consumer", "dependency", "declared", "planned"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "composition keys consumer, dependency, declared, and planned",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let consumer = object["consumer"] else { throw .missingKey("consumer") }
        guard let dependency = object["dependency"] else { throw .missingKey("dependency") }
        guard let declared = object["declared"] else { throw .missingKey("declared") }
        guard let planned = object["planned"] else { throw .missingKey("planned") }

        return try Self(
            consumer: Swift.String(json: consumer),
            dependency: Swift.String(json: dependency),
            declared: Swift.String(json: declared),
            planned: Swift.String(json: planned)
        )
    }
}
