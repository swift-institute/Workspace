public import JSON

extension Workspace.Conversion.Evaluation {
    /// The counts of excluded, not-applicable, and unmeasured entries, and
    /// protocol §6's pre-declared decision quantities.
    ///
    /// Workspace records and validates these fields; it does not compute
    /// them. Computing Newcombe's paired hybrid-score interval and applying
    /// the §6 mapping is the canary run's own work (#83's explicit
    /// deferral).
    public struct Summary: Equatable, Sendable, JSON.Serializable {
        public let excluded: Swift.Int
        public let notApplicable: Swift.Int
        public let unmeasured: Swift.Int
        public let pairCount: Swift.Int
        public let deltaHat: Swift.Double
        public let ciLower: Swift.Double
        public let ciUpper: Swift.Double
        public let decision: Decision

        public init(
            excluded: Swift.Int,
            notApplicable: Swift.Int,
            unmeasured: Swift.Int,
            pairCount: Swift.Int,
            deltaHat: Swift.Double,
            ciLower: Swift.Double,
            ciUpper: Swift.Double,
            decision: Decision
        ) {
            self.excluded = excluded
            self.notApplicable = notApplicable
            self.unmeasured = unmeasured
            self.pairCount = pairCount
            self.deltaHat = deltaHat
            self.ciLower = ciLower
            self.ciUpper = ciUpper
            self.decision = decision
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "excluded": value.excluded.json,
                "notApplicable": value.notApplicable.json,
                "unmeasured": value.unmeasured.json,
                "pairCount": value.pairCount.json,
                "deltaHat": value.deltaHat.json,
                "ciLower": value.ciLower.json,
                "ciUpper": value.ciUpper.json,
                "decision": value.decision.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let excluded = object["excluded"] else { throw .missingKey("excluded") }
            guard let notApplicable = object["notApplicable"] else {
                throw .missingKey("notApplicable")
            }
            guard let unmeasured = object["unmeasured"] else { throw .missingKey("unmeasured") }
            guard let pairCount = object["pairCount"] else { throw .missingKey("pairCount") }
            guard let deltaHat = object["deltaHat"] else { throw .missingKey("deltaHat") }
            guard let ciLower = object["ciLower"] else { throw .missingKey("ciLower") }
            guard let ciUpper = object["ciUpper"] else { throw .missingKey("ciUpper") }
            guard let decision = object["decision"] else { throw .missingKey("decision") }
            return try Self(
                excluded: Swift.Int(json: excluded),
                notApplicable: Swift.Int(json: notApplicable),
                unmeasured: Swift.Int(json: unmeasured),
                pairCount: Swift.Int(json: pairCount),
                deltaHat: Swift.Double(json: deltaHat),
                ciLower: Swift.Double(json: ciLower),
                ciUpper: Swift.Double(json: ciUpper),
                decision: Decision(json: decision)
            )
        }
    }
}
