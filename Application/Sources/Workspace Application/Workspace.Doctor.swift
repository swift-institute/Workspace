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
        public let git: Git.Client
        public let packages: Package.Manager
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
            git: Git.Client = .init(),
            packages: Package.Manager = .init(),
            environment: @escaping @Sendable (_ variable: Swift.String) -> Swift.String? =
                Self.variable,
            tool:
                @escaping @Sendable (
                    _ executable: Swift.String,
                    _ arguments: [Swift.String]
                ) throws(Workspace.Error) -> Swift.String = Self.spawn
        ) {
            self.root = root
            self.configuration = configuration
            self.selection = selection
            self.git = git
            self.packages = packages
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
    public func run(access: Access = .contributor) async -> Report {
        let checkouts = selection.repositories.compactMap(materialized)
        var outcomes = [
            toolchain(),
            reference(),
            materialization(),
            census(checkouts),
            pins(checkouts),
            manifest(checkouts),
            linter(),
        ]
        switch access {
        case .contributor:
            outcomes.append(Self.currency.omitted)
        case .institute(let inventory):
            do throws(Workspace.Error) {
                outcomes.append(currency(try await inventory()))
            } catch {
                outcomes.append(
                    Self.currency.unmeasured(reason: "inventory discovery failed: \(error)")
                )
            }
        }
        return .init(outcomes: outcomes, origin: selection.origin)
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

    /// Spawns the tool and captures its standard output — the default
    /// interrogation behind ``tool``.
    public static func spawn(
        _ executable: Swift.String,
        arguments: [Swift.String]
    ) throws(Workspace.Error) -> Swift.String {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: [executable] + arguments,
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
