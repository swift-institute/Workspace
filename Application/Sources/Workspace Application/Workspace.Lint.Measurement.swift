public import File_System

extension Workspace.Lint {
    /// One package's lint result, adjudicated.
    ///
    /// Constructed only by ``Workspace/Lint/measure(_:using:)``, so
    /// there is no path by which a caller can assemble a clean verdict
    /// out of an unconfigured run.
    public struct Measurement: Equatable, Sendable {
        /// The package root that was linted, as an absolute path.
        public let package: Swift.String

        /// The verdict, which is never `clean` without a summary line.
        public let verdict: Verdict

        /// The engine's summary, when it emitted one.
        public let summary: Summary?

        /// Diagnostic lines the engine wrote to standard output.
        public let findings: [Swift.String]

        /// Whatever the engine wrote to standard error, verbatim.
        ///
        /// Retained so an `unmeasured` verdict can show what the tool
        /// actually said rather than only that it said nothing useful.
        public let diagnostics: Swift.String

        /// The child process's exit status.
        public let status: Swift.Int32

        /// How long the invocation took.
        ///
        /// Recorded per package because the cost is not uniform: a
        /// consumer whose rule closure is exactly a baked bundle is
        /// linted by the prebuilt runner in seconds, while one the
        /// classifier cannot route compiles its declared rule packs
        /// first. Without this, a sweep that is slow for two packages
        /// looks like a sweep that is slow.
        public var duration: Duration = .zero
    }
}

extension Workspace.Lint.Measurement {
    /// What a run established.
    ///
    /// Three states, not two. `clean` and `violations` are both
    /// measurements; `unmeasured` is the absence of one, and it is
    /// deliberately not collapsible into either. A capability that
    /// reported "no violations found" for a run that loaded no rules
    /// would be the exact defect this type exists to make
    /// unrepresentable.
    public enum Verdict: Equatable, Sendable {
        /// Rules ran over files and found nothing.
        case clean

        /// Rules ran over files and found something. The run fails when
        /// any finding carries `error` severity, which the engine
        /// signals through its own exit status under `--exit-policy
        /// strict`.
        case violations(count: Swift.Int, failing: Swift.Bool)

        /// Nothing was established. Never reported as clean, in either
        /// mode, and never absorbed into a sweep aggregate.
        case unmeasured(reason: Swift.String)

        /// The package carries no lint configuration, and the sweep's
        /// allowlist records that as deliberate.
        ///
        /// Separate from both `clean` and `unmeasured` on purpose. It is
        /// not clean — nothing was measured — so it is never counted as
        /// coverage. It is not a failure either, because the gap is
        /// recorded and tracked rather than unnoticed. Collapsing it
        /// into `clean` would overstate coverage; collapsing it into
        /// `unmeasured` would make the sweep permanently red, and a gate
        /// that is always red gates nothing.
        ///
        /// Only ever produced by the sweep. The single-package path does
        /// not read the allowlist: asked to lint a package, "nothing
        /// here is configured" is a failure to deliver what was asked.
        case unconfigured(recorded: Swift.String)
    }
}

extension Workspace.Lint.Measurement.Verdict {
    public var isUnmeasured: Swift.Bool {
        if case .unmeasured = self { true } else { false }
    }

    public var isUnconfigured: Swift.Bool {
        if case .unconfigured = self { true } else { false }
    }

    /// Whether this verdict alone should fail the run.
    ///
    /// An unmeasured package fails. That is the point: a lint run that
    /// found nothing because it was pointed at the wrong directory must
    /// not be able to pass.
    public var fails: Swift.Bool {
        switch self {
        case .clean: false
        case .violations(_, let failing): failing
        case .unmeasured: true
        case .unconfigured: false
        }
    }

    public var text: Swift.String {
        switch self {
        case .clean: "clean"
        case .violations(let count, let failing):
            "\(count) violation\(count == 1 ? "" : "s")\(failing ? " (error severity)" : " (advisory)")"
        case .unmeasured(let reason): "UNMEASURED — \(reason)"
        case .unconfigured(let recorded):
            "no lint configuration — recorded in \(recorded); nothing was measured here"
        }
    }
}

extension Workspace.Lint {
    /// Adjudicates a completed invocation into a measurement.
    ///
    /// The three conditions below are the whole of the UNMEASURED
    /// guard, and each corresponds to a way the tool exits zero having
    /// established nothing:
    ///
    /// - **No summary line.** The engine emitted no run summary, so it
    ///   was never configured. This covers the file-path invocation, the
    ///   missing-`Lint.swift` invocation, and the empty directory — all
    ///   three of which otherwise exit zero in total silence.
    /// - **Zero active rules.** A configuration resolved but loaded no
    ///   rules. Nothing could have been found.
    /// - **Zero files linted.** Rules loaded but matched no source. A
    ///   clean verdict here would report on an empty population.
    ///
    /// A non-zero exit accompanied by a valid summary is a real
    /// finding, not an error: that is precisely what `--exit-policy
    /// strict` does when an `error`-severity rule fires.
    static func adjudicate(
        package: Swift.String,
        status: Swift.Int32,
        standardOutput: Swift.String,
        standardError: Swift.String
    ) -> Measurement {
        let summary = Summary.parse(standardError)
        let findings =
            standardOutput
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(Swift.String.init)

        guard let summary else {
            return .init(
                package: package,
                verdict: .unmeasured(
                    reason:
                        "the engine emitted no run summary, so no rules were loaded and no files "
                        + "were scanned; exit status \(status) attests only that a process ran"
                ),
                summary: nil,
                findings: findings,
                diagnostics: standardError,
                status: status
            )
        }
        guard summary.activeRules > 0 else {
            return .init(
                package: package,
                verdict: .unmeasured(
                    reason: "the engine loaded zero active rules, so nothing could be found"
                ),
                summary: summary,
                findings: findings,
                diagnostics: standardError,
                status: status
            )
        }
        guard summary.filesLinted > 0 else {
            return .init(
                package: package,
                verdict: .unmeasured(
                    reason:
                        "the engine matched zero source files, so \(summary.activeRules) rules "
                        + "ran over an empty population"
                ),
                summary: summary,
                findings: findings,
                diagnostics: standardError,
                status: status
            )
        }

        let verdict: Measurement.Verdict =
            summary.violations == 0
            ? .clean
            : .violations(count: summary.violations, failing: status != 0)
        return .init(
            package: package,
            verdict: verdict,
            summary: summary,
            findings: findings,
            diagnostics: standardError,
            status: status
        )
    }
}

extension Workspace.Lint.Measurement {
    /// The measurement restricted to findings naming `file`.
    ///
    /// Used by the single-file convenience: the enclosing package is
    /// linted whole — passing a file to the engine is a silent zero —
    /// and the diagnostic list is narrowed afterwards. The verdict is
    /// deliberately *not* recomputed: the package's result is the
    /// package's result, and a file with no findings inside a failing
    /// package has not been shown to be clean.
    public func restricted(to file: File.Path) -> Self {
        let needle = file.description
        var narrowed = Self(
            package: package,
            verdict: verdict,
            summary: summary,
            findings: findings.filter { $0.contains(needle) },
            diagnostics: diagnostics,
            status: status
        )
        narrowed.duration = duration
        return narrowed
    }
}
