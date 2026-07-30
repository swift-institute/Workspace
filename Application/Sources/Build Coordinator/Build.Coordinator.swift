// Internal rather than private: `remove(_:after:)` is shared with the
// workspace operation in another file, and its parameter is a `File` type.
internal import File_System
private import Kernel_System
private import Kernel_Thread
internal import Process

extension Build {
    /// Runs SwiftPM operations with one owned interface and isolated evidence builds.
    public struct Coordinator: Sendable {
        /// How many compile jobs SwiftPM is given.
        ///
        /// Defaults to the machine's online processor count. Nothing else is
        /// competing for it: ``run(_:at:fresh:arguments:)`` holds a
        /// machine-wide exclusive lock across the whole compilation, so a
        /// coordinated build is the only coordinated build running. A cap
        /// below the core count therefore does not protect a second builder —
        /// there isn't one — it just leaves cores idle for the duration.
        public let jobs: Swift.Int

        /// The online processor count.
        ///
        /// Read from the machine rather than fixed, so a coordinated build
        /// neither under-uses a large host nor oversubscribes a small one.
        /// Same derivation as ``Workspace/Lint/Sweep/processors``.
        public static var processors: Swift.Int {
            Swift.Int(Kernel.Thread.Count(System.Processor.count))
        }

        public init(jobs: Swift.Int? = nil) {
            self.jobs = Swift.max(1, jobs ?? Self.processors)
        }
    }
}

extension Build.Coordinator {
    /// Runs one operation at a Swift package root.
    ///
    /// A fresh build or test uses a unique scratch directory and removes that
    /// generated state afterward. It never mutates `Package.resolved`.
    public func run(
        _ action: Build.Action,
        at path: Swift.String,
        fresh: Swift.Bool = false,
        arguments: [Swift.String] = []
    ) throws(Build.Error) -> Swift.Int32 {
        try run(action, at: path, fresh: fresh, arguments: arguments, capturingDiagnostics: false)
            .exitCode
    }

    /// Runs one operation at a Swift package root, optionally capturing the
    /// child's `stdout`/`stderr` so a caller can extract the first compiler
    /// diagnostic mechanically — the ecosystem coherence instrument's
    /// swiftpm-composed-root `build`-stage attribution, the SwiftPM analogue
    /// of ``run(_:fresh:arguments:capturingDiagnostics:)`` on the `xcodebuild`
    /// path.
    ///
    /// The plain ``run(_:at:fresh:arguments:)`` above stays the default for
    /// every interactive caller — streaming straight to the parent's own
    /// streams is the point of a potentially long-running build. A caller
    /// that needs the first diagnostic's text opts in here explicitly.
    public func run(
        _ action: Build.Action,
        at path: Swift.String,
        fresh: Swift.Bool = false,
        arguments: [Swift.String] = [],
        capturingDiagnostics: Swift.Bool
    ) throws(Build.Error) -> Build.Coordinator.Result {
        let candidate: File.Directory
        do throws(File.Path.Error) {
            candidate = try File.Directory(validating: path)
        } catch {
            throw .configuration("invalid package path \(path): \(error)")
        }
        guard candidate[file: "Package.swift"].stat.exists else {
            throw .configuration("no Package.swift at \(candidate)")
        }
        let package: File.Directory
        do throws(File.System.Canonical.Error) {
            package = File.Directory(try File.System.Canonical.resolve(candidate.path))
        } catch {
            throw .filesystem("cannot resolve package path \(candidate): \(error)")
        }
        guard !fresh || action.acceptsFreshScratch else {
            throw .configuration("--fresh is valid only with package build or test")
        }

        _ = try action.invocation(
            jobs: jobs,
            scratchPath: nil,
            arguments: arguments
        )
        let scratch = try freshScratch(for: action, package: package, enabled: fresh)
        let invocation = try action.invocation(
            jobs: jobs,
            scratchPath: scratch?.description,
            arguments: arguments
        )

        let output = try coordinated(
            invocation,
            in: package.description,
            describing: "\(action.rawValue) at \(package)",
            capture: capturingDiagnostics
        ) { failure in
            do throws(Build.Error) {
                try remove(scratch, after: failure)
                return failure
            } catch {
                return error
            }
        }
        return .init(
            exitCode: output.exitCode,
            standardOutput: capturingDiagnostics ? output.stdout : nil,
            standardError: capturingDiagnostics ? output.stderr : nil
        )
    }

    /// Internal rather than private so the workspace operation removes its
    /// fresh derived data through the same failure-folding path.
    func remove(
        _ scratch: File.Directory?,
        after failure: Build.Error?
    ) throws(Build.Error) {
        guard let scratch else { return }
        do throws(File.System.Delete.Error) {
            try scratch.delete.recursive()
        } catch {
            let message = "cannot remove fresh build state \(scratch): \(error)"
            throw failure.map {
                .filesystem("\($0); additionally, \(message)")
            } ?? .filesystem(message)
        }
    }

    private func freshScratch(
        for action: Build.Action,
        package: File.Directory,
        enabled: Swift.Bool
    ) throws(Build.Error) -> File.Directory? {
        guard enabled else { return nil }

        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: package.path,
                prefix: ".workspace-\(action.rawValue)-",
                suffix: ""
            )
        } catch {
            throw .filesystem("cannot allocate fresh build state beside \(package): \(error)")
        }

        let directory = File.Directory(path)
        do throws(File.System.Create.Directory.Error) {
            try directory.create.recursive()
        } catch {
            throw .filesystem("cannot create fresh build state \(directory): \(error)")
        }
        return directory
    }
}
