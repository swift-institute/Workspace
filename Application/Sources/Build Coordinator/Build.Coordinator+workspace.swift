private import File_System
internal import Process

extension Build.Coordinator {
    /// Runs one `xcodebuild` operation over a generated Xcode workspace.
    ///
    /// The whole selection compiles in this one process. That is the
    /// difference from ``Build/Coordinator/run(_:at:fresh:arguments:)``,
    /// which builds one package per invocation and, because the machine lock
    /// is held across the compilation, cannot overlap with another: N
    /// packages cost N serialized builds with an effective parallelism of one.
    ///
    /// Two distinct wins, worth separating because only one is about
    /// parallelism:
    ///
    /// - Xcode schedules every target in the merged graph against all cores.
    /// - The graph is merged, so a dependency shared by several selected
    ///   packages is compiled once. The serialized path gives each package
    ///   its own `.build` and so recompiles the shared closure once per
    ///   package.
    ///
    /// A `fresh` run builds into a unique derived-data directory beside the
    /// workspace and removes it afterward, mirroring the SwiftPM path's fresh
    /// scratch. It is the isolated-evidence build, not the fast one.
    public func run(
        _ workspace: Build.Workspace,
        fresh: Swift.Bool = false,
        arguments: [Swift.String] = []
    ) throws(Build.Error) -> Swift.Int32 {
        try run(
            workspace,
            fresh: fresh,
            arguments: arguments,
            capturingDiagnostics: false
        ).exitCode
    }

    /// Runs one `xcodebuild` operation, optionally capturing the child's
    /// `stdout`/`stderr` for mechanical failure attribution.
    ///
    /// The plain ``run(_:fresh:arguments:)`` above stays the default for
    /// every interactive caller — streaming straight to the parent's own
    /// streams is the point of a potentially multi-hour build. A caller
    /// that needs the first compiler diagnostic's text (the ecosystem
    /// coherence instrument's `build`-stage attribution, not human
    /// progress) opts in here explicitly.
    public func run(
        _ workspace: Build.Workspace,
        fresh: Swift.Bool,
        arguments: [Swift.String],
        capturingDiagnostics: Swift.Bool
    ) throws(Build.Error) -> Build.Coordinator.Result {
        let candidate: File.Directory
        do throws(File.Path.Error) {
            candidate = try File.Directory(validating: workspace.bundle)
        } catch {
            throw .configuration("invalid workspace path \(workspace.bundle): \(error)")
        }
        guard candidate[file: "contents.xcworkspacedata"].stat.exists else {
            throw .configuration("no contents.xcworkspacedata in \(candidate)")
        }
        let bundle: File.Directory
        do throws(File.System.Canonical.Error) {
            bundle = File.Directory(try File.System.Canonical.resolve(candidate.path))
        } catch {
            throw .filesystem("cannot resolve workspace path \(candidate): \(error)")
        }
        guard let parent = bundle.parent else {
            throw .configuration("workspace bundle has no containing directory: \(bundle)")
        }

        // Rejected before any directory is created, so an invalid argument
        // cannot leave fresh state behind. Same order as the SwiftPM path.
        var described = workspace
        described.bundle = bundle.description
        _ = try described.invocation(jobs: jobs, arguments: arguments)

        let derived = try freshDerivedData(for: bundle, enabled: fresh)
        if let derived {
            described.derivedDataPath = derived.description
        }
        let invocation = try described.invocation(jobs: jobs, arguments: arguments)

        let output = try coordinated(
            invocation,
            // The bundle's containing directory, because the workspace's
            // references are relative to it.
            in: parent.description,
            describing: "xcodebuild \(described.operation.rawValue) on \(bundle)",
            capture: capturingDiagnostics
        ) { failure in
            do throws(Build.Error) {
                try remove(derived, after: failure)
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

    private func freshDerivedData(
        for bundle: File.Directory,
        enabled: Swift.Bool
    ) throws(Build.Error) -> File.Directory? {
        guard enabled else { return nil }

        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: bundle.path,
                prefix: ".workspace-derived-data-",
                suffix: ""
            )
        } catch {
            throw .filesystem("cannot allocate fresh derived data beside \(bundle): \(error)")
        }

        let directory = File.Directory(path)
        do throws(File.System.Create.Directory.Error) {
            try directory.create.recursive()
        } catch {
            throw .filesystem("cannot create fresh derived data \(directory): \(error)")
        }
        return directory
    }
}
