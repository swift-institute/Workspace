import Build_Coordinator
public import File_System
public import Git_Foundation

extension Workspace.Coherence {
    /// One coherence run over one selection.
    ///
    /// `sync`, `doctor`, and `build` are injected with real defaults —
    /// exactly ``Workspace/Doctor``'s `tool`/`environment` pattern — so a
    /// test can substitute a fake stage without a network reach or an
    /// Xcode install, while production always walks the real pipeline.
    public struct Run: Sendable {
        public let root: Workspace.Root
        public let configuration: Workspace.Configuration
        public let selection: Workspace.Selection.Resolved
        public let git: Git.Client

        /// The prior green receipt, if any — consulted only to diffuse
        /// `headsChangedSinceLastGreen` on an `incoherent` verdict. Receipt
        /// persistence itself is `swift-institute/.github`'s concern; this
        /// run never reads or writes one on its own.
        public let priorGreen: Receipt?

        /// Which build path measures the `graph` and `build` stages —
        /// Phase 1's `xcodebuild`-merged instrument by default, or Phase
        /// 2's `swiftpm-composed-root` (issue #81). Recorded verbatim into
        /// the receipt's `instrument.buildPath`.
        public let buildPath: Workspace.Coherence.BuildPath

        public let sync:
            @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error) -> Void
        public let doctor:
            @Sendable (Workspace.Root, Workspace.Configuration, Workspace.Selection.Resolved) async ->
                Workspace.Doctor.Report
        /// Re-renders and byte-compares the generated workspace/scheme
        /// against the current manifests, returning the expected built
        /// target count on success — the stale-scheme gate
        /// ``Workspace/Xcode/Build`` already performs, injectable so a test
        /// can substitute a count without a real `institute.xcworkspace`.
        public let graph:
            @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error) -> Swift.Int
        let build:
            @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error) ->
                Build_Coordinator.Build.Coordinator.Result

        init(
            root: Workspace.Root,
            configuration: Workspace.Configuration,
            selection: Workspace.Selection.Resolved,
            git: Git.Client = .init(),
            priorGreen: Receipt? = nil,
            buildPath: Workspace.Coherence.BuildPath = .xcodebuildMerged,
            sync: @escaping @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error)
                -> Void = Self.realSync,
            doctor: @escaping @Sendable (
                Workspace.Root, Workspace.Configuration, Workspace.Selection.Resolved
            ) async -> Workspace.Doctor.Report = Self.realDoctor,
            graph: (
                @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error) -> Swift.Int
            )? = nil,
            build: (
                @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error)
                    -> Build_Coordinator.Build.Coordinator.Result
            )? = nil
        ) {
            self.root = root
            self.configuration = configuration
            self.selection = selection
            self.git = git
            self.priorGreen = priorGreen
            self.buildPath = buildPath
            self.sync = sync
            self.doctor = doctor
            self.graph = graph ?? Self.realGraph(for: buildPath, swift: configuration.swift)
            self.build = build ?? Self.realBuild(for: buildPath)
        }
    }
}

extension Workspace.Coherence.Run {
    static func realSync(
        _ root: Workspace.Root,
        _ selection: Workspace.Selection.Resolved
    ) throws(Workspace.Error) {
        try Workspace.Sync(root: root, selection: selection).run(dry: false)
    }

    static func realDoctor(
        _ root: Workspace.Root,
        _ configuration: Workspace.Configuration,
        _ selection: Workspace.Selection.Resolved
    ) async -> Workspace.Doctor.Report {
        await Workspace.Doctor(
            root: root,
            configuration: configuration,
            selection: selection
        ).run(access: .contributor)
    }

    static func realGraph(
        _ root: Workspace.Root,
        _ selection: Workspace.Selection.Resolved
    ) throws(Workspace.Error) -> Swift.Int {
        let diagnostics = try Workspace.Xcode.Build(root: root, selection: selection).diagnostics()
        guard diagnostics.isEmpty else {
            throw .configuration(diagnostics.joined(separator: "\n"))
        }
        return try Workspace.Xcode.Scheme.buildables(for: selection.repositories, at: root).count
    }

    static func realBuild(
        _ root: Workspace.Root,
        _ selection: Workspace.Selection.Resolved
    ) throws(Workspace.Error) -> Build_Coordinator.Build.Coordinator.Result {
        try Workspace.Xcode.Build(root: root, selection: selection).run(
            fresh: false,
            arguments: [],
            capturingDiagnostics: true
        )
    }

    /// Generates the composed root fresh from the current selection's
    /// manifests and returns its reachable population — Phase 2's `graph`
    /// stage. There is no separate staleness gate here (unlike
    /// ``realGraph(_:_:)``'s scheme byte-compare): ``Composed/Root/write``
    /// regenerates the directory unconditionally, so the count it returns
    /// is always current for this run.
    static func realComposedGraph(
        swift: Swift.String
    ) -> @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error) -> Swift.Int {
        { root, selection in
            let manifests = try Workspace.Composed.manifests(for: selection.repositories, at: root)
            try Workspace.Composed.Root.write(manifests, swift: swift, at: root.checkout)
            return Workspace.Composed.Root.expectedTargetCount(in: manifests)
        }
    }

    static func realComposedBuild(
        _ root: Workspace.Root,
        _ selection: Workspace.Selection.Resolved
    ) throws(Workspace.Error) -> Build_Coordinator.Build.Coordinator.Result {
        try Workspace.Composed.Root.build(
            at: root.checkout,
            fresh: false,
            arguments: [],
            capturingDiagnostics: true
        )
    }

    /// Selects the real `graph` stage for `buildPath`, capturing `swift`
    /// (the declared tools-version floor) for the composed-root path's
    /// generated manifest header.
    static func realGraph(
        for buildPath: Workspace.Coherence.BuildPath,
        swift: Swift.String
    ) -> @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error) -> Swift.Int {
        switch buildPath {
        case .xcodebuildMerged: Self.realGraph
        case .swiftPMComposedRoot: Self.realComposedGraph(swift: swift)
        }
    }

    /// Selects the real `build` stage for `buildPath`.
    static func realBuild(
        for buildPath: Workspace.Coherence.BuildPath
    ) -> @Sendable (Workspace.Root, Workspace.Selection.Resolved) throws(Workspace.Error) ->
        Build_Coordinator.Build.Coordinator.Result
    {
        switch buildPath {
        case .xcodebuildMerged: Self.realBuild
        case .swiftPMComposedRoot: Self.realComposedBuild
        }
    }
}

extension Workspace.Coherence.Run {
    /// Walks every stage and returns the receipt — never throws, so a
    /// failure this instrument encounters becomes an entry in the receipt
    /// rather than a process failure with no comparable record.
    public func run() async -> Workspace.Coherence.Receipt {
        let clock = Swift.ContinuousClock()
        var stages: [Workspace.Coherence.StageResult] = [
            .init(stage: .bootstrap, outcome: .success, durationSeconds: 0)
        ]
        var attribution: Workspace.Coherence.Attribution?
        var proceed = true

        // sync
        if proceed {
            let started = clock.now
            do throws(Workspace.Error) {
                try sync(root, selection)
                stages.append(
                    .init(stage: .sync, outcome: .success, durationSeconds: Self.seconds(clock.now - started))
                )
            } catch {
                stages.append(
                    .init(stage: .sync, outcome: .failure, durationSeconds: Self.seconds(clock.now - started))
                )
                proceed = false
            }
        } else {
            stages.append(.init(stage: .sync, outcome: .notRun, durationSeconds: 0))
        }

        // doctor
        if proceed {
            let started = clock.now
            let report = await doctor(root, configuration, selection)
            let ok = report.status == 0
            stages.append(
                .init(
                    stage: .doctor,
                    outcome: ok ? .success : .failure,
                    durationSeconds: Self.seconds(clock.now - started)
                )
            )
            if !ok { proceed = false }
        } else {
            stages.append(.init(stage: .doctor, outcome: .notRun, durationSeconds: 0))
        }

        // graph
        var expectedTargetCount = 0
        if proceed {
            let started = clock.now
            do throws(Workspace.Error) {
                expectedTargetCount = try graph(root, selection)
                stages.append(
                    .init(
                        stage: .graph,
                        outcome: .success,
                        durationSeconds: Self.seconds(clock.now - started)
                    )
                )
            } catch {
                stages.append(
                    .init(
                        stage: .graph,
                        outcome: .failure,
                        durationSeconds: Self.seconds(clock.now - started)
                    )
                )
                proceed = false
            }
        } else {
            stages.append(.init(stage: .graph, outcome: .notRun, durationSeconds: 0))
        }

        // build
        var builtTargetCount = 0
        var buildSucceeded = false
        if proceed {
            let started = clock.now
            do throws(Workspace.Error) {
                let result = try build(root, selection)
                let elapsed = Self.seconds(clock.now - started)
                if result.exitCode == 0 {
                    buildSucceeded = true
                    builtTargetCount = expectedTargetCount
                    stages.append(.init(stage: .build, outcome: .success, durationSeconds: elapsed))
                } else {
                    stages.append(.init(stage: .build, outcome: .failure, durationSeconds: elapsed))
                    let diagnostic = Workspace.Coherence.firstDiagnostic(
                        standardOutput: result.standardOutput,
                        standardError: result.standardError
                    )
                    let repository = Workspace.Coherence.attribute(
                        diagnostic,
                        repositories: selection.repositories,
                        root: root
                    )
                    attribution = .init(
                        stage: .build,
                        package: repository?.name,
                        organization: repository?.organization,
                        layer: repository?.layer.rawValue,
                        firstDiagnostic: diagnostic,
                        headsChangedSinceLastGreen: []
                    )
                    proceed = false
                }
            } catch {
                // A thrown `Workspace.Error` here is the build coordinator
                // failing to invoke `xcodebuild` at all (a process or
                // filesystem defect) — not a compile diagnostic about the
                // graph. It carries no package attribution and is reported
                // as `unmeasured`, exactly like an earlier-stage failure,
                // rather than manufacturing a false `incoherent` verdict.
                stages.append(
                    .init(
                        stage: .build,
                        outcome: .failure,
                        durationSeconds: Self.seconds(clock.now - started)
                    )
                )
                proceed = false
            }
        } else {
            stages.append(.init(stage: .build, outcome: .notRun, durationSeconds: 0))
        }

        // population
        let inventoryCount = configuration.repositories.count
        let materializedCount = selection.repositories.count
        let canonical: Swift.Bool
        if case .committed = selection.origin { canonical = true } else { canonical = false }

        let population = Workspace.Coherence.Population(
            inventoryCount: inventoryCount,
            materializedCount: materializedCount,
            builtTargetCount: builtTargetCount,
            expectedTargetCount: expectedTargetCount
        )

        let verdict: Workspace.Coherence.Verdict
        if buildSucceeded {
            let coverageOK = !canonical || materializedCount == inventoryCount
            let targetsOK = builtTargetCount == expectedTargetCount
            if coverageOK, targetsOK {
                stages.append(.init(stage: .population, outcome: .success, durationSeconds: 0))
                verdict = .coherent
            } else {
                stages.append(.init(stage: .population, outcome: .failure, durationSeconds: 0))
                verdict = .unmeasured
            }
        } else {
            stages.append(.init(stage: .population, outcome: .notRun, durationSeconds: 0))
            verdict = attribution == nil ? .unmeasured : .incoherent
        }

        if let priorGreen, var completed = attribution {
            completed = .init(
                stage: completed.stage,
                package: completed.package,
                organization: completed.organization,
                layer: completed.layer,
                firstDiagnostic: completed.firstDiagnostic,
                headsChangedSinceLastGreen: Self.changedHeads(from: priorGreen.heads, to: heads())
            )
            attribution = completed
        }

        let selectionField = canonical ? "policy" : Self.narrowingDescription(selection.origin)
        return .init(
            instrument: .init(
                workspaceCommit: Self.line(
                    try? Workspace.Doctor.spawn(
                        "git",
                        arguments: ["-C", root.checkout.description, "rev-parse", "HEAD"]
                    )
                ),
                workspaceJsonBlob: Self.line(
                    try? Workspace.Doctor.spawn(
                        "git",
                        arguments: ["-C", root.checkout.description, "rev-parse", "HEAD:Institute.json"]
                    )
                ),
                selection: selectionField,
                buildPath: buildPath.rawValue
            ),
            environment: .init(
                platform: Self.currentPlatform,
                swift: configuration.swift,
                xcode: configuration.xcode,
                runner: Self.runnerDescription(),
                fresh: false,
                cachesUsed: []
            ),
            population: population,
            heads: stages.first(where: { $0.stage == .sync })?.outcome == .success ? heads() : [:],
            stages: stages,
            verdict: verdict,
            attribution: attribution,
            priorGreenReceipt: nil
        )
    }

    /// One "org/repository" → HEAD-of-`main` entry per selected repository
    /// whose materialized checkout is currently readable. Best-effort: a
    /// repository whose head cannot be read is omitted rather than failing
    /// the whole run — this map feeds attribution's head-diff, it does not
    /// gate the verdict.
    private func heads() -> [Swift.String: Swift.String] {
        var heads = [Swift.String: Swift.String]()
        for repository in selection.repositories {
            guard
                let directory = try? root.materialization(for: repository),
                let head = try? git.head("main", at: directory.description)
            else { continue }
            heads["\(repository.organization)/\(repository.name)"] = head.rawValue
        }
        return heads
    }

    private static func changedHeads(
        from previous: [Swift.String: Swift.String],
        to current: [Swift.String: Swift.String]
    ) -> [Swift.String] {
        var changed = [Swift.String]()
        for (identity, head) in current where previous[identity] != head {
            changed.append("\(identity)@\(head)")
        }
        return changed.sorted()
    }

    private static func narrowingDescription(_ origin: Workspace.Selection.Origin) -> Swift.String {
        "narrowed(+\(origin.added.count)/-\(origin.removed.count))"
    }

    /// `Workspace.Doctor.variable` rather than a direct `Environment.read`
    /// here: inside `extension Workspace.Coherence.Run` the unqualified
    /// name `Environment` resolves to ``Coherence/Environment`` (the
    /// receipt's own nested type) first, exactly the shadow
    /// `Workspace.Xcode.Scheme` documents for its own `Xcode` collision.
    /// Routing through the already-imported `Workspace.Doctor` avoids
    /// needing a module-qualified spelling of the swift-environment
    /// product here at all.
    private static func runnerDescription() -> Swift.String {
        Workspace.Doctor.variable("GITHUB_ACTIONS") != nil ? "github-hosted" : "local"
    }

    /// The platform this run actually measures on — literal `"macos"`
    /// under Phase 1 today, but the `swiftpm-composed-root` build path
    /// (issue #81) is Ubuntu-capable, so the receipt must not hardcode a
    /// single platform regardless of what compiled it.
    static var currentPlatform: Swift.String {
        #if os(macOS)
            "macos"
        #elseif os(Linux)
            "linux"
        #elseif os(Windows)
            "windows"
        #else
            "unknown"
        #endif
    }

    /// The first line of a spawned tool's output, or `"unknown"` when the
    /// interrogation itself failed — this metadata is descriptive, not
    /// gating, so a failure here must never fail the run.
    private static func line(_ value: Swift.String?) -> Swift.String {
        guard let value else { return "unknown" }
        return value.split(separator: "\n").first.map(Swift.String.init) ?? "unknown"
    }

    private static func seconds(_ duration: Swift.Duration) -> Swift.Double {
        let components = duration.components
        return Swift.Double(components.seconds) + Swift.Double(components.attoseconds) / 1e18
    }
}
