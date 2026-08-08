public import Async_Fanout
private import Environment
internal import File_System
public import Git_Foundation
public import Package_Manager
private import Process

extension Workspace {
    /// Reports what is true right now about the checkout, as the outcome
    /// of executed checks — never as prose. Every check ends in exactly
    /// one of the four ``Workspace/Doctor/Result`` states, and the run's
    /// exit status is 0 (measured, no errors), 1 (measured, errors), or
    /// 2 (something could not be measured).
    public struct Doctor: Sendable {
        public let root: Workspace.Root
        public let configuration: Configuration
        public let selection: Workspace.Selection.Resolved
        /// The registered peer institutes whose checkout facts the run
        /// measures (``Workspace/Peer/Registry``); empty when the
        /// checkout registers none.
        public let peers: [Workspace.Peer]
        public let git: Git.Client
        public let packages: Package.Manager

        /// How many subjects a per-subject check gathers at once.
        ///
        /// Every per-subject gather here spawns child processes and most of
        /// them wait on something — a remote, a Git process, SwiftPM — so
        /// serial gathering spends the majority of the run's wall clock
        /// idle. See ``Workspace/Fanout``.
        public let fanout: Workspace.Fanout

        /// Where the run reports what it is doing while it does it. Never
        /// consulted by a check and never part of an outcome.
        public let progress: Progress

        public let environment: @Sendable (_ variable: Swift.String) -> Swift.String?
        public let tool:
            @Sendable (
                _ executable: Swift.String,
                _ arguments: [Swift.String]
            ) throws(Workspace.Error) -> Swift.String

        public init(
            root: Workspace.Root,
            configuration: Configuration,
            selection: Workspace.Selection.Resolved,
            peers: [Workspace.Peer] = [],
            git: Git.Client = .init(),
            packages: Package.Manager = .init(),
            fanout: Workspace.Fanout = .init(),
            progress: Progress = .silent,
            environment: @escaping @Sendable (_ variable: Swift.String) -> Swift.String? =
                Self.variable,
            tool:
                @escaping @Sendable (
                    _ executable: Swift.String,
                    _ arguments: [Swift.String]
                ) throws(Workspace.Error) -> Swift.String = Self.interrogation()
        ) {
            self.root = root
            self.configuration = configuration
            self.selection = selection
            self.peers = peers
            self.git = git
            self.packages = packages
            self.fanout = fanout
            self.progress = progress
            self.environment = environment
            self.tool = tool
        }
    }
}

extension Workspace.Doctor {
    /// Runs every check and returns the report.
    ///
    /// A check whose declared scope exceeds `access` is gated to
    /// `notApplicable` here, before its measurement is attempted; a
    /// measurement that has begun can only end in `ok`, `finding`, or
    /// `unmeasured`.
    ///
    /// The run reports itself to ``progress`` as it goes — the selection in
    /// effect first, then each check's outcome as it lands, and each
    /// per-subject gather's completions as they accumulate. None of that is
    /// a measurement; the returned report is unchanged by whether anyone is
    /// listening.
    public func run(access: Access = .contributor) async -> Report {
        progress.write(selection.origin.description)
        let checkouts = await materialized(selection.repositories)
        var outcomes = [
            record(toolchain()),
            record(reference()),
            record(await materialization()),
            record(await census(checkouts)),
            record(await pins(checkouts)),
            record(await manifest(checkouts)),
            record(linter()),
            record(await peerCheckout()),
        ]
        switch access {
        case .contributor:
            outcomes.append(record(Self.currency.omitted))
            outcomes.append(record(Self.resolutionCurrency.omitted))
            outcomes.append(record(Self.lintConfigCurrency.omitted))
        case .institute(let inventory):
            do throws(Workspace.Error) {
                outcomes.append(record(currency(try await inventory())))
            } catch {
                outcomes.append(
                    record(Self.currency.unmeasured(reason: "inventory discovery failed: \(error)"))
                )
            }
            outcomes.append(record(await resolutionCurrency(checkouts)))
            outcomes.append(record(await lintConfigCurrency(checkouts)))
        }
        return .init(outcomes: outcomes, origin: selection.origin)
    }

    /// Reports a completed check's outcome to ``progress`` and returns it
    /// unchanged, so the run's transcript is written by the same expression
    /// that collects the report rather than by a parallel one that could
    /// disagree with it.
    private func record(_ outcome: Outcome) -> Outcome {
        progress.write("\(outcome.check): \(outcome.result)")
        return outcome
    }

    /// Every selected repository whose path holds a Git repository, in
    /// selection order.
    ///
    /// One `git` interrogation per selected repository, and the three
    /// per-subject checks downstream all measure what it finds.
    func materialized(
        _ repositories: [Workspace.Repository]
    ) async -> [(Workspace.Repository, File.Directory)] {
        await fanout.map(
            repositories,
            completed: progress.steps("locating checkouts", of: repositories.count)
        ) { repository in
            self.materialized(repository)
        }
        .compactMap { $0 }
    }

    /// The repository's on-disk checkout, when its path holds a Git
    /// repository.
    func materialized(_ repository: Workspace.Repository) -> (Workspace.Repository, File.Directory)? {
        do throws(Workspace.Error) {
            let path = try path(for: repository)
            let materialized = try execute { () throws(Git.Client.Error) -> Bool in
                try git.repository(at: path.description)
            }
            return materialized ? (repository, path) : nil
        } catch {
            return nil
        }
    }

    func path(for repository: Workspace.Repository) throws(Workspace.Error) -> File.Directory {
        try root.materialization(for: repository)
    }

    func execute<Result>(
        _ operation: () throws(Git.Client.Error) -> Result
    ) throws(Workspace.Error) -> Result {
        do throws(Git.Client.Error) {
            return try operation()
        } catch {
            throw .process("Git operation failed: \(error)")
        }
    }

    /// Reads the invoking process environment — the default
    /// interrogation behind ``environment``.
    public static func variable(_ name: Swift.String) -> Swift.String? {
        Environment.read(name)
    }

    /// The default interrogation behind ``tool``: spawns the tool and
    /// captures its standard output, against one environment snapshot taken
    /// when the interrogation is built.
    ///
    /// The snapshot is taken once, here, rather than at each spawn. A
    /// full-roster run makes thousands of these calls and gathers them
    /// concurrently, and inheriting the parent environment re-reads process
    /// global state on every one of them. Snapshotting also gives the run a
    /// property a report of facts should have anyway: every interrogation in
    /// it saw the same environment, so no finding can depend on when in the
    /// run it was measured.
    public static func interrogation() -> @Sendable (
        _ executable: Swift.String,
        _ arguments: [Swift.String]
    ) throws(Workspace.Error) -> Swift.String {
        let environment = Environment.Snapshot.current().values
        return { executable, arguments throws(Workspace.Error) in
            try spawn(executable, arguments: arguments, environment: environment)
        }
    }

    /// Spawns the tool and captures its standard output.
    public static func spawn(
        _ executable: Swift.String,
        arguments: [Swift.String],
        environment: [Swift.String: Swift.String]? = nil
    ) throws(Workspace.Error) -> Swift.String {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: [executable] + arguments,
                    environment: environment,
                    stdout: .pipe,
                    stderr: .pipe
                )
            )
        } catch {
            throw .process("cannot run \(executable): \(error)")
        }
        guard output.status == .exited(code: 0) else {
            let diagnostic = Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
            throw .process("\(executable) failed: \(diagnostic)")
        }
        return Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
    }
}
