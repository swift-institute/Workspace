public import JSON

extension Workspace.Coherence {
    /// What identifies the instrument that produced a receipt: the
    /// Workspace revision, the inventory it read, which selection was in
    /// effect, and which build path measured it (`xcodebuild-merged` today;
    /// Phase 2 adds `swiftpm-composed-root`, per the standing cross-platform
    /// mandate).
    ///
    /// `selection` is `"policy"` for a canonical run — no local override in
    /// effect — and otherwise a verbatim rendering of the narrowing delta;
    /// a receipt whose `selection` is not `"policy"` is non-canonical and
    /// must never be cited as a full-roster composition result.
    public struct Instrument: Equatable, Sendable, JSON.Serializable {
        public let workspaceCommit: Swift.String
        public let workspaceJsonBlob: Swift.String
        public let selection: Swift.String
        public let buildPath: Swift.String

        public init(
            workspaceCommit: Swift.String,
            workspaceJsonBlob: Swift.String,
            selection: Swift.String,
            buildPath: Swift.String = "xcodebuild-merged"
        ) {
            self.workspaceCommit = workspaceCommit
            self.workspaceJsonBlob = workspaceJsonBlob
            self.selection = selection
            self.buildPath = buildPath
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "workspaceCommit": value.workspaceCommit.json,
                "workspaceJsonBlob": value.workspaceJsonBlob.json,
                "selection": value.selection.json,
                "buildPath": value.buildPath.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let workspaceCommit = object["workspaceCommit"] else {
                throw .missingKey("workspaceCommit")
            }
            guard let workspaceJsonBlob = object["workspaceJsonBlob"] else {
                throw .missingKey("workspaceJsonBlob")
            }
            guard let selection = object["selection"] else { throw .missingKey("selection") }
            guard let buildPath = object["buildPath"] else { throw .missingKey("buildPath") }
            return try Self(
                workspaceCommit: Swift.String(json: workspaceCommit),
                workspaceJsonBlob: Swift.String(json: workspaceJsonBlob),
                selection: Swift.String(json: selection),
                buildPath: Swift.String(json: buildPath)
            )
        }
    }
}

extension Workspace.Coherence {
    /// The environment a run measured in. `fresh` and `cachesUsed` are part
    /// of the observation, not decoration: the canonical path caches
    /// nothing, and a receipt claiming otherwise is reporting on a
    /// different measurement than the one this instrument is doctrine-bound
    /// to make.
    public struct Environment: Equatable, Sendable, JSON.Serializable {
        public let platform: Swift.String
        public let swift: Swift.String
        public let xcode: Swift.String
        public let runner: Swift.String
        public let fresh: Swift.Bool
        public let cachesUsed: [Swift.String]

        public init(
            platform: Swift.String,
            swift: Swift.String,
            xcode: Swift.String,
            runner: Swift.String,
            fresh: Swift.Bool,
            cachesUsed: [Swift.String]
        ) {
            self.platform = platform
            self.swift = swift
            self.xcode = xcode
            self.runner = runner
            self.fresh = fresh
            self.cachesUsed = cachesUsed
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "platform": value.platform.json,
                "swift": value.swift.json,
                "xcode": value.xcode.json,
                "runner": value.runner.json,
                "fresh": value.fresh.json,
                "cachesUsed": value.cachesUsed.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let platform = object["platform"] else { throw .missingKey("platform") }
            guard let swift = object["swift"] else { throw .missingKey("swift") }
            guard let xcode = object["xcode"] else { throw .missingKey("xcode") }
            guard let runner = object["runner"] else { throw .missingKey("runner") }
            guard let fresh = object["fresh"] else { throw .missingKey("fresh") }
            guard let cachesUsed = object["cachesUsed"] else { throw .missingKey("cachesUsed") }
            return try Self(
                platform: Swift.String(json: platform),
                swift: Swift.String(json: swift),
                xcode: Swift.String(json: xcode),
                runner: Swift.String(json: runner),
                fresh: Swift.Bool(json: fresh),
                cachesUsed: [Swift.String](json: cachesUsed)
            )
        }
    }
}

extension Workspace.Coherence {
    /// The content-addressed receipt one coherence run emits.
    ///
    /// Sorted keys, no volatile ordering, no machine paths — the digest
    /// over the canonical serialization is what freezes the observation;
    /// the receipt, not prose, owns the facts (the #90/#94 pattern).
    public struct Receipt: Equatable, Sendable, Workspace.Receipt.Sealed {
        public let version: Swift.Int
        public let kind: Swift.String
        public let instrument: Instrument
        public let environment: Environment
        public let population: Population
        public let heads: [Swift.String: Swift.String]
        public let stages: [StageResult]
        public let verdict: Verdict
        public let attribution: Attribution?
        public let priorGreenReceipt: Swift.String?

        public init(
            version: Swift.Int = 1,
            kind: Swift.String = "ecosystem-coherence",
            instrument: Instrument,
            environment: Environment,
            population: Population,
            heads: [Swift.String: Swift.String],
            stages: [StageResult],
            verdict: Verdict,
            attribution: Attribution?,
            priorGreenReceipt: Swift.String?
        ) {
            self.version = version
            self.kind = kind
            self.instrument = instrument
            self.environment = environment
            self.population = population
            self.heads = heads
            self.stages = stages
            self.verdict = verdict
            self.attribution = attribution
            self.priorGreenReceipt = priorGreenReceipt
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "version": value.version.json,
                "kind": value.kind.json,
                "instrument": value.instrument.json,
                "environment": value.environment.json,
                "population": value.population.json,
                "heads": value.heads.json,
                "stages": value.stages.json,
                "verdict": value.verdict.json,
                "attribution": value.attribution.json,
                "priorGreenReceipt": value.priorGreenReceipt.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let version = object["version"] else { throw .missingKey("version") }
            guard let kind = object["kind"] else { throw .missingKey("kind") }
            guard let instrument = object["instrument"] else { throw .missingKey("instrument") }
            guard let environment = object["environment"] else { throw .missingKey("environment") }
            guard let population = object["population"] else { throw .missingKey("population") }
            guard let heads = object["heads"] else { throw .missingKey("heads") }
            guard let stages = object["stages"] else { throw .missingKey("stages") }
            guard let verdict = object["verdict"] else { throw .missingKey("verdict") }
            return try Self(
                version: Swift.Int(json: version),
                kind: Swift.String(json: kind),
                instrument: Instrument(json: instrument),
                environment: Environment(json: environment),
                population: Population(json: population),
                heads: [Swift.String: Swift.String](json: heads),
                stages: [StageResult](json: stages),
                verdict: Verdict(json: verdict),
                attribution: Attribution?(json: object["attribution"] ?? .null),
                priorGreenReceipt: Swift.String?(json: object["priorGreenReceipt"] ?? .null)
            )
        }
    }
}

// ``canonical`` and ``digest`` come from ``Workspace/Receipt/Sealed``
// (issue #83 Part 1) — this type contributed no members beyond the
// `JSON.Serializable` shape above, so the digest behavior did not change.
