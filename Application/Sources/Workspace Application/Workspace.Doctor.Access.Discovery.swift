private import GitHub_HTTP

extension Workspace.Doctor.Access {
    /// Institute access backed by a live discovery of the Institute
    /// organizations.
    ///
    /// This is the only construction of ``Workspace/Doctor/Access/institute(inventory:)``
    /// outside the tests. Until it existed the `inventory-currency` check
    /// was written, tested, controlled — and unreachable from any command,
    /// so every real run reported it as not run (Workspace issue #43).
    ///
    /// It uses the same policy, transport, and client as `institute inventory
    /// regenerate`, deliberately: `doctor`'s verdict about the roster and a
    /// regeneration of the roster must not be able to disagree about what is
    /// on GitHub.
    ///
    /// ## Cost, and why no command reaches this by default
    ///
    /// Discovery issues roughly one request per repository — about 460
    /// today — and needs an authenticated `gh` on the machine, exactly as
    /// `institute inventory regenerate` does. `doctor` otherwise needs no
    /// credentials and touches no network, and `CLAUDE.md` promises
    /// contributors that it stays that way. So the caller asks for this explicitly
    /// (`institute doctor --institute`); it is never selected from ambient
    /// machine state. A contributor who has authenticated `gh` for
    /// `gh issue list` — which the contributing instructions tell them to
    /// run — must not thereby get a different, slower, network-bound
    /// `doctor` than the one CI proves.
    ///
    /// A discovery that fails surfaces as `unmeasured`, never as a clean
    /// result: the run that could not look is distinguishable from the run
    /// that looked and found nothing.
    public static func institute(policy: Workspace.Inventory.Policy = .institute()) -> Self {
        .institute(inventory: { () throws(Workspace.Error) -> Workspace.Inventory.Discovery in
            let http = GitHub.HTTP.Client<
                Workspace.Inventory.Transport.Error,
                GitHub.HTTP.Pagination.Error
            >(
                agent: .init(rawValue: "swift-institute-workspace"),
                version: .init(rawValue: "2022-11-28"),
                execute: Workspace.Inventory.Transport.githubCLI()
            )
            do {
                return try await Workspace.Inventory.client(
                    http,
                    // `gh` supplies the credential; see Workspace.Inventory.Transport.
                    authentication: .token(.init(rawValue: ""))
                ).discover(policy)
            } catch {
                throw .configuration("\(error)")
            }
        })
    }
}
