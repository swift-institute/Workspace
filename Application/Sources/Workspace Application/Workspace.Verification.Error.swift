extension Workspace.Verification {
    /// Why ``Run/run()`` refused to seal a receipt.
    ///
    /// Every case here is a *refusal*, not a failing measurement: a
    /// subject that was genuinely measured and found wanting seals as an
    /// ``Verdict/unverified`` receipt, which is the whole point of keeping
    /// this type small. These cases exist because sealing a receipt at all
    /// would misrepresent what happened — the producer never measured the
    /// claimed commit, never ran a required operation, or captured content
    /// that must not leave this process.
    public enum Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        case subject(Swift.String)
        case headMismatch(claimed: Swift.String, observed: Swift.String)
        case dirtySubject(Swift.String)
        case noOperationExecuted
        case requiredOperationMissing(Operation.Kind)
        case requiredOperationNotExecuted(Operation.Kind)
        case unsafeContent(Swift.String)
        case configuration(Swift.String)
    }
}

extension Workspace.Verification.Error {
    public var description: Swift.String {
        switch self {
        case .subject(let message):
            "cannot establish the verification subject: \(message)"
        case .headMismatch(let claimed, let observed):
            "claimed head \(claimed) does not match the checked-out head \(observed); "
                + "refusing to seal a receipt for a commit this run did not observe"
        case .dirtySubject(let path):
            "\(path) has uncommitted changes; refusing to seal a receipt for a dirty subject"
        case .noOperationExecuted:
            "zero operations reached a real outcome; a receipt attesting nothing was measured "
                + "is refused"
        case .requiredOperationMissing(let kind):
            "required operation \(kind.rawValue) was not requested; refusing to seal a receipt "
                + "silently missing it"
        case .requiredOperationNotExecuted(let kind):
            "required operation \(kind.rawValue) was skipped or unmeasured; refusing to seal a "
                + "receipt claiming it ran"
        case .unsafeContent(let reason):
            "refusing to seal: captured evidence \(reason)"
        case .configuration(let message):
            message
        }
    }
}
