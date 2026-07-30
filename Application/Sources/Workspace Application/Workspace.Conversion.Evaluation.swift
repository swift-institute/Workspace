public import JSON

extension Workspace.Conversion {
    /// The evaluation section: absent before any trial, present after.
    ///
    /// `executorBinding` is a sorted string map, identical for every trial
    /// by construction (protocol §4) — one binding for the whole receipt,
    /// never one per trial.
    public struct Evaluation: Equatable, Sendable, JSON.Serializable {
        public let protocolFreezeBlob: Swift.String
        public let appendixBlob: Swift.String
        public let executorBinding: [Swift.String: Swift.String]
        public let trials: [Trial]
        public let summary: Summary

        public init(
            protocolFreezeBlob: Swift.String,
            appendixBlob: Swift.String,
            executorBinding: [Swift.String: Swift.String],
            trials: [Trial],
            summary: Summary
        ) {
            self.protocolFreezeBlob = protocolFreezeBlob
            self.appendixBlob = appendixBlob
            self.executorBinding = executorBinding
            self.trials = trials.sorted(by: Trial.precedes)
            self.summary = summary
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "protocolFreezeBlob": value.protocolFreezeBlob.json,
                "appendixBlob": value.appendixBlob.json,
                "executorBinding": value.executorBinding.json,
                "trials": value.trials.json,
                "summary": value.summary.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let protocolFreezeBlob = object["protocolFreezeBlob"] else {
                throw .missingKey("protocolFreezeBlob")
            }
            guard let appendixBlob = object["appendixBlob"] else {
                throw .missingKey("appendixBlob")
            }
            guard let executorBinding = object["executorBinding"] else {
                throw .missingKey("executorBinding")
            }
            guard let trials = object["trials"] else { throw .missingKey("trials") }
            guard let summary = object["summary"] else { throw .missingKey("summary") }
            return try Self(
                protocolFreezeBlob: Swift.String(json: protocolFreezeBlob),
                appendixBlob: Swift.String(json: appendixBlob),
                executorBinding: [Swift.String: Swift.String](json: executorBinding),
                trials: [Trial](json: trials),
                summary: Summary(json: summary)
            )
        }
    }
}
