public import File_System

extension Workspace.Lint {
    /// One package's lint result, adjudicated.
    ///
    /// Constructed only by ``Workspace/Lint/measure(_:using:default:)``,
    /// so there is no path by which a caller can assemble a clean
    /// verdict out of a run that loaded no rules.
    public struct Measurement: Equatable, Sendable {
        /// The inventory coordinate, attached by the ecosystem sweep.
        ///
        /// Single-package mode has no inventory in scope and leaves this
        /// `nil`; ledger mode requires it for every measured repository.
        package var repository: Workspace.Repository.Key?

        /// The package root that was linted, as an absolute path.
        public let package: Swift.String

        /// The verdict, which is never `clean` without a summary line.
        public let verdict: Verdict

        /// The engine's summary, when it emitted one.
        public let summary: Summary?

        /// The exact safe rewrite plan, present only for a fix invocation.
        ///
        /// A non-empty fix result has no usable remediation value without
        /// rule-attributed sites, so fix-mode adjudication refuses a summary
        /// whose reported rewrite count cannot be matched to this plan.
        public let plan: Fix.Plan?

        /// Diagnostic lines the engine wrote to standard output.
        public let findings: [Swift.String]

        /// Structured, unsuppressed findings from swift-linter's SARIF reporter.
        ///
        /// `nil` means structured evidence was not requested or was not
        /// available. An empty array is a measured clean result.
        public let structured: [Finding]?

        /// The typed prerequisite blocking structured evidence, when known.
        ///
        /// This is deliberately independent of the human-readable verdict
        /// reason, so copy changes cannot alter machine state.
        public let prerequisite: Prerequisite?

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

        package init(
            repository: Workspace.Repository.Key? = nil,
            package: Swift.String,
            verdict: Verdict,
            summary: Summary?,
            plan: Fix.Plan?,
            findings: [Swift.String],
            structured: [Finding]? = nil,
            prerequisite: Prerequisite? = nil,
            diagnostics: Swift.String,
            status: Swift.Int32,
            duration: Duration = .zero
        ) {
            self.repository = repository
            self.package = package
            self.verdict = verdict
            self.summary = summary
            self.plan = plan
            self.findings = findings
            self.structured = structured
            self.prerequisite = prerequisite
            self.diagnostics = diagnostics
            self.status = status
            self.duration = duration
        }
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
    ///
    /// There was a fourth, `unconfigured`, for packages carrying no
    /// `Lint.swift`: not clean, not a failure, excused by a checked-in
    /// allowlist. It is gone. Such a package is now linted against the
    /// default ``Workspace/Lint/Bundle`` for its layer and lands in one
    /// of the three states below like any other, so there is no longer a
    /// state that means "we agreed not to look".
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
    }
}

extension Workspace.Lint.Measurement.Verdict {
    public var isUnmeasured: Swift.Bool {
        if case .unmeasured = self { true } else { false }
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
        }
    }

    public var text: Swift.String {
        switch self {
        case .clean: "clean"
        case .violations(let count, let failing):
            "\(count) violation\(count == 1 ? "" : "s")\(failing ? " (error severity)" : " (advisory)")"
        case .unmeasured(let reason): "UNMEASURED — \(reason)"
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
    ///   was never configured. This covers the file-path invocation and
    ///   the empty directory, both of which otherwise exit zero in total
    ///   silence — and it is the guard that would catch a default-bundle
    ///   run whose channel the runner ignored.
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
        standardError: Swift.String,
        fix: Fix? = nil,
        format: Format = .text
    ) -> Measurement {
        let summary = Summary.parse(standardError)
        let findings: [Swift.String] =
            format == .text
            ? standardOutput
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(Swift.String.init)
            : []

        guard let summary else {
            return .init(
                package: package,
                verdict: .unmeasured(
                    reason:
                        "the engine emitted no run summary, so no rules were loaded and no files "
                        + "were scanned; exit status \(status) attests only that a process ran"
                ),
                summary: nil,
                plan: nil,
                findings: findings,
                structured: nil,
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
                plan: nil,
                findings: findings,
                structured: nil,
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
                plan: nil,
                findings: findings,
                structured: nil,
                diagnostics: standardError,
                status: status
            )
        }

        let plan: Fix.Plan?
        if fix != nil {
            guard let parsed = Fix.Plan.parse(standardOutput, changes: summary.violations) else {
                return .init(
                    package: package,
                    verdict: .unmeasured(
                        reason: "the engine reported \(summary.violations) rewrite sites but did not "
                            + "publish one complete rule-attributed plan"
                    ),
                    summary: summary,
                    plan: nil,
                    findings: findings,
                    structured: nil,
                    diagnostics: standardError,
                    status: status
                )
            }
            plan = parsed
        } else {
            plan = nil
        }

        let structured: [Finding]?
        switch format {
        case .text:
            structured = nil
        case .sarif:
            do throws(Finding.Error) {
                let parsed = try Finding.parse(sarif: standardOutput)
                // The five-field summary's `findings` count is the SARIF
                // population like-for-like: `violations` deliberately
                // excludes note/remark severities that SARIF still
                // serializes, so comparing against it there is
                // apples-to-oranges (#104). Four-field engines carry no
                // `findings` count, so they fall back to the only total
                // they reported.
                let expected = summary.findings ?? summary.violations
                guard parsed.count == expected else {
                    return .init(
                        package: package,
                        verdict: .unmeasured(
                            reason:
                                "swift-linter reported \(expected) findings in its run "
                                + "summary but emitted \(parsed.count) SARIF results"
                        ),
                        summary: summary,
                        plan: plan,
                        findings: [],
                        structured: nil,
                        diagnostics: standardError,
                        status: status
                    )
                }
                let normalized = try parsed.map { (finding) throws(Finding.Error) in
                    try finding.relative(to: package)
                }
                let carriesError = normalized.contains(where: \.severity.isError)
                guard carriesError == (status != 0) else {
                    return .init(
                        package: package,
                        verdict: .unmeasured(
                            reason:
                                "swift-linter's strict exit status and SARIF error severities "
                                + "disagree"
                        ),
                        summary: summary,
                        plan: plan,
                        findings: [],
                        structured: nil,
                        diagnostics: standardError,
                        status: status
                    )
                }
                structured = normalized
            } catch {
                let prerequisite = Workspace.Lint.Prerequisite.sarif
                return .init(
                    package: package,
                    verdict: .unmeasured(
                        reason:
                            "structured findings are unavailable: \(error). "
                            + prerequisite.reason
                    ),
                    summary: summary,
                    plan: plan,
                    findings: [],
                    structured: nil,
                    prerequisite: prerequisite,
                    diagnostics: standardError,
                    status: status
                )
            }
        }

        let verdict: Measurement.Verdict =
            summary.violations == 0
            ? .clean
            : .violations(count: summary.violations, failing: status != 0)
        return .init(
            package: package,
            verdict: verdict,
            summary: summary,
            plan: plan,
            findings: findings,
            structured: structured,
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
            repository: repository,
            package: package,
            verdict: verdict,
            summary: summary,
            plan: plan,
            findings: findings.filter { $0.contains(needle) },
            structured: structured?.filter {
                needle.hasSuffix("/\($0.path)") || $0.path == needle
            },
            prerequisite: prerequisite,
            diagnostics: diagnostics,
            status: status
        )
        narrowed.duration = duration
        return narrowed
    }
}
