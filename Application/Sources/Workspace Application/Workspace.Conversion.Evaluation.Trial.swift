public import JSON

extension Workspace.Conversion.Evaluation {
    /// Exactly protocol §5's per-trial field list, and nothing else.
    public struct Trial: Equatable, Sendable, JSON.Serializable {
        public let trialIdentifier: Swift.String
        public let coordinate: Workspace.Repository.Key
        public let template: Swift.String
        public let arm: Arm
        public let readmeBlob: Swift.String
        public let transcriptDigest: Swift.String
        public let tokenCount: Swift.Int
        public let turnCount: Swift.Int
        public let durationSeconds: Swift.Double
        public let finalAnswer: Swift.String
        public let score: Swift.Bool
        public let scoringRule: Swift.String

        public init(
            trialIdentifier: Swift.String,
            coordinate: Workspace.Repository.Key,
            template: Swift.String,
            arm: Arm,
            readmeBlob: Swift.String,
            transcriptDigest: Swift.String,
            tokenCount: Swift.Int,
            turnCount: Swift.Int,
            durationSeconds: Swift.Double,
            finalAnswer: Swift.String,
            score: Swift.Bool,
            scoringRule: Swift.String
        ) {
            self.trialIdentifier = trialIdentifier
            self.coordinate = coordinate
            self.template = template
            self.arm = arm
            self.readmeBlob = readmeBlob
            self.transcriptDigest = transcriptDigest
            self.tokenCount = tokenCount
            self.turnCount = turnCount
            self.durationSeconds = durationSeconds
            self.finalAnswer = finalAnswer
            self.score = score
            self.scoringRule = scoringRule
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "trialIdentifier": value.trialIdentifier.json,
                "coordinate": value.coordinate.json,
                "template": value.template.json,
                "arm": value.arm.json,
                "readmeBlob": value.readmeBlob.json,
                "transcriptDigest": value.transcriptDigest.json,
                "tokenCount": value.tokenCount.json,
                "turnCount": value.turnCount.json,
                "durationSeconds": value.durationSeconds.json,
                "finalAnswer": value.finalAnswer.json,
                "score": value.score.json,
                "scoringRule": value.scoringRule.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let trialIdentifier = object["trialIdentifier"] else {
                throw .missingKey("trialIdentifier")
            }
            guard let coordinate = object["coordinate"] else { throw .missingKey("coordinate") }
            guard let template = object["template"] else { throw .missingKey("template") }
            guard let arm = object["arm"] else { throw .missingKey("arm") }
            guard let readmeBlob = object["readmeBlob"] else { throw .missingKey("readmeBlob") }
            guard let transcriptDigest = object["transcriptDigest"] else {
                throw .missingKey("transcriptDigest")
            }
            guard let tokenCount = object["tokenCount"] else { throw .missingKey("tokenCount") }
            guard let turnCount = object["turnCount"] else { throw .missingKey("turnCount") }
            guard let durationSeconds = object["durationSeconds"] else {
                throw .missingKey("durationSeconds")
            }
            guard let finalAnswer = object["finalAnswer"] else { throw .missingKey("finalAnswer") }
            guard let score = object["score"] else { throw .missingKey("score") }
            guard let scoringRule = object["scoringRule"] else { throw .missingKey("scoringRule") }
            return try Self(
                trialIdentifier: Swift.String(json: trialIdentifier),
                coordinate: Workspace.Repository.Key(json: coordinate),
                template: Swift.String(json: template),
                arm: Arm(json: arm),
                readmeBlob: Swift.String(json: readmeBlob),
                transcriptDigest: Swift.String(json: transcriptDigest),
                tokenCount: Swift.Int(json: tokenCount),
                turnCount: Swift.Int(json: turnCount),
                durationSeconds: Swift.Double(json: durationSeconds),
                finalAnswer: Swift.String(json: finalAnswer),
                score: Swift.Bool(json: score),
                scoringRule: Swift.String(json: scoringRule)
            )
        }
    }
}

extension Workspace.Conversion.Evaluation.Trial {
    /// Sorted by `trialIdentifier` — the receipt's trial ordering.
    package static func precedes(_ lhs: Self, _ rhs: Self) -> Swift.Bool {
        lhs.trialIdentifier < rhs.trialIdentifier
    }
}
