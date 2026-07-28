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
    /// ``Workspace/Lint/divergence()``, which `workspace lint check` and
    /// `workspace doctor` call. Putting a network round trip on the
    /// inner loop would make the fast path slow, and the fast path being
    /// fast is what decides whether any of this gets used.
    public func installation() throws(Workspace.Error) -> Installation {
        guard manifestFile.stat.isFile else {
            throw .configuration(
                "swift-linter is not installed; run `workspace lint install`"
            )
        }
        let manifest = try installedManifest()
        let executable = try executable(for: manifest)
        let runner = try runner(for: manifest)
        guard executable.stat.isFile else {
            throw .configuration(
                "installed manifest records digest \(manifest.digest) but \(executable) is missing; "
                    + "run `workspace lint install`"
            )
        }
        guard runner.stat.isFile else {
            throw .configuration(
                "installed manifest records digest \(manifest.digest) but \(runner) is missing; "
                    + "run `workspace lint install`"
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
    /// The invocation is what CI runs, argument for argument:
    /// `swift-linter <package-root> --exit-policy strict`, with the
    /// prebuilt standard runner provisioned on the environment. The
    /// package root is passed absolute so the engine's summary line
    /// names the package rather than reporting `.`.
    public func measure(
        _ target: Target,
        using installation: Installation,
        recordedUnconfigured: Swift.String? = nil
    ) -> Measurement {
        let package = target.package.description

        guard target.isConfigured else {
            if let recordedUnconfigured {
                return .init(
                    package: package,
                    verdict: .unconfigured(recorded: recordedUnconfigured),
                    summary: nil,
                    findings: [],
                    diagnostics: "",
                    status: 0
                )
            }
            return .init(
                package: package,
                verdict: .unmeasured(
                    reason:
                        "no Lint.swift at \(package); the engine's activation signal is absent, so "
                        + "a run here would load zero rules and exit clean having measured nothing"
                ),
                summary: nil,
                findings: [],
                diagnostics: "",
                status: 0
            )
        }

        var environment = Environment.Snapshot.current()
        environment[Self.runnerVariable] = installation.runner.description

        let clock = ContinuousClock()
        let started = clock.now
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: installation.executable.description,
                    arguments: [package, "--exit-policy", Self.exitPolicy],
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
                standardError: standardError
            )
            measurement.duration = elapsed
            guard let file = target.file else { return measurement }
            return measurement.restricted(to: file)
        case .signaled(let signal):
            return .init(
                package: package,
                verdict: .unmeasured(reason: "swift-linter terminated by signal \(signal)"),
                summary: nil,
                findings: [],
                diagnostics: standardError,
                status: -1
            )
        case .stopped(let signal):
            return .init(
                package: package,
                verdict: .unmeasured(reason: "swift-linter stopped by signal \(signal)"),
                summary: nil,
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
