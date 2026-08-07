extension Workspace.Verification.Operation.Result {
    /// The same result with every captured free-text field rewritten in
    /// coordinates relative to the subject.
    ///
    /// **Why this is central and not per-leg.** The lint leg was fixed
    /// first, because its findings are the ones that visibly refused every
    /// seal. That was the correct principle applied to one instance of the
    /// class: `compileEvidence` on the build and test legs is captured the
    /// same way, from tools pointed at the same absolute path, and refuses
    /// the seal for the same reason the moment a subject actually emits a
    /// compiler diagnostic — observed as
    /// `seal-refusal:unsafe-content` on hosted runs 31143653197 and
    /// siblings, where the subject failed to compile and the receipt could
    /// therefore not be produced at all.
    ///
    /// Applying it once, to every leg, is what makes the rule a property
    /// of the receipt boundary rather than of whichever leg someone
    /// remembered. An absolute path that is *not* under the subject root
    /// still refuses the seal — this narrows what must be refused, it does
    /// not weaken the refusal.
    func relative(to root: Swift.String) -> Self {
        .init(
            operation: operation,
            subpath: subpath,
            arguments: arguments,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            exitCode: exitCode,
            provenance: provenance,
            outcome: outcome,
            compileEvidence: compileEvidence.map {
                Workspace.Verification.Redaction.relative($0, to: root)
            },
            testCounts: testCounts,
            findings: findings.map { Workspace.Verification.Redaction.relative($0, to: root) }
        )
    }
}
