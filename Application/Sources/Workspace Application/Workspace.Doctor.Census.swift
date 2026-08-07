internal import Async_Fanout
import File_System
private import Git_Foundation

extension Workspace.Doctor {
    /// One materialized repository's working state, read in one pass:
    /// where HEAD is, what it tracks, how far it has moved against the
    /// resolved upstream, what the worktree carries, and whether a
    /// resolved-state file is present and ignored.
    public struct Census: Equatable, Sendable {
        public let name: Swift.String
        public let url: Swift.String
        public let origin: Swift.String
        public let head: Head
        public let upstream: Swift.String
        public let ahead: Int
        public let behind: Int
        public let dirty: Int
        public let untracked: Int
        public let resolved: Resolved

        public init(
            name: Swift.String,
            url: Swift.String,
            origin: Swift.String,
            head: Head,
            upstream: Swift.String,
            ahead: Int,
            behind: Int,
            dirty: Int,
            untracked: Int,
            resolved: Resolved
        ) {
            self.name = name
            self.url = url
            self.origin = origin
            self.head = head
            self.upstream = upstream
            self.ahead = ahead
            self.behind = behind
            self.dirty = dirty
            self.untracked = untracked
            self.resolved = resolved
        }
    }
}

extension Workspace.Doctor {
    /// The working-state census: every materialized repository's state,
    /// judged against the guarantees `sync` relies on. The census only
    /// reports — `sync` owns the sole safe mutation, and it refuses
    /// dirty, diverged, and feature-branch repositories.
    ///
    /// Dirty worktrees, untracked entries, detached HEADs, and feature
    /// branches are warnings and remain untouched; divergence from the
    /// resolved upstream is an error.
    public static let census = Check<Census>(
        name: "working-state",
        scope: .contributor,
        controls: .init(
            positive: .init(
                name: "control",
                url: "https://example.com/control.git",
                origin: "https://example.com/other.git",
                head: .branch("main"),
                upstream: "origin/main",
                ahead: 0,
                behind: 0,
                dirty: 0,
                untracked: 0,
                resolved: .absent
            ),
            negative: .init(
                name: "control",
                url: "https://example.com/control.git",
                origin: "https://example.com/control.git",
                head: .branch("main"),
                upstream: "origin/main",
                ahead: 0,
                behind: 0,
                dirty: 0,
                untracked: 0,
                resolved: .ignored
            )
        )
    ) { repository in
        var findings = [Finding]()
        if repository.origin != repository.url {
            findings.append(
                .init(
                    severity: .error,
                    message: "\(repository.name): wrong origin \(repository.origin)"
                )
            )
        }
        if repository.upstream != "origin/main" {
            findings.append(
                .init(
                    severity: .error,
                    message: "\(repository.name): local main does not track origin/main"
                )
            )
        }
        switch repository.head {
        case .detached:
            findings.append(
                .init(
                    severity: .warning,
                    message: "\(repository.name): HEAD is detached; sync will not touch it"
                )
            )
        case .branch("main"):
            break
        case .branch(let branch):
            findings.append(
                .init(
                    severity: .warning,
                    message: "\(repository.name): current branch is \(branch); sync will not switch it"
                )
            )
        }
        if repository.dirty > 0 {
            findings.append(
                .init(
                    severity: .warning,
                    message: "\(repository.name): worktree carries \(repository.dirty) dirty "
                        + "entries; sync will not update it"
                )
            )
        }
        if repository.untracked > 0 {
            findings.append(
                .init(
                    severity: .warning,
                    message: "\(repository.name): worktree carries \(repository.untracked) "
                        + "untracked entries; sync will not touch them"
                )
            )
        }
        if repository.upstream == "origin/main", repository.ahead > 0 || repository.behind > 0 {
            // A warning, not an error, because this is the one observation in
            // this check that is not certain. `doctor` never fetches — it is
            // offline and credential-free by design, and fetching would cost a
            // network round trip per repository across the whole roster — so
            // the comparison is against a remote-tracking ref of unknown age,
            // not against the remote. A checkout that has not fetched recently
            // reports commits as unpushed that are already on origin, and it
            // did: two of the three divergences reported on this roster on
            // 2026-07-29 evaporated on `git fetch`, and one nearly became a
            // redundant push. Erroring on that blocks people on a phantom,
            // which is worse than the divergence it is warning about — and the
            // certain local-work signals beside it, dirty and untracked, are
            // already warnings.
            findings.append(
                .init(
                    severity: .warning,
                    message: "\(repository.name): local main diverges from the last fetched "
                        + "origin/main (ahead \(repository.ahead), behind \(repository.behind)) "
                        + "— the tracking ref may be stale; `git fetch` in that repository to "
                        + "tell a real divergence from a cached one"
                )
            )
        }
        if repository.resolved == .exposed {
            findings.append(
                .init(
                    severity: .warning,
                    message: "\(repository.name): Package.resolved is present and not ignored — "
                        + "generated state; never commit it"
                )
            )
        }
        return findings
    }

    /// Up to six `git` interrogations per materialized repository,
    /// gathered concurrently.
    ///
    /// Each repository is an independent checkout and the gather reads it
    /// without writing, so nothing here depends on the order the gathers
    /// complete in. The short-circuit does depend on order, and keeps it:
    /// results come back in selection order and the *first* unreadable
    /// repository in that order names the reason, exactly as the serial
    /// gather did. Concurrency costs only work already begun on repositories
    /// after it — never a different verdict.
    func census(_ materialized: [(Workspace.Repository, File.Directory)]) async -> Outcome {
        let observed = await fanout.map(
            materialized,
            completed: progress.steps("working-state: gathered", of: materialized.count)
        ) { entry in
            let (repository, path) = entry
            do throws(Workspace.Error) {
                return Swift.Result<Census, Workspace.Error>.success(
                    try self.observe(repository, at: path)
                )
            } catch {
                return .failure(error)
            }
        }

        var population = [Census]()
        population.reserveCapacity(observed.count)
        for (offset, result) in observed.enumerated() {
            switch result {
            case .success(let census):
                population.append(census)
            case .failure(let error):
                return Self.census.unmeasured(
                    reason: "\(materialized[offset].0.name): cannot read its working state: \(error)"
                )
            }
        }
        return Self.census.run(
            population: population,
            inventory: selection.repositories.count
        )
    }

    private func observe(
        _ repository: Workspace.Repository,
        at path: File.Directory
    ) throws(Workspace.Error) -> Census {
        let upstream = try execute { () throws(Git.Client.Error) -> Swift.String in
            try git.upstream("main", at: path.description)
        }
        let counts: (ahead: Int, behind: Int) =
            upstream == "origin/main"
            ? (
                try execute { () throws(Git.Client.Error) -> Int in
                    try git.count("origin/main..main", at: path.description)
                },
                try execute { () throws(Git.Client.Error) -> Int in
                    try git.count("main..origin/main", at: path.description)
                }
            )
            : (0, 0)
        let branch = try execute { () throws(Git.Client.Error) -> Swift.String in
            try git.branch(at: path.description)
        }
        let entries = try execute { () throws(Git.Client.Error) -> [Git.Status.Entry] in
            try git.status(at: path.description)
        }
        let untracked = entries.count { $0.index == .untracked && $0.tree == .untracked }
        return .init(
            name: repository.name,
            url: repository.url,
            origin: try execute { () throws(Git.Client.Error) -> Swift.String in
                try git.remote("origin", at: path.description)
            },
            head: branch.isEmpty ? .detached : .branch(branch),
            upstream: upstream,
            ahead: counts.ahead,
            behind: counts.behind,
            dirty: entries.count - untracked,
            untracked: untracked,
            resolved: try resolvedState(at: path)
        )
    }

    /// Whether the repository's resolved-state file is present, and if
    /// so whether it is ignored. Both interrogations exit zero whatever
    /// they find, so a thrown error here is a broken interrogation —
    /// never a state.
    private func resolvedState(at path: File.Directory) throws(Workspace.Error) -> Census.Resolved {
        let status = try tool(
            "git",
            [
                "-C", path.description,
                "status", "--porcelain", "--ignored=matching", "--", "Package.resolved",
            ]
        )
        if !status.isEmpty {
            return status.hasPrefix("!!") ? .ignored : .exposed
        }
        let tracked = try tool(
            "git",
            ["-C", path.description, "ls-files", "--", "Package.resolved"]
        )
        return tracked.isEmpty ? .absent : .exposed
    }
}
