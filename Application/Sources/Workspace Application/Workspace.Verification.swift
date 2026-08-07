extension Workspace {
    /// The private-package verification instrument (programme Task 2-01,
    /// `swift-institute/.github#276`, Task work object `#253`).
    ///
    /// A private repository produces no CI attestation at all (18
    /// `!github.event.repository.private` guards in `swift-ci.yml`,
    /// deliberately, per the principal's CI-first-ordering ruling — see
    /// `#253`). The gap this instrument closes is not the absence of CI; it
    /// is that the doctrine's substitution — run the same Swift-owned
    /// executables locally through Workspace, and record the substitution
    /// and its scope — previously existed as prose and produced no
    /// artifact. `Run` performs or seals that substitute verification for
    /// one subject package and emits one canonical, content-addressed
    /// ``Receipt``; ``Check`` independently re-parses and re-digests a
    /// sealed receipt.
    ///
    /// This type owns receipt *semantics* only. It never posts a GitHub
    /// status or check, never mints a credential, and never decides which
    /// private repositories are in scope — that is Task 2-02's trusted
    /// control-plane dispatcher (`swift-institute/.github`), which invokes
    /// `institute verification seal` at an exact recorded Workspace
    /// revision and supplies every fact this instrument cannot itself
    /// observe (see ``Run``'s documentation for exactly which facts those
    /// are and why they are caller-supplied rather than derived here).
    public enum Verification {}
}
