import File_System
private import Git_Foundation

extension Workspace.Doctor {
    /// One materialized repository's Git facts, judged against the
    /// guarantees `sync` relies on.
    public struct Synchronization: Equatable, Sendable {
        public let name: Swift.String
        public let url: Swift.String
        public let origin: Swift.String
        public let upstream: Swift.String
        public let branch: Swift.String
        public let worktree: Worktree
        public let ahead: Int
        public let behind: Int

        public init(
            name: Swift.String,
            url: Swift.String,
            origin: Swift.String,
            upstream: Swift.String,
            branch: Swift.String,
            worktree: Worktree,
            ahead: Int,
            behind: Int
        ) {
            self.name = name
            self.url = url
            self.origin = origin
            self.upstream = upstream
            self.branch = branch
            self.worktree = worktree
            self.ahead = ahead
            self.behind = behind
        }
    }
}

extension Workspace.Doctor {
    /// Every materialized repository has the configured origin, tracks
    /// `origin/main`, and carries no divergence `sync` would refuse.
    public static let synchronization = Check<Synchronization>(
        name: "synchronization",
        scope: .contributor,
        controls: .init(
            positive: .init(
                name: "control",
                url: "https://example.com/control.git",
                origin: "https://example.com/other.git",
                upstream: "origin/main",
                branch: "main",
                worktree: .clean,
                ahead: 0,
                behind: 0
            ),
            negative: .init(
                name: "control",
                url: "https://example.com/control.git",
                origin: "https://example.com/control.git",
                upstream: "origin/main",
                branch: "main",
                worktree: .clean,
                ahead: 0,
                behind: 0
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
        if repository.worktree == .dirty {
            findings.append(
                .init(
                    severity: .warning,
                    message: "\(repository.name): worktree is dirty; sync will not update it"
                )
            )
        }
        if repository.branch != "main" {
            let branch = repository.branch.isEmpty ? "detached" : repository.branch
            findings.append(
                .init(
                    severity: .warning,
                    message: "\(repository.name): current branch is \(branch); sync will not switch it"
                )
            )
        }
        if repository.upstream == "origin/main", repository.ahead > 0 || repository.behind > 0 {
            findings.append(
                .init(
                    severity: .error,
                    message: "\(repository.name): local main is not synchronized with the last "
                        + "fetched origin/main (ahead \(repository.ahead), behind \(repository.behind))"
                )
            )
        }
        return findings
    }

    func synchronization(_ materialized: [(Workspace.Repository, File.Directory)]) -> Outcome {
        do throws(Workspace.Error) {
            var population = [Synchronization]()
            for (repository, path) in materialized {
                population.append(try observe(repository, at: path))
            }
            return Self.synchronization.run(
                population: population,
                inventory: configuration.repositories.count
            )
        } catch {
            return Self.synchronization.unmeasured(
                reason: "a Git interrogation failed: \(error)"
            )
        }
    }

    private func observe(
        _ repository: Workspace.Repository,
        at path: File.Directory
    ) throws(Workspace.Error) -> Synchronization {
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
        return .init(
            name: repository.name,
            url: repository.url,
            origin: try execute { () throws(Git.Client.Error) -> Swift.String in
                try git.remote("origin", at: path.description)
            },
            upstream: upstream,
            branch: try execute { () throws(Git.Client.Error) -> Swift.String in
                try git.branch(at: path.description)
            },
            worktree: try execute({ () throws(Git.Client.Error) -> [Git.Status.Entry] in
                try git.status(at: path.description)
            }).isEmpty ? .clean : .dirty,
            ahead: counts.ahead,
            behind: counts.behind
        )
    }
}
