public import File_System
import Build_Coordinator
public import Git_Foundation

extension Workspace.Verification {
    /// One verification run over one subject package: performs the
    /// requested operations against ``packagePath`` and seals a
    /// content-addressed ``Receipt`` (Task 2-01).
    ///
    /// **Why so many facts are caller-supplied rather than derived here.**
    /// A verification run must stay a fast, offline, credential-free leaf
    /// operation — Task 2-02's read-only verifier mints no write-capable
    /// token and must not need a live network reach to seal evidence. Every
    /// fact this run cannot establish by inspecting `packagePath` itself
    /// (its coordinate's visibility, its effective-inventory layer and
    /// digest, the pinned Workspace revision measuring it, the control
    /// plane's policy revision) is therefore a parameter, not a derivation:
    /// the control plane that already resolved those facts from the live
    /// effective inventory (0C-02) and its own pinned checkout supplies
    /// them, and this run never re-derives or invents one it was not
    /// given — the same discipline producer requirement 4 states for
    /// hosted image identity, applied to every caller-supplied fact.
    ///
    /// **What this run does establish itself:** the subject's observed
    /// head and working-tree cleanliness (``Git/Client``), the toolchain
    /// and host it is measuring on (``Environment/observe()``), and the
    /// result of every requested operation, by actually running it through
    /// ``Build/Coordinator`` (build, test, nested test packages) or
    /// ``Workspace/Lint`` (lint).
    ///
    /// Every real-tool interaction is injectable, exactly the
    /// ``Workspace/Coherence/Run`` and ``Workspace/Conversion/Seal``
    /// pattern: production always walks the real closures; a test
    /// substitutes a fake without a real package checkout.
    public struct Run: Sendable {
        public let packagePath: Swift.String
        public let claimedHead: Swift.String
        public let coordinate: Workspace.Repository.Key
        public let visibility: Workspace.Verification.Visibility
        public let visibilityReason: Swift.String?
        public let defaultBranch: Swift.String
        public let layer: Workspace.Layer
        public let inventoryDigest: Workspace.Verification.Inventory.Digest
        public let workspaceRevision: Swift.String
        public let policyRevision: Swift.String
        public let requestedOperations: [Operation.Kind]
        public let requiredOperations: [Operation.Kind]
        public let platformSupport: [Swift.String]
        public let fresh: Swift.Bool
        public let jobs: Swift.Int?
        public let arguments: [Swift.String]
        let tools: Tools

        /// The public entry point — always walks the real tool closures.
        /// `Tools` itself stays internal (it is only an injection seam for
        /// this module's own tests), so it cannot appear in a `public`
        /// initializer's signature; this forwards to the internal
        /// designated initializer with the real defaults.
        public init(
            packagePath: Swift.String,
            claimedHead: Swift.String,
            coordinate: Workspace.Repository.Key,
            visibility: Workspace.Verification.Visibility,
            visibilityReason: Swift.String? = nil,
            defaultBranch: Swift.String,
            layer: Workspace.Layer,
            inventoryDigest: Workspace.Verification.Inventory.Digest,
            workspaceRevision: Swift.String,
            policyRevision: Swift.String,
            requestedOperations: [Operation.Kind],
            requiredOperations: [Operation.Kind],
            platformSupport: [Swift.String] = [],
            fresh: Swift.Bool = false,
            jobs: Swift.Int? = nil,
            arguments: [Swift.String] = []
        ) {
            self.init(
                packagePath: packagePath,
                claimedHead: claimedHead,
                coordinate: coordinate,
                visibility: visibility,
                visibilityReason: visibilityReason,
                defaultBranch: defaultBranch,
                layer: layer,
                inventoryDigest: inventoryDigest,
                workspaceRevision: workspaceRevision,
                policyRevision: policyRevision,
                requestedOperations: requestedOperations,
                requiredOperations: requiredOperations,
                platformSupport: platformSupport,
                fresh: fresh,
                jobs: jobs,
                arguments: arguments,
                tools: Tools()
            )
        }

        /// The designated initializer — internal because ``Tools`` is
        /// internal. Exists so this module's own tests can substitute fake
        /// tool closures without a real package checkout.
        init(
            packagePath: Swift.String,
            claimedHead: Swift.String,
            coordinate: Workspace.Repository.Key,
            visibility: Workspace.Verification.Visibility,
            visibilityReason: Swift.String? = nil,
            defaultBranch: Swift.String,
            layer: Workspace.Layer,
            inventoryDigest: Workspace.Verification.Inventory.Digest,
            workspaceRevision: Swift.String,
            policyRevision: Swift.String,
            requestedOperations: [Operation.Kind],
            requiredOperations: [Operation.Kind],
            platformSupport: [Swift.String] = [],
            fresh: Swift.Bool = false,
            jobs: Swift.Int? = nil,
            arguments: [Swift.String] = [],
            tools: Tools
        ) {
            self.packagePath = packagePath
            self.claimedHead = claimedHead
            self.coordinate = coordinate
            self.visibility = visibility
            self.visibilityReason = visibilityReason
            self.defaultBranch = defaultBranch
            self.layer = layer
            self.inventoryDigest = inventoryDigest
            self.workspaceRevision = workspaceRevision
            self.policyRevision = policyRevision
            self.requestedOperations = requestedOperations
            self.requiredOperations = requiredOperations
            self.platformSupport = platformSupport
            self.fresh = fresh
            self.jobs = jobs
            self.arguments = arguments
            self.tools = tools
        }
    }
}

extension Workspace.Verification.Run {
    /// Every real-tool interaction ``Run`` performs, bundled as one
    /// injectable value instead of eight separate initializer parameters.
    ///
    /// Split out deliberately, not only for readability: a single
    /// initializer assigning sixteen plain facts and eight `@Sendable`
    /// closures (several with a `parameter ?? Self.realX` fallback) is
    /// exactly the shape that crashed `swift-frontend` during IR
    /// generation for `Run.init` on this toolchain — see the programme's
    /// `toolchain-defects.md`. Splitting the closure-bearing parameters
    /// into their own small type with its own defaults resolves the
    /// crash and is the better design independent of that: every real/fake
    /// pair now sits next to its sibling instead of spread across a
    /// twenty-three-parameter initializer.
    ///
    /// Production always uses the defaults (every real closure); a test
    /// substitutes only the ones it needs to fake, exactly the
    /// ``Workspace/Coherence/Run`` pattern applied one level down.
    struct Tools: Sendable {
        var head: @Sendable (Swift.String) throws(Workspace.Error) -> Swift.String
        var dirty: @Sendable (Swift.String) throws(Workspace.Error) -> Swift.Bool
        var build:
            @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
                Workspace.Verification.Operation.Result
        var test:
            @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
                Workspace.Verification.Operation.Result
        var nestedTests:
            @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
                [Workspace.Verification.Operation.Result]
        var lint: @Sendable (Swift.String) -> Workspace.Verification.Operation.Result
        var environment: @Sendable () -> Workspace.Verification.Environment
        var now: @Sendable () -> Swift.String

        init(
            head: @escaping @Sendable (Swift.String) throws(Workspace.Error) -> Swift.String =
                Workspace.Verification.Run.realHead,
            dirty: @escaping @Sendable (Swift.String) throws(Workspace.Error) -> Swift.Bool =
                Workspace.Verification.Run.realDirty,
            build: @escaping @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
                Workspace.Verification.Operation.Result = Workspace.Verification.Run.realBuild,
            test: @escaping @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
                Workspace.Verification.Operation.Result = Workspace.Verification.Run.realTest,
            nestedTests: @escaping @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
                [Workspace.Verification.Operation.Result] = Workspace.Verification.Run.realNestedTests,
            lint: @escaping @Sendable (Swift.String) -> Workspace.Verification.Operation.Result =
                Workspace.Verification.Run.realLint,
            environment: @escaping @Sendable () -> Workspace.Verification.Environment =
                Workspace.Verification.Environment.observe,
            now: @escaping @Sendable () -> Swift.String = Workspace.Verification.Run.realNow
        ) {
            self.head = head
            self.dirty = dirty
            self.build = build
            self.test = test
            self.nestedTests = nestedTests
            self.lint = lint
            self.environment = environment
            self.now = now
        }
    }
}

extension Workspace.Verification.Run {
    static func realHead(_ path: Swift.String) throws(Workspace.Error) -> Swift.String {
        do throws(Git.Client.Error) {
            return try Git.Client().head(at: path).rawValue
        } catch {
            throw .process("cannot read the subject HEAD at \(path): \(error)")
        }
    }

    static func realDirty(_ path: Swift.String) throws(Workspace.Error) -> Swift.Bool {
        do throws(Git.Client.Error) {
            return try !Git.Client().status(at: path).isEmpty
        } catch {
            throw .process("cannot read the subject working-tree status at \(path): \(error)")
        }
    }

    /// `date -u` rather than Foundation's `Date` — this module stays
    /// Foundation-free, and every other wall-clock-adjacent fact in it
    /// (``Workspace/Doctor/spawn``'s callers) already reaches the system
    /// through a spawned tool rather than a linked framework.
    static func realNow() -> Swift.String {
        (try? Workspace.Doctor.spawn("date", arguments: ["-u", "+%Y-%m-%dT%H:%M:%SZ"]))
            .map { $0.split(separator: "\n").first.map(Swift.String.init) ?? "unknown" } ?? "unknown"
    }
}

extension Workspace.Verification.Run {
    /// Runs one `Build.Action` at `path` and folds the coordinator's
    /// result into an ``Operation/Result``. Shared by ``realBuild``,
    /// ``realTest``, and each nested test package ``realNestedTests``
    /// discovers.
    static func run(
        _ operation: Workspace.Verification.Operation.Kind,
        action: Build.Action,
        at path: Swift.String,
        subpath: Swift.String?,
        fresh: Swift.Bool,
        jobs: Swift.Int?,
        arguments: [Swift.String],
        started: Swift.String,
        now: @Sendable () -> Swift.String
    ) -> Workspace.Verification.Operation.Result {
        let clock = Swift.ContinuousClock()
        let clockStart = clock.now
        let coordinator = Build.Coordinator(jobs: jobs)
        let outcome: Workspace.Verification.Operation.Outcome
        let exitCode: Swift.Int32?
        var compileEvidence: Swift.String?
        var testCounts: Workspace.Verification.Operation.TestCounts?
        do throws(Build.Error) {
            let result = try coordinator.run(
                action,
                at: path,
                fresh: fresh,
                arguments: arguments,
                capturingDiagnostics: true
            )
            exitCode = result.exitCode
            if result.exitCode == 0 {
                outcome = .success
                if action == .test {
                    testCounts = Self.parseTestCounts(
                        Swift.String(decoding: result.standardOutput ?? [], as: Swift.UTF8.self)
                    )
                }
            } else {
                outcome = .failure
                compileEvidence = Workspace.Coherence.firstDiagnostic(
                    standardOutput: result.standardOutput,
                    standardError: result.standardError
                )
            }
        } catch {
            exitCode = nil
            outcome = .unmeasured(reason: "the build coordinator could not run \(action.rawValue): \(error)")
        }
        return .init(
            operation: operation,
            subpath: subpath,
            arguments: arguments,
            startedAt: started,
            endedAt: now(),
            durationSeconds: Self.seconds(clock.now - clockStart),
            exitCode: exitCode,
            provenance: fresh ? .fresh : .cached,
            outcome: outcome,
            compileEvidence: compileEvidence,
            testCounts: testCounts,
            findings: []
        )
    }

    /// The same `Duration` → seconds reduction
    /// ``Workspace/Coherence/Run/seconds(_:)`` uses.
    static func seconds(_ duration: Swift.Duration) -> Swift.Double {
        let components = duration.components
        return Swift.Double(components.seconds) + Swift.Double(components.attoseconds) / 1e18
    }

    static func realBuild(
        _ path: Swift.String,
        _ fresh: Swift.Bool,
        _ jobs: Swift.Int?,
        _ arguments: [Swift.String]
    ) -> Workspace.Verification.Operation.Result {
        Self.run(
            .build,
            action: .build,
            at: path,
            subpath: nil,
            fresh: fresh,
            jobs: jobs,
            arguments: arguments,
            started: Self.realNow(),
            now: Self.realNow
        )
    }

    static func realTest(
        _ path: Swift.String,
        _ fresh: Swift.Bool,
        _ jobs: Swift.Int?,
        _ arguments: [Swift.String]
    ) -> Workspace.Verification.Operation.Result {
        Self.run(
            .test,
            action: .test,
            at: path,
            subpath: nil,
            fresh: fresh,
            jobs: jobs,
            arguments: arguments,
            started: Self.realNow(),
            now: Self.realNow
        )
    }

    /// A best-effort parse of `swift test`'s final summary line, in either
    /// shape this ecosystem's targets can emit: XCTest's `Executed N
    /// tests, with F failures …`, or Swift Testing's `Test run with N
    /// tests in M suites passed/failed after T seconds …`. Returns `nil`
    /// — never a guessed count — whenever a line matches one shape's
    /// opening words but not its exact number-bearing tokens, exactly the
    /// discipline ``Workspace/Lint/Summary/parse(_:)`` already applies to
    /// swift-linter's own run summary.
    static func parseTestCounts(
        _ output: Swift.String
    ) -> Workspace.Verification.Operation.TestCounts? {
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            if let counts = Self.parseXCTestSummary(line) { return counts }
            if let counts = Self.parseSwiftTestingSummary(line) { return counts }
        }
        return nil
    }

    /// `Executed 5 tests, with 0 failures (0 unexpected) in 0.012 (0.014)
    /// seconds`.
    private static func parseXCTestSummary(
        _ line: Swift.Substring
    ) -> Workspace.Verification.Operation.TestCounts? {
        guard line.contains("Executed"), line.contains("test") else { return nil }
        let tokens = line.split(separator: " ")
        guard
            let executedIndex = tokens.firstIndex(of: "Executed"),
            executedIndex + 1 < tokens.count,
            let executed = Swift.Int(tokens[executedIndex + 1]),
            let withIndex = tokens.firstIndex(of: "with"),
            withIndex + 1 < tokens.count,
            let failed = Swift.Int(tokens[withIndex + 1])
        else { return nil }
        return .init(executed: executed, passed: executed - failed, failed: failed)
    }

    /// `Test run with 5 tests in 2 suites passed after 0.012 seconds.` or
    /// `… failed after 0.012 seconds with 2 issues (including 1 known
    /// issue).` — the executed count sits right after the first `with`;
    /// the failure count, when the run failed, sits right after the
    /// second. A `passed` line with no second `with` is 0 failures by
    /// construction, never a guess.
    private static func parseSwiftTestingSummary(
        _ line: Swift.Substring
    ) -> Workspace.Verification.Operation.TestCounts? {
        guard line.hasPrefix("Test run with"), line.contains("test") else { return nil }
        let tokens = line.split(separator: " ")
        guard
            let firstWith = tokens.firstIndex(of: "with"),
            firstWith + 1 < tokens.count,
            let executed = Swift.Int(tokens[firstWith + 1])
        else { return nil }
        if line.contains(" passed ") {
            return .init(executed: executed, passed: executed, failed: 0)
        }
        guard
            line.contains(" failed "),
            let secondWith = tokens[(firstWith + 1)...].firstIndex(of: "with"),
            secondWith + 1 < tokens.count,
            let failed = Swift.Int(tokens[secondWith + 1])
        else { return nil }
        return .init(executed: executed, passed: executed - failed, failed: failed)
    }
}

extension Workspace.Verification.Run {
    /// Discovers every nested test package under `Tests/` — a `Package.swift`
    /// one level below `Tests/`, the shape the testing skill documents for a
    /// snapshot suite needing a third-party test dependency the main
    /// manifest does not carry — and runs `swift test` in each. An absent
    /// `Tests/` directory or one containing no nested manifest is not an
    /// error: it means this subject has none, which
    /// ``Workspace/Verification/Run/run()`` records as `notApplicable`
    /// when nothing is returned here.
    static func realNestedTests(
        _ path: Swift.String,
        _ fresh: Swift.Bool,
        _ jobs: Swift.Int?,
        _ arguments: [Swift.String]
    ) -> [Workspace.Verification.Operation.Result] {
        guard let testsComponent = try? File.Path.Component("Tests") else { return [] }
        let root: File.Directory
        do throws(File.Path.Error) {
            root = try File.Directory(validating: path)
        } catch {
            return []
        }
        let tests = root[directory: testsComponent]
        guard File(tests.path).stat.isDirectory else { return [] }

        let entries: [File.Directory.Entry]
        do throws(File.Directory.Contents.Error) {
            entries = try File.Directory.Contents.list(at: tests)
        } catch {
            return []
        }

        var results: [Workspace.Verification.Operation.Result] = []
        for entry in entries where entry.type == .directory {
            guard let name = Swift.String(entry.name), let component = try? File.Path.Component(name)
            else { continue }
            let nested = tests[directory: component]
            guard nested[file: "Package.swift"].stat.exists else { continue }
            results.append(
                Self.run(
                    .nestedTests,
                    action: .test,
                    at: nested.description,
                    subpath: "Tests/\(name)",
                    fresh: fresh,
                    jobs: jobs,
                    arguments: arguments,
                    started: Self.realNow(),
                    now: Self.realNow
                )
            )
        }
        return results
    }
}

extension Workspace.Verification.Run {
    /// Runs the same per-package lint gate `institute package lint`
    /// already performs (``Workspace/CLI/run()``'s `.package`/`.lint`
    /// branch), folded into an ``Operation/Result``.
    static func realLint(_ path: Swift.String) -> Workspace.Verification.Operation.Result {
        let started = Self.realNow()
        // Each stage is caught separately so the sealed reason can name
        // *which* stage refused. The old single `catch` interpolated the
        // error's captured message to get that detail, and the message
        // routinely quotes this machine's filesystem — see `Refusal`.
        let target: Workspace.Lint.Target
        do throws(Workspace.Error) {
            target = try Workspace.Lint.Target.resolve(path)
        } catch {
            return Self.refusedLint(.unresolvableTarget(error.kind), started: started)
        }
        let lint: Workspace.Lint
        do throws(Workspace.Error) {
            lint = try Workspace.Lint.resolve(from: target.package.description)
        } catch {
            return Self.refusedLint(.unresolvableConfiguration(error.kind), started: started)
        }
        let installation: Workspace.Lint.Installation
        do throws(Workspace.Error) {
            installation = try lint.installation()
        } catch {
            return Self.refusedLint(.unavailableInstallation(error.kind), started: started)
        }
        let measurement = lint.measure(
            target,
            using: installation,
            default: Workspace.Lint.Bundle.resolve(target.package, under: lint.hierarchy),
            fix: nil
        )
        let outcome: Workspace.Verification.Operation.Outcome
        switch measurement.verdict {
        case .clean:
            outcome = .success
        case .violations(_, let failing):
            outcome = failing ? .failure : .success
        case .unmeasured(let reason):
            // The engine's own unmeasured reasons quote the package and
            // hierarchy paths it was given (see `Workspace.Lint.Run`'s
            // no-bundle branch), so the reason is relativized first and
            // withheld entirely if anything unsealable survives.
            let relative = Workspace.Verification.Redaction.relative(reason, to: path)
            outcome =
                Workspace.Verification.Redaction.diagnose(relative) == nil
                ? .unmeasured(reason: relative)
                : .unmeasured(reason: Refusal.unsealableMeasurementReason.description)
        }
        return .init(
            operation: .lint,
            arguments: [],
            startedAt: started,
            endedAt: Self.realNow(),
            durationSeconds: Self.seconds(measurement.duration),
            exitCode: measurement.status,
            provenance: .cached,
            outcome: outcome,
            // swift-linter reports the files it was pointed at, which on a
            // hosted runner means an absolute path per finding — content
            // `run()` refuses to seal. Relativizing here keeps the finding
            // whole and makes the lint leg sealable at all; a finding that
            // still names some *other* absolute path is left to that
            // refusal, deliberately.
            // Relativized centrally in `run()`, with every other leg.
            findings: Swift.Array(measurement.findings.prefix(50))
        )
    }

    /// One leak-safe unmeasured lint result — the shape every refusal
    /// stage in ``realLint(_:)`` returns.
    private static func refusedLint(
        _ refusal: Refusal,
        started: Swift.String
    ) -> Workspace.Verification.Operation.Result {
        .init(
            operation: .lint,
            arguments: [],
            startedAt: started,
            endedAt: Self.realNow(),
            durationSeconds: 0,
            exitCode: nil,
            provenance: .cached,
            outcome: .unmeasured(reason: refusal.description),
            findings: []
        )
    }
}

extension Workspace.Verification.Run {
    /// Performs every requested operation and seals a ``Receipt`` — or
    /// refuses with a typed ``Error`` when this run cannot honestly claim
    /// to have verified the subject. See ``Error`` for exactly which
    /// conditions refuse rather than seal an ``Verdict/unverified``
    /// receipt, and why the distinction matters.
    public func run() throws(Workspace.Verification.Error) -> Workspace.Verification.Receipt {
        let observedHead: Swift.String
        let isDirty: Swift.Bool
        do throws(Workspace.Error) {
            observedHead = try tools.head(packagePath)
            isDirty = try tools.dirty(packagePath)
        } catch {
            throw .subject("\(error)")
        }
        guard observedHead == claimedHead else {
            throw .headMismatch(claimed: claimedHead, observed: observedHead)
        }
        guard !isDirty else {
            throw .dirtySubject(packagePath)
        }

        var results: [Workspace.Verification.Operation.Result] = []
        for kind in requestedOperations {
            switch kind {
            case .build:
                results.append(tools.build(packagePath, fresh, jobs, arguments))
            case .test:
                results.append(tools.test(packagePath, fresh, jobs, arguments))
            case .nestedTests:
                let nested = tools.nestedTests(packagePath, fresh, jobs, arguments)
                if nested.isEmpty {
                    results.append(
                        .init(
                            operation: .nestedTests,
                            arguments: [],
                            startedAt: tools.now(),
                            endedAt: tools.now(),
                            durationSeconds: 0,
                            exitCode: nil,
                            provenance: fresh ? .fresh : .cached,
                            outcome: .notApplicable(reason: "no nested test package under Tests/"),
                            findings: []
                        )
                    )
                } else {
                    results.append(contentsOf: nested)
                }
            case .lint:
                results.append(tools.lint(packagePath))
            }
        }

        guard results.contains(where: { $0.outcome.isExecuted }) else {
            throw .noOperationExecuted
        }

        var gates: [Workspace.Verification.Gate] = []
        for required in requiredOperations {
            let matches = results.filter { $0.operation == required }
            guard !matches.isEmpty else {
                throw .requiredOperationMissing(required)
            }
            guard matches.allSatisfy({ $0.outcome.isExecuted }) else {
                throw .requiredOperationNotExecuted(required)
            }
            gates.append(
                .init(
                    name: required.rawValue,
                    satisfied: matches.allSatisfy { $0.outcome.isSatisfying }
                )
            )
        }

        // One place, every leg: captured tool output names the subject by
        // the absolute path the tool was pointed at, and the boundary
        // below refuses exactly that. Rewriting it here — not in each
        // producer — is what keeps the rule a property of the boundary.
        results = results.map { $0.relative(to: packagePath) }

        for result in results {
            if let evidence = result.compileEvidence,
                let reason = Workspace.Verification.Redaction.diagnose(evidence)
            {
                throw .unsafeContent("operation \(result.operation.rawValue) compile evidence \(reason)")
            }
            for finding in result.findings {
                if let reason = Workspace.Verification.Redaction.diagnose(finding) {
                    throw .unsafeContent("operation \(result.operation.rawValue) finding \(reason)")
                }
            }
        }

        let verdict: Workspace.Verification.Verdict
        if gates.allSatisfy(\.satisfied), results.allSatisfy({ $0.outcome.isSatisfying }) {
            verdict = .verified
        } else {
            verdict = .unverified(
                reason: "one or more executed operations did not reach a satisfying outcome"
            )
        }

        return Workspace.Verification.Receipt(
            subject: .init(
                coordinate: coordinate,
                visibility: visibility,
                visibilityReason: visibilityReason,
                defaultBranch: defaultBranch,
                claimedHead: claimedHead,
                observedHead: observedHead,
                dirty: isDirty
            ),
            inventoryDigest: inventoryDigest,
            layer: layer,
            workspaceRevision: workspaceRevision,
            policyRevision: policyRevision,
            environment: tools.environment(),
            requestedOperations: requestedOperations,
            operations: results,
            platform: .init(
                declared: platformSupport,
                measured: Workspace.Verification.Environment.currentOS
            ),
            requiredGates: gates,
            verdict: verdict
        )
    }
}
