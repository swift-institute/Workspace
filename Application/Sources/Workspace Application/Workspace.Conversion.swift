extension Workspace {
    /// The shared content-addressed conversion receipt (issue #83 Part 2):
    /// seals the canary cohort, the page inventory, and — by derivation,
    /// never by authoring — the pre-registered protocol's arm assignments.
    ///
    /// Workspace owns the schema, the sealing, and the consistency checks —
    /// never the judgments. Choosing the cohort, converting a page, running
    /// a trial, capturing a remote-state snapshot, and computing the §6
    /// decision are the canary run's own gated work; this namespace records
    /// and validates their outcomes, nothing more.
    public enum Conversion {}
}

extension Workspace.Conversion {
    /// The pre-registered protocol document this receipt kind certifies
    /// against, frozen before any trial (protocol §0): the commit of
    /// `swift-institute/Research` that authored it, and the git blob
    /// digest of the document at that commit — "the freeze digest is the
    /// protocol the run executed."
    public static let protocolCommit: Swift.String = "cfc2216dca7031d1b8e4a886aad7de33dd4843bc"
    public static let protocolBlob: Swift.String = "b39bb77d717f12d5de1f0d243a92ddaf291fac56"
}
