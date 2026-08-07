extension Workspace.Inventory {
    /// The authenticated-runtime-derived extension to the committed public
    /// roster.
    ///
    /// **Why this is a namespace, not a committed file.** ``Policy`` and
    /// ``Client/discover(_:)`` already produce the *public* roster that
    /// ``Institute.json`` commits. A private repository is never eligible for
    /// that file — ``Eligibility/Reason/visibility(_:)`` excludes it — and the
    /// programme's own instruction is explicit: private entries reach the
    /// effective inventory "through authenticated runtime derivation when
    /// public commitment is not authorized," never through "a manually
    /// maintained second private list." So there is no
    /// `Workspace.Private.json` to design a schema for; there is only a
    /// second, symmetric discovery pass — ``Client/discoverPrivate(_:)`` —
    /// whose output is combined with the loaded public configuration each run
    /// by ``Workspace/Inventory/Effective``, and never written to disk.
    public enum Private: Sendable {}
}
