extension Workspace {
    /// The ecosystem coherence instrument.
    ///
    /// Per-package CI proves each package against its own resolution — its
    /// declared dependencies, resolved at its own trigger time, on its own
    /// matrix. Nothing else measures whether the fleet's canonical `main`
    /// heads **compose**: that one graph containing every selected package,
    /// resolved to today's tips, type-checks and compiles together.
    /// Branch-based dependencies make this gap real — two packages can each
    /// be green while their current tips are mutually incompatible through a
    /// shared consumer, and nothing before this measured that.
    ///
    /// ``Run`` walks the stages `sync` → `doctor` → `graph` → `build` →
    /// `population` in order and stops at the first that fails; every
    /// later stage is recorded ``Coherence/Outcome/notRun``. `bootstrap` —
    /// the self-hosting `institute install` compile that produced the
    /// executable running this instrument — is recorded a unconditional
    /// success: this process running is bootstrap's own proof, and its
    /// wall-clock is measured by the CI wiring's calibration dispatches
    /// (`swift-institute/.github#125`), never locally.
    ///
    /// The whole run emits one content-addressed ``Receipt`` — the digest
    /// freezes the observation, so a green is a comparable artifact rather
    /// than one machine's anecdote.
    public enum Coherence {}
}
