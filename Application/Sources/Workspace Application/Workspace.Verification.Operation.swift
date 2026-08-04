public import JSON

extension Workspace.Verification {
    /// The Workspace-owned operations one verification run can request.
    ///
    /// Fixed, not open-ended: a receipt's ``Gate`` set is keyed by this
    /// enum, so an operation this instrument does not itself know how to
    /// run can never appear as "satisfied" by construction.
    public enum Operation {}
}

extension Workspace.Verification.Operation {
    public enum Kind: Swift.String, Swift.CaseIterable, Equatable, Sendable, JSON.Serializable {
        case build
        case test
        case nestedTests = "nested-tests"
        case lint

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let kind = Self(rawValue: value) else {
                throw .typeMismatch(expected: "build, test, nested-tests, or lint", got: value)
            }
            return kind
        }
    }
}

extension Workspace.Verification.Operation {
    /// Whether an operation ran against isolated, fresh build state or
    /// reused whatever state the checkout already carried — the receipt's
    /// "fresh/cached provenance" field (Task 2-01).
    public enum Provenance: Swift.String, Equatable, Sendable, JSON.Serializable {
        case fresh
        case cached

        public static func serialize(_ value: Self) -> JSON { value.rawValue.json }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            let value = try Swift.String(json: json)
            guard let provenance = Self(rawValue: value) else {
                throw .typeMismatch(expected: "fresh or cached", got: value)
            }
            return provenance
        }
    }
}

extension Workspace.Verification.Operation {
    /// A best-effort parse of a `swift test` summary line — never invented
    /// when the invocation's captured output does not contain one.
    public struct TestCounts: Equatable, Sendable, JSON.Serializable {
        public let executed: Swift.Int
        public let passed: Swift.Int
        public let failed: Swift.Int

        public init(executed: Swift.Int, passed: Swift.Int, failed: Swift.Int) {
            self.executed = executed
            self.passed = passed
            self.failed = failed
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "executed": value.executed.json,
                "passed": value.passed.json,
                "failed": value.failed.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let executed = object["executed"] else { throw .missingKey("executed") }
            guard let passed = object["passed"] else { throw .missingKey("passed") }
            guard let failed = object["failed"] else { throw .missingKey("failed") }
            return try Self(
                executed: Swift.Int(json: executed),
                passed: Swift.Int(json: passed),
                failed: Swift.Int(json: failed)
            )
        }
    }
}

extension Workspace.Verification.Operation {
    /// One operation's disposition.
    ///
    /// Five states, not two, exactly the discipline
    /// ``Workspace/Lint/Measurement/Verdict`` and ``Workspace/Coherence``
    /// already carry: `success` and `failure` are both *measurements*, and
    /// so is `notApplicable` (there was genuinely nothing to run — no
    /// nested test package existed to test). `skipped` and `unmeasured`
    /// are the absence of one, and a receipt refuses to seal when a
    /// *required* operation lands in either — see
    /// ``Workspace/Verification/Run/run()``.
    public enum Outcome: Equatable, Sendable, JSON.Serializable {
        case success
        case failure
        case notApplicable(reason: Swift.String)
        case skipped(reason: Swift.String)
        case unmeasured(reason: Swift.String)

        /// A real determination was reached — this operation was not
        /// merely declined. `notApplicable` counts: the determination
        /// "there was nothing to run" is itself a measurement, distinct
        /// from "we did not look" (`skipped`/`unmeasured`).
        public var isExecuted: Swift.Bool {
            switch self {
            case .success, .failure, .notApplicable: true
            case .skipped, .unmeasured: false
            }
        }

        /// Whether this outcome alone satisfies a ``Gate``.
        /// `notApplicable` satisfies vacuously; every other non-`success`
        /// state does not.
        public var isSatisfying: Swift.Bool {
            switch self {
            case .success, .notApplicable: true
            case .failure, .skipped, .unmeasured: false
            }
        }

        public static func serialize(_ value: Self) -> JSON {
            switch value {
            case .success: ["state": "success".json]
            case .failure: ["state": "failure".json]
            case .notApplicable(let reason): ["state": "not-applicable".json, "reason": reason.json]
            case .skipped(let reason): ["state": "skipped".json, "reason": reason.json]
            case .unmeasured(let reason): ["state": "unmeasured".json, "reason": reason.json]
            }
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let state = object["state"] else { throw .missingKey("state") }
            let value = try Swift.String(json: state)
            switch value {
            case "success": return .success
            case "failure": return .failure
            case "not-applicable":
                guard let reason = object["reason"] else { throw .missingKey("reason") }
                return try .notApplicable(reason: Swift.String(json: reason))
            case "skipped":
                guard let reason = object["reason"] else { throw .missingKey("reason") }
                return try .skipped(reason: Swift.String(json: reason))
            case "unmeasured":
                guard let reason = object["reason"] else { throw .missingKey("reason") }
                return try .unmeasured(reason: Swift.String(json: reason))
            default:
                throw .typeMismatch(
                    expected: "success, failure, not-applicable, skipped, or unmeasured",
                    got: value
                )
            }
        }
    }
}

extension Workspace.Verification.Operation {
    /// One operation's complete, sealed record.
    ///
    /// `arguments` is exactly the `[String]` the coordinator forwarded to
    /// SwiftPM — "represented structurally" (Task 2-01), never a shell
    /// string a reader would have to re-parse. `compileEvidence` and
    /// `findings` are bounded, already-extracted facts (a first diagnostic
    /// line, a lint finding count) rather than raw captured output — the
    /// receipt records what was established, not a log dump a reader would
    /// have to re-derive it from.
    public struct Result: Equatable, Sendable, JSON.Serializable {
        public let operation: Kind
        public let subpath: Swift.String?
        public let arguments: [Swift.String]
        public let startedAt: Swift.String
        public let endedAt: Swift.String
        public let durationSeconds: Swift.Double
        public let exitCode: Swift.Int32?
        public let provenance: Provenance
        public let outcome: Outcome
        public let compileEvidence: Swift.String?
        public let testCounts: TestCounts?
        public let findings: [Swift.String]

        public init(
            operation: Kind,
            subpath: Swift.String? = nil,
            arguments: [Swift.String],
            startedAt: Swift.String,
            endedAt: Swift.String,
            durationSeconds: Swift.Double,
            exitCode: Swift.Int32?,
            provenance: Provenance,
            outcome: Outcome,
            compileEvidence: Swift.String? = nil,
            testCounts: TestCounts? = nil,
            findings: [Swift.String] = []
        ) {
            self.operation = operation
            self.subpath = subpath
            self.arguments = arguments
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationSeconds = durationSeconds
            self.exitCode = exitCode
            self.provenance = provenance
            self.outcome = outcome
            self.compileEvidence = compileEvidence
            self.testCounts = testCounts
            self.findings = findings
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "operation": value.operation.json,
                "subpath": value.subpath.json,
                "arguments": value.arguments.json,
                "startedAt": value.startedAt.json,
                "endedAt": value.endedAt.json,
                "durationSeconds": value.durationSeconds.json,
                "exitCode": value.exitCode.map { Swift.Int($0) }.json,
                "provenance": value.provenance.json,
                "outcome": value.outcome.json,
                "compileEvidence": value.compileEvidence.json,
                "testCounts": value.testCounts.json,
                "findings": value.findings.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let operation = object["operation"] else { throw .missingKey("operation") }
            guard let arguments = object["arguments"] else { throw .missingKey("arguments") }
            guard let startedAt = object["startedAt"] else { throw .missingKey("startedAt") }
            guard let endedAt = object["endedAt"] else { throw .missingKey("endedAt") }
            guard let durationSeconds = object["durationSeconds"] else {
                throw .missingKey("durationSeconds")
            }
            guard let provenance = object["provenance"] else { throw .missingKey("provenance") }
            guard let outcome = object["outcome"] else { throw .missingKey("outcome") }
            guard let findings = object["findings"] else { throw .missingKey("findings") }
            let exitCode = try Swift.Int?(json: object["exitCode"] ?? .null)
            return try Self(
                operation: Kind(json: operation),
                subpath: Swift.String?(json: object["subpath"] ?? .null),
                arguments: [Swift.String](json: arguments),
                startedAt: Swift.String(json: startedAt),
                endedAt: Swift.String(json: endedAt),
                durationSeconds: Swift.Double(json: durationSeconds),
                exitCode: exitCode.map(Swift.Int32.init),
                provenance: Provenance(json: provenance),
                outcome: Outcome(json: outcome),
                compileEvidence: Swift.String?(json: object["compileEvidence"] ?? .null),
                testCounts: TestCounts?(json: object["testCounts"] ?? .null),
                findings: [Swift.String](json: findings)
            )
        }
    }
}
