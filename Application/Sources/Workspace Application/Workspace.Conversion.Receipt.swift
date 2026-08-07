public import JSON

extension Workspace.Conversion {
    /// The content-addressed conversion receipt `institute conversion
    /// seal`/`check` produce and validate (issue #83 Part 2).
    ///
    /// Sorted keys, no volatile ordering, no machine paths — the digest
    /// over ``Workspace/Receipt/Sealed/canonical`` is what freezes the
    /// observation, the discipline every receipt in this module shares.
    /// `cohort` is sorted by canonical coordinate; `pages` by
    /// (`coordinate`, `kind`, `path`); `driftChecks` by (`coordinate`,
    /// `path`). `revert` and `evaluation` are `nil` until the canary run
    /// rehearses the revert and records trials — never authored eagerly.
    public struct Receipt: Equatable, Sendable, Workspace.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String
        public let instrument: Instrument
        public let cohort: [Repository]
        public let pages: [Page]
        public let driftChecks: [DriftCheck]
        public let revert: Revert?
        public let evaluation: Evaluation?

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "authoring-conversion",
            instrument: Instrument,
            cohort: [Repository],
            pages: [Page],
            driftChecks: [DriftCheck],
            revert: Revert? = nil,
            evaluation: Evaluation? = nil
        ) {
            self.version = version
            self.kind = kind
            self.instrument = instrument
            self.cohort = cohort.sorted(by: Repository.precedes)
            self.pages = pages.sorted(by: Page.precedes)
            self.driftChecks = driftChecks.sorted(by: DriftCheck.precedes)
            self.revert = revert
            self.evaluation = evaluation
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "version": value.version.json,
                "kind": value.kind.json,
                "instrument": value.instrument.json,
                "cohort": value.cohort.json,
                "pages": value.pages.json,
                "driftChecks": value.driftChecks.json,
                "revert": value.revert.json,
                "evaluation": value.evaluation.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let version = object["version"] else { throw .missingKey("version") }
            guard let kind = object["kind"] else { throw .missingKey("kind") }
            guard let instrument = object["instrument"] else { throw .missingKey("instrument") }
            guard let cohort = object["cohort"] else { throw .missingKey("cohort") }
            guard let pages = object["pages"] else { throw .missingKey("pages") }
            guard let driftChecks = object["driftChecks"] else { throw .missingKey("driftChecks") }
            return try Self(
                version: Swift.Int(json: version),
                kind: Swift.String(json: kind),
                instrument: Instrument(json: instrument),
                cohort: [Repository](json: cohort),
                pages: [Page](json: pages),
                driftChecks: [DriftCheck](json: driftChecks),
                revert: Revert?(json: object["revert"] ?? .null),
                evaluation: Evaluation?(json: object["evaluation"] ?? .null)
            )
        }
    }
}
