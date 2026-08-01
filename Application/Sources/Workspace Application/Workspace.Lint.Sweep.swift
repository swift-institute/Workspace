internal import File_System
public import Git_Foundation

extension Workspace.Lint {
    /// The whole-ecosystem mode.
    ///
    /// Enumerates from `Workspace.json` — never by walking the tree.
    /// A tree walk carries its own layout assumptions and fails toward
    /// clean-looking empties, which is the failure this capability
    /// exists to make impossible.
    ///
    /// The sweep is not a second implementation of linting. It resolves
    /// the installation once and then calls the same
    /// ``Workspace/Lint/measure(_:using:default:)`` the single-package
    /// mode calls, so a package's verdict cannot depend on which entry
    /// point asked for it. That extends to the default rule set: the two
    /// modes reach the same ``Workspace/Lint/Bundle`` by different
    /// routes — the inventory's layer here, the materialized path there
    /// — and ``Workspace/Layout`` makes those routes agree.
    public struct Sweep: Sendable {
        public let lint: Workspace.Lint

        /// The checkout whose inventory defines the population, and
        /// whose hierarchy the packages materialize under.
        public let root: Workspace.Root

        /// The inventory, verbatim from `Workspace.json`.
        public let repositories: [Workspace.Repository]

        public let git: Git.Client

        /// How many packages are linted at once.
        ///
        /// Defaults to the online processor count. The engine's fast
        /// path is CPU-bound and single-threaded per package, so
        /// parallelism across packages is where the time goes.
        public let jobs: Swift.Int

        /// The online processor count.
        ///
        /// Read from the machine rather than fixed, so the sweep neither
        /// under-uses a large host nor oversubscribes a small one.
        public static var processors: Swift.Int {
            Workspace.Fanout.processors
        }

        public init(
            lint: Workspace.Lint,
            root: Workspace.Root,
            repositories: [Workspace.Repository],
            git: Git.Client = .init(),
            jobs: Swift.Int? = nil
        ) {
            self.lint = lint
            self.root = root
            self.repositories = repositories
            self.git = git
            self.jobs = Swift.max(1, jobs ?? Self.processors)
        }
    }
}

extension Workspace.Lint.Sweep {
    /// Which packages a sweep covers.
    public enum Scope: Equatable, Sendable {
        /// Every materialized package in the inventory.
        case all

        /// Only packages with local work: an unclean working tree, or
        /// commits not yet in the tracked upstream.
        ///
        /// Defined per repository rather than against one global ref,
        /// because the 441 packages are independent repositories with
        /// independent histories — a single shared ref has no meaning
        /// across them. A repository whose state cannot be read is
        /// **included**, never skipped: a scope filter that silently
        /// drops what it could not classify is the narrowing this
        /// capability is built to refuse.
        case changed
    }
}

extension Workspace.Lint.Sweep {
    /// Lints the ecosystem and returns the aggregate.
    ///
    /// The empty-population guard is the sweep's own version of the
    /// per-package UNMEASURED rule, and it exists because this exact
    /// failure has happened in this fleet: a validator run from the
    /// wrong root scanned nothing and reported green. A sweep that
    /// enumerated an inventory and then found nothing on disk has not
    /// established that the ecosystem is clean; it has established that
    /// it is looking in the wrong place.
    public func run(
        scope: Scope = .all,
        fix: Workspace.Lint.Fix? = nil
    ) async throws(Workspace.Error) -> Workspace.Lint.Report {
        let installation = try lint.installation()
        let inventory = repositories

        var targets = [(repository: Workspace.Repository, target: Workspace.Lint.Target)]()
        var absent = [Swift.String]()
        for repository in inventory {
            let directory = try root.materialization(for: repository)
            guard File(directory.path).stat.isDirectory else {
                absent.append(repository.name)
                continue
            }
            guard directory[file: "Package.swift"].stat.isFile else {
                absent.append(repository.name)
                continue
            }
            targets.append(
                (repository: repository, target: .init(package: directory, file: nil))
            )
        }

        guard !targets.isEmpty || inventory.isEmpty else {
            throw .configuration(
                "UNMEASURED: \(inventory.count) packages in the inventory, none materialized under "
                    + "\(lint.hierarchy). Nothing was linted. This is very likely the wrong "
                    + "hierarchy root rather than an empty ecosystem — check where `workspace` was "
                    + "invoked from, or pass --workspace-path."
            )
        }

        let selected: [(repository: Workspace.Repository, target: Workspace.Lint.Target)]
        switch scope {
        case .all:
            selected = targets
        case .changed:
            let git = self.git
            let local = await concurrently(targets) { entry in
                Self.hasLocalWork(entry.target.package, using: git)
            }
            selected = zip(targets, local).filter(\.1).map(\.0)
        }

        // The bundle comes from the inventory entry's layer, which is
        // authoritative — the sweep never has to derive it from where a
        // package happens to sit on disk. It is passed for every package,
        // configured or not; `measure` uses it only for the ones with no
        // `Lint.swift`, and a configured package's own manifest always
        // wins.
        let measurements = await measure(
            selected.map { entry in
                (
                    target: entry.target,
                    bundle: Workspace.Lint.Bundle(entry.repository.layer)
                )
            },
            using: installation,
            fix: fix
        )
        return .init(
            scope: scope,
            inventory: inventory.count,
            unmaterialized: absent,
            considered: targets.count,
            measurements: measurements
        )
    }

    /// Measures every target, `jobs` at a time.
    func measure(
        _ targets: [(target: Workspace.Lint.Target, bundle: Workspace.Lint.Bundle)],
        using installation: Workspace.Lint.Installation,
        fix: Workspace.Lint.Fix?
    ) async -> [Workspace.Lint.Measurement] {
        let lint = self.lint
        return await concurrently(targets) { entry in
            lint.measure(
                entry.target,
                using: installation,
                default: entry.bundle,
                fix: fix
            )
        }
    }

    /// Runs `work` over `items` with at most `jobs` in flight, returning
    /// results in input order.
    ///
    /// Bounded rather than unbounded: every unit of work here spawns a
    /// child process, and hundreds at once would thrash rather than
    /// finish sooner. Used for the scope filter as well as the
    /// measurement — the filter interrogates Git once per repository,
    /// and run sequentially over hundreds of repositories it costs more
    /// than the linting it is supposed to avoid.
    ///
    /// The bounding itself belongs to ``Workspace/Fanout``, which `doctor`
    /// gathers through as well. Two implementations of the same bound would
    /// be two chances to drift.
    func concurrently<Item: Sendable, Result: Sendable>(
        _ items: [Item],
        _ work: @escaping @Sendable (Item) -> Result
    ) async -> [Result] {
        await Workspace.Fanout(jobs: jobs).map(items, work)
    }

    /// Whether the repository at `directory` carries local work.
    ///
    /// Returns `true` when the state cannot be read. An unreadable
    /// repository is linted rather than skipped: the cost of linting one
    /// package unnecessarily is a second; the cost of skipping one
    /// silently is a false clean.
    static func hasLocalWork(
        _ directory: File.Directory,
        using git: Git.Client
    ) -> Swift.Bool {
        do throws(Git.Client.Error) {
            guard try git.repository(at: directory.description) else { return true }
            if !(try git.status(at: directory.description)).isEmpty { return true }
            let branch = try git.branch(at: directory.description)
            let upstream = try git.upstream(branch, at: directory.description)
            return try git.count("\(upstream)..HEAD", at: directory.description) > 0
        } catch {
            return true
        }
    }
}
