private import Build_Coordinator
public import File_System

extension Workspace.Xcode {
    /// Builds the whole selection in one `xcodebuild` invocation, through the
    /// generated `institute.xcworkspace`.
    ///
    /// The alternative this replaces is N invocations of
    /// `workspace package build`, one per selected package. Those cannot
    /// overlap: the build coordinator holds a machine-wide exclusive lock
    /// across the whole compilation, so the effective parallelism of a
    /// multi-package sweep is one, whatever `jobs` says. They also do not
    /// share work — each package gets its own `.build`, so a dependency
    /// common to several selected packages is compiled once per package.
    ///
    /// And they build the wrong sources. `swift build` resolves a package's
    /// dependencies from pinned remotes: change a selected package on disk
    /// and a consumer's `swift build` will compile the published version and
    /// report success. The workspace resolves its members from local paths,
    /// so this is the only path that builds the institute from the working
    /// copy. That, not speed, is the reason it exists.
    ///
    /// The scheme covers the selected repositories only. `Application` is a
    /// reference in the workspace document so the tool is editable beside the
    /// packages, but it is Workspace's own executable rather than an
    /// inventory package, and `swift build --package-path Application` is
    /// what builds it. Putting it in the scheme would make every selection
    /// build rebuild the tool that launched it.
    public struct Build: Sendable {
        public let root: Workspace.Root
        public let selection: Workspace.Selection.Resolved

        public init(root: Workspace.Root, selection: Workspace.Selection.Resolved) {
            self.root = root
            self.selection = selection
        }
    }
}

extension Workspace.Xcode.Build {
    public var bundle: File.Directory {
        root.checkout[directory: "institute.xcworkspace"]
    }

    /// Everything that must agree before a build can mean anything, or the
    /// reasons it does not.
    ///
    /// Both generated documents are re-rendered from their current sources
    /// and byte-compared. Staleness is refused rather than repaired: `sync`
    /// owns generation, and a build command that quietly regenerated its own
    /// inputs would be reporting on a workspace nobody asked for.
    ///
    /// The scheme check is the load-bearing one. `xcodebuild` silently drops
    /// a `BuildableReference` whose blueprint matches no target in its
    /// container — measured on this machine: one fabricated entry among valid
    /// ones exits 0 and prints `** BUILD SUCCEEDED **` having never built
    /// that package; only an entirely unmatched scheme fails, with exit 66.
    /// A manifest that renamed a target since the last `sync` therefore does
    /// not break the build, it shrinks it, and the shrunken build still looks
    /// green. Comparing the rendered scheme against the manifests before
    /// building is what makes that reachable.
    public func diagnostics() throws(Workspace.Error) -> [Swift.String] {
        try preflight().diagnostics
    }

    /// The manifest read is one `swift package dump-package` per selected
    /// repository, so it happens once per command and both the gate and the
    /// reported target count are derived from that single read.
    private func preflight() throws(Workspace.Error) -> (
        buildables: [Workspace.Xcode.Scheme.Buildable],
        diagnostics: [Swift.String]
    ) {
        guard bundle[file: "contents.xcworkspacedata"].stat.exists else {
            return ([], ["institute.xcworkspace is not generated; run `workspace sync`"])
        }

        var diagnostics = [Swift.String]()
        if !Workspace.Xcode.current(selection.repositories, at: root.checkout) {
            diagnostics.append(
                "institute.xcworkspace does not match the resolved selection; run `workspace sync`"
            )
        }

        let buildables = try Workspace.Xcode.Scheme.buildables(
            for: selection.repositories,
            at: root
        )
        if !Workspace.Xcode.Scheme.current(buildables, at: root.checkout) {
            diagnostics.append(
                "\(Workspace.Xcode.Scheme.name).xcscheme does not match the selected packages'"
                    + " manifests (\(buildables.count) buildable targets); run `workspace sync`."
                    + " An out-of-date scheme does not fail the build — it silently builds less"
                    + " of the selection."
            )
        }
        return (buildables, diagnostics)
    }

    /// Runs the build and returns `xcodebuild`'s exit status.
    public func run(
        fresh: Swift.Bool,
        arguments: [Swift.String]
    ) throws(Workspace.Error) -> Swift.Int32 {
        try run(fresh: fresh, arguments: arguments, capturingDiagnostics: false).exitCode
    }

    /// Runs the build, optionally capturing `xcodebuild`'s `stdout`/`stderr`
    /// so a caller can extract the first compiler diagnostic mechanically —
    /// the ecosystem coherence instrument's `build`-stage attribution.
    public func run(
        fresh: Swift.Bool,
        arguments: [Swift.String],
        capturingDiagnostics: Swift.Bool
    ) throws(Workspace.Error) -> Build_Coordinator.Build.Coordinator.Result {
        let preflight = try preflight()
        guard preflight.diagnostics.isEmpty else {
            throw .configuration(preflight.diagnostics.joined(separator: "\n"))
        }
        print(
            "build: \(selection.repositories.count) packages,"
                + " \(preflight.buildables.count) targets, one xcodebuild invocation"
        )

        let operation = Build_Coordinator.Build.Workspace(
            bundle: bundle.description,
            scheme: Workspace.Xcode.Scheme.name
        )
        do throws(Build_Coordinator.Build.Error) {
            return try Build_Coordinator.Build.Coordinator().run(
                operation,
                fresh: fresh,
                arguments: arguments,
                capturingDiagnostics: capturingDiagnostics
            )
        } catch {
            throw .process("\(error)")
        }
    }
}
