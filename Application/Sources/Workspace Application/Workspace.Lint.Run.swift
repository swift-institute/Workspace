private import Environment
public import File_System
private import Process

extension Workspace.Lint {
    /// An installed, verified pair of linter binaries, ready to invoke.
    ///
    /// Resolved once and reused for every package in a sweep, so the
    /// whole-ecosystem mode pays the installation checks once rather
    /// than 441 times — and so a single-package run pays them exactly
    /// once too.
    public struct Installation: Sendable {
        public let manifest: Manifest
        public let executable: File
        public let runner: File
    }
}

extension Workspace.Lint {
    /// Resolves the installed binaries, or explains what is missing.
    ///
    /// Reads only local state. A lint run never touches the network:
    /// the parity comparison against CI belongs to
    /// ``Workspace/Lint/divergence()``, which `institute lint check` and
    /// `institute doctor` call. Putting a network round trip on the
    /// inner loop would make the fast path slow, and the fast path being
    /// fast is what decides whether any of this gets used.
    public func installation() throws(Workspace.Error) -> Installation {
        guard manifestFile.stat.isFile else {
            throw .configuration(
                "swift-linter is not installed; run `institute lint install`"
            )
        }
        let manifest = try installedManifest()
        let executable = try executable(for: manifest)
        let runner = try runner(for: manifest)
        guard executable.stat.isFile else {
            throw .configuration(
                "installed manifest records digest \(manifest.digest) but \(executable) is missing; "
                    + "run `institute lint install`"
            )
        }
        guard runner.stat.isFile else {
            throw .configuration(
                "installed manifest records digest \(manifest.digest) but \(runner) is missing; "
                    + "run `institute lint install`"
            )
        }
        return .init(manifest: manifest, executable: executable, runner: runner)
    }

    /// The build manifest recorded at install time.
    public func installedManifest() throws(Workspace.Error) -> Manifest {
        try Manifest.parse(
            try Workspace.Lint.read(manifestFile),
            label: "installed manifest \(manifestFile)"
        )
    }
}

extension Workspace.Lint {
    /// Lints one package root and adjudicates the result.
    ///
    /// This is the only place in the capability that spawns the engine.
    /// The single-package mode calls it once; the sweep calls it per
    /// package. There is no second implementation for either to drift
    /// from, so a package's verdict cannot depend on which entry point
    /// asked for it.
    ///
    /// A package carrying a `Lint.swift` is run through what CI runs,
    /// argument for argument: `swift-linter <package-root> --exit-policy
    /// strict`, with the prebuilt standard runner provisioned on the
    /// environment. The package root is passed absolute so the engine's
    /// summary line names the package rather than reporting `.`.
    ///
    /// ## The unconfigured package
    ///
    /// A package with no `Lint.swift` cannot go through the dispatcher
    /// at all: the dispatcher's whole job is to classify a consumer
    /// manifest, and with none present it falls through to a zero-rules
    /// configuration and exits clean having loaded nothing. So it is
    /// handed straight to the prebuilt standard runner, which bakes
    /// every published bundle and selects one from
    /// ``Workspace/Lint/Bundle/variable``. The runner takes lint targets
    /// and nothing else on its argument vector — a `--exit-policy` flag
    /// there would be read as a path — so the policy rides its own
    /// environment channel, which is the same terminal the dispatched
    /// executable reads.
    ///
    /// This path has no CI counterpart, because CI's activation signal
    /// is the presence of `Lint.swift` and these packages have none. It
    /// is Workspace's own measurement. The adjudicator does not know the
    /// difference and does not need to: a runner that loaded no rules,
    /// or found no files, is `unmeasured` here exactly as it would be
    /// there.
    ///
    /// - Parameter default: The bundle to lint an unconfigured package
    ///   with. `nil` means the caller could not determine one, and the
    ///   package is reported unmeasured rather than linted against a
    ///   guess.
    ///
    /// - Parameter fix: When non-`nil`, the run applies (or previews) the
    ///   canonical fixes rewriter-backed rules declare instead of reporting
    ///   findings. The engine reads the mode from its own environment
    ///   channel; ``Workspace/Lint/supportsFix(_:)`` is what keeps an older
    ///   installation — which ignores that channel and would lint silently
    ///   instead — from being handed the request at all.
    public func measure(
        _ target: Target,
        using installation: Installation,
        default bundle: Bundle?,
        fix: Fix? = nil,
        excluding excludedFixes: [Swift.String] = [],
        format: Format = .text
    ) -> Measurement {
        let package = target.package.description

        var environment = Environment.Snapshot.current()
        // Workspace's selection is authoritative even when the parent shell
        // carries a different token. Writing text too prevents an ambient
        // SARIF request from changing the ordinary developer-facing command.
        environment[Format.variable] = format.token
        var roots = [File.Directory]()
        if let fix {
            do throws(Workspace.Error) {
                roots = try target.roots()
            } catch {
                return .init(
                    package: package,
                    verdict: .unmeasured(
                        reason: "cannot resolve declared SwiftPM target roots for --fix: \(error)"
                    ),
                    summary: nil,
                    plan: nil,
                    findings: [],
                    diagnostics: "",
                    status: -1
                )
            }
            guard !roots.isEmpty else {
                return .init(
                    package: package,
                    verdict: .unmeasured(
                        reason: "--fix requires at least one declared SwiftPM target root"
                    ),
                    summary: nil,
                    plan: nil,
                    findings: [],
                    diagnostics: "",
                    status: -1
                )
            }
            environment[Workspace.Lint.Fix.variable] = fix.rawValue
            environment[Workspace.Lint.Fix.targetsVariable] = Workspace.Lint.Fix.targets(roots)
        }
        let executable: Swift.String
        var arguments: [Swift.String]
        if target.isConfigured {
            environment[Self.runnerVariable] = installation.runner.description
            executable = installation.executable.description
            arguments = [package, "--exit-policy", Self.exitPolicy]
            if format == .sarif {
                arguments += ["--format", format.token]
            }
            if let fix {
                arguments.append("--fix")
                if fix == .dryRun {
                    arguments.append("--dry-run")
                }
                arguments += roots.flatMap { ["--target-root", $0.description] }
                arguments += Fix.exclusionArguments(excludedFixes)
            }
        } else {
            guard let bundle else {
                let reason =
                    "no Lint.swift at \(package), and no default rule bundle could be resolved for it: "
                    + "the package does not sit under a layer root in \(hierarchy), so which rule set "
                    + "its peers use is not established. Linting it against a guessed bundle would "
                    + "publish a number nobody can interpret"
                return .init(
                    package: package,
                    verdict: .unmeasured(reason: reason),
                    summary: nil,
                    plan: nil,
                    findings: [],
                    diagnostics: "",
                    status: 0
                )
            }
            environment[Bundle.variable] = bundle.token
            environment[Self.policyVariable] = Self.exitPolicy
            executable = installation.runner.description
            arguments = [package]
            // The runner's argument vector is lint targets and nothing
            // else, so the exclusion must ride the environment here. The
            // dispatcher branch above is the opposite: in command-line
            // fix mode the engine reads only `--fix-excluding` and
            // silently ignores the exclusion channel, which on a
            // shadowed package would apply the exact rewrite the
            // exclusion exists to withhold.
            if fix != nil, !excludedFixes.isEmpty {
                environment[Workspace.Lint.Fix.exclusionsVariable] =
                    Workspace.Lint.Fix.exclusions(excludedFixes)
            }
        }

        let clock = ContinuousClock()
        let started = clock.now
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: arguments,
                    environment: environment.values,
                    stdout: .pipe,
                    stderr: .pipe,
                    workingDirectory: package
                )
            )
        } catch {
            return .init(
                package: package,
                verdict: .unmeasured(reason: "cannot execute swift-linter: \(error)"),
                summary: nil,
                plan: nil,
                findings: [],
                diagnostics: "\(error)",
                status: -1
            )
        }

        let elapsed = clock.now - started
        let standardOutput = Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
        let standardError = Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)

        switch output.status {
        case .exited(let code):
            var measurement = Self.adjudicate(
                package: package,
                status: code,
                standardOutput: standardOutput,
                standardError: standardError,
                fix: fix,
                format: format
            )
            measurement.duration = elapsed
            guard let file = target.file else { return measurement }
            return measurement.restricted(to: file)
        case .signaled(let signal):
            return .init(
                package: package,
                verdict: .unmeasured(reason: "swift-linter terminated by signal \(signal)"),
                summary: nil,
                plan: nil,
                findings: [],
                diagnostics: standardError,
                status: -1
            )
        case .stopped(let signal):
            return .init(
                package: package,
                verdict: .unmeasured(reason: "swift-linter stopped by signal \(signal)"),
                summary: nil,
                plan: nil,
                findings: [],
                diagnostics: standardError,
                status: -1
            )
        }
    }
}

extension Workspace.Lint {
    /// Reads a text file whole.
    static func read(_ file: File) throws(Workspace.Error) -> Swift.String {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try file.read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            throw .filesystem("cannot read \(file): \(error)")
        }
    }
}
