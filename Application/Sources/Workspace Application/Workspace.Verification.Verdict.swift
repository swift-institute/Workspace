public import JSON

extension Workspace.Verification {
    /// A sealed receipt's overall determination.
    ///
    /// `verified` requires every requested operation to have reached
    /// ``Operation/Outcome/isSatisfying`` and every required ``Gate`` to be
    /// `satisfied` — ``Run/run()`` computes it, never a caller.
    /// `unverified` is a real, sealed, citable receipt: the subject was
    /// measured and did not pass. It is distinct from the refusal cases
    /// ``Error`` represents (zero operations, a missing required
    /// operation, a head mismatch, a dirty subject) precisely because
    /// those are not measurements of the subject at all — they are this
    /// instrument declining to claim it measured anything, and a receipt
    /// is never sealed for them.
    public enum Verdict: Equatable, Sendable, JSON.Serializable {
        case verified
        case unverified(reason: Swift.String)

        public static func serialize(_ value: Self) -> JSON {
            switch value {
            case .verified: ["state": "verified".json]
            case .unverified(let reason): ["state": "unverified".json, "reason": reason.json]
            }
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let state = object["state"] else { throw .missingKey("state") }
            let value = try Swift.String(json: state)
            switch value {
            case "verified": return .verified
            case "unverified":
                guard let reason = object["reason"] else { throw .missingKey("reason") }
                return try .unverified(reason: Swift.String(json: reason))
            default:
                throw .typeMismatch(expected: "verified or unverified", got: value)
            }
        }
    }
}

extension Workspace.Verification.Verdict {
    /// Whether this verdict alone should fail a caller reading the receipt
    /// as a pass/fail gate — the same "one boolean a CI leg can switch on"
    /// convenience ``Workspace/Lint/Measurement/Verdict/fails`` and
    /// ``Workspace/Coherence/Verdict`` already provide.
    public var fails: Swift.Bool {
        switch self {
        case .verified: false
        case .unverified: true
        }
    }
}
