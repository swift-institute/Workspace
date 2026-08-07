public import JSON

extension Workspace.Coherence {
    /// The stages a coherence run walks, in the fixed order it walks them.
    ///
    /// A red run must first say *which stage* failed — doctrine forbids
    /// inferring a source defect from a setup failure. `bootstrap` precedes
    /// everything this instrument itself can measure (see ``Coherence``);
    /// the remaining five are what ``Run/run()`` actually executes.
    public enum Stage: Swift.String, Swift.CaseIterable, Equatable, Sendable, JSON.Serializable {
        /// The self-hosting `institute install` compile that produced the
        /// executable running this instrument.
        case bootstrap
        /// Materializing the selection — `institute sync`.
        case sync
        /// Checkout facts, credential-free — `institute doctor`.
        case doctor
        /// The generated workspace/scheme re-rendered and byte-compared
        /// against the manifests before anything is built.
        case graph
        /// The one merged `xcodebuild` invocation over the composed graph.
        case build
        /// The built-target population checked against the
        /// inventory-derived expectation. Never green on a mismatch.
        case population

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let stage = Self(rawValue: value) else {
                throw .typeMismatch(expected: "coherence stage", got: value)
            }
            return stage
        }
    }
}

extension Workspace.Coherence {
    /// One stage's outcome.
    public enum Outcome: Swift.String, Equatable, Sendable, JSON.Serializable {
        case success
        case failure
        case notRun = "not-run"

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let outcome = Self(rawValue: value) else {
                throw .typeMismatch(expected: "coherence outcome", got: value)
            }
            return outcome
        }
    }
}

extension Workspace.Coherence {
    /// One stage's recorded outcome and wall-clock duration.
    public struct StageResult: Equatable, Sendable, JSON.Serializable {
        public let stage: Stage
        public let outcome: Outcome
        public let durationSeconds: Swift.Double

        public init(stage: Stage, outcome: Outcome, durationSeconds: Swift.Double) {
            self.stage = stage
            self.outcome = outcome
            self.durationSeconds = durationSeconds
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "stage": value.stage.json,
                "outcome": value.outcome.json,
                "durationSeconds": value.durationSeconds.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let stage = object["stage"] else { throw .missingKey("stage") }
            guard let outcome = object["outcome"] else { throw .missingKey("outcome") }
            guard let durationSeconds = object["durationSeconds"] else {
                throw .missingKey("durationSeconds")
            }
            return try Self(
                stage: Stage(json: stage),
                outcome: Outcome(json: outcome),
                durationSeconds: Swift.Double(json: durationSeconds)
            )
        }
    }
}
