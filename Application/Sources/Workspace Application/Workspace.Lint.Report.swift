extension Workspace.Lint {
    /// The result of one sweep, and the exit status it implies.
    ///
    /// Three tallies rather than two. A sweep that reported only
    /// "packages" and "violations" would have nowhere to put a package
    /// it failed to measure, and anything without a place to go gets
    /// absorbed into the clean count.
    ///
    /// There was a fourth — packages recorded as deliberately carrying
    /// no lint configuration — and it is gone with the allowlist that
    /// fed it. Every materialized package is now measured, so the only
    /// reason a package is missing from the coverage count is that
    /// measuring it failed.
    public struct Report: Sendable {
        public let scope: Sweep.Scope

        /// Packages in `Institute.json`.
        public let inventory: Swift.Int

        /// Inventory entries with no package on disk.
        ///
        /// Reported by name rather than counted: a sweep that covers
        /// fewer packages than the inventory holds must say which ones
        /// it did not reach.
        public let unmaterialized: [Swift.String]

        /// Materialized packages the scope filter chose from.
        public let considered: Swift.Int

        /// One measurement per package actually linted.
        public let measurements: [Measurement]

        /// The requested rewrite mode, if this was a fix sweep.
        public let fix: Fix?

        /// Packages whose shadow risk excluded PLAT-ARCH-022 from `--fix`, and why.
        ///
        /// Empty on every read-only sweep — there is no fixer to exclude
        /// from a run that writes nothing — and never folded into the
        /// tallies above. The package is still measured and may receive
        /// every other safe canonical fix; the named exclusion is reported
        /// with its declaring site rather than hidden in a package count.
        ///
        /// It does not fail the run. The gate is the safe outcome, not an
        /// error: a fleet fix that exited non-zero because it correctly
        /// declined to retarget 141 packages' references would be a gate
        /// nobody could leave switched on.
        public let excluded: [Shadow.Exclusion]

        public init(
            scope: Sweep.Scope,
            inventory: Swift.Int,
            unmaterialized: [Swift.String],
            considered: Swift.Int,
            measurements: [Measurement],
            fix: Fix? = nil,
            excluded: [Shadow.Exclusion] = []
        ) {
            self.scope = scope
            self.inventory = inventory
            self.unmaterialized = unmaterialized
            self.considered = considered
            self.measurements = measurements
            self.fix = fix
            self.excluded = excluded
        }
    }
}

extension Workspace.Lint.Report {
    public var clean: [Workspace.Lint.Measurement] {
        measurements.filter { $0.verdict == .clean }
    }

    public var violations: [Workspace.Lint.Measurement] {
        measurements.filter {
            if case .violations = $0.verdict { true } else { false }
        }
    }

    public var unmeasured: [Workspace.Lint.Measurement] {
        measurements.filter(\.verdict.isUnmeasured)
    }

    /// Source files the sweep actually visited.
    ///
    /// The other half of the positive control, at sweep scale: a sweep
    /// reporting hundreds of clean packages and a handful of files
    /// scanned has measured almost nothing, and this number is what
    /// makes that visible.
    public var filesLinted: Swift.Int {
        measurements.reduce(0) { $0 + ($1.summary?.filesLinted ?? 0) }
    }

    /// Total time spent inside the engine, summed across packages.
    ///
    /// Larger than wall clock whenever the sweep ran in parallel; the
    /// ratio between the two is what says whether the parallelism paid.
    public var engineTime: Duration {
        measurements.reduce(.zero) { $0 + $1.duration }
    }

    /// Every package that took measurable time, slowest first.
    ///
    /// A sweep whose total is driven by a handful of packages is a
    /// different problem from one that is uniformly slow, and an
    /// aggregate alone cannot tell them apart. In this ecosystem the
    /// difference is structural: a consumer whose rule closure is
    /// exactly a baked bundle is linted by the prebuilt runner, while
    /// one the classifier cannot route compiles its declared rule packs
    /// on the spot — orders of magnitude apart, not percentages.
    ///
    /// Unbounded on purpose. The rendering shows a leading slice and
    /// says how many of how many it is showing, so a reader can see that
    /// there is more rather than having to suspect it; a report that
    /// quietly truncated would hide exactly the pathological tail this
    /// exists to surface.
    public var slowest: [Workspace.Lint.Measurement] {
        measurements
            .sorted { $0.duration > $1.duration }
            .prefix { $0.duration > .zero }
            .map { $0 }
    }

    /// Exit status, matching `institute doctor`'s vocabulary.
    ///
    /// | Status | Meaning |
    /// |---|---|
    /// | 0 | measured, nothing failing |
    /// | 1 | measured, error-severity findings |
    /// | 2 | something could not be measured |
    ///
    /// Two beats one deliberately: an unmeasured package is a more
    /// serious result than a violation, because a violation is a fact
    /// about the code while an unmeasured package is the absence of any
    /// fact at all.
    public var status: Swift.Int32 {
        if !unmeasured.isEmpty { return 2 }
        if measurements.contains(where: { $0.verdict.fails }) { return 1 }
        return 0
    }
}

extension Workspace.Lint.Report: CustomStringConvertible {
    public var description: Swift.String {
        var lines = [Swift.String]()

        for measurement in unmeasured {
            lines.append("UNMEASURED  \(measurement.package)")
            if case .unmeasured(let reason) = measurement.verdict {
                lines.append("            \(reason)")
            }
            for line in measurement.unmeasuredDiagnostics {
                lines.append("            \(line)")
            }
        }
        for measurement in violations {
            lines.append("\(measurement.verdict.text)  \(measurement.package)")
        }

        if let fix {
            lines.append("")
            lines.append("fix \(fix.rawValue) measurement:")
            for measurement in measurements {
                guard let summary = measurement.summary else {
                    lines.append("  UNMEASURED  \(measurement.package)")
                    continue
                }
                let siteLabel = summary.violations == 1 ? "site" : "sites"
                lines.append(
                    "  \(measurement.package) · \(summary.activeRules) active rules · "
                        + "\(summary.filesLinted) files linted · \(summary.violations) rewrite "
                        + siteLabel
                )
                guard let plan = measurement.plan else { continue }
                if plan.sites.isEmpty {
                    lines.append("    rewrite plan: no eligible changes")
                    continue
                }
                lines.append("    rewrite plan:")
                for rule in plan.rules {
                    lines.append("      \(rule)")
                    for site in plan.sites(for: rule) {
                        lines.append("        \(site)")
                    }
                }
            }
        }

        if !excluded.isEmpty {
            lines.append("")
            lines.append(
                "PLAT-ARCH-022 excluded from --fix (\(excluded.count)) — qualification is "
                    + "unsound where a standard-library name is shadowed; other safe fixes proceed:"
            )
            for entry in excluded {
                lines.append("\(entry)")
            }
        }

        if !unmaterialized.isEmpty {
            lines.append("")
            lines.append(
                "not materialized (\(unmaterialized.count)): "
                    + unmaterialized.sorted().joined(separator: ", ")
            )
        }

        let ranked = slowest
        if !ranked.isEmpty {
            // The slice is a rendering choice, and it is disclosed. A
            // report that showed a fixed number of rows without saying
            // so would conceal a long tail behind something that reads
            // like a complete list.
            let shown = ranked.prefix(while: { $0.duration >= ranked[0].duration / 10 })
            lines.append("")
            lines.append(
                "slowest \(shown.count) of \(ranked.count) packages "
                    + "(within one order of magnitude of the slowest):"
            )
            for measurement in shown {
                lines.append(
                    "  \(Self.seconds(measurement.duration))  \(measurement.package)"
                )
            }
        }

        lines.append("")
        lines.append(
            "lint \(scope.text): \(measurements.count) packages linted · \(filesLinted) files · "
                + "\(clean.count) clean · \(violations.count) with violations · "
                + "\(unmeasured.count) UNMEASURED"
                + (excluded.isEmpty ? "" : " · \(excluded.count) PLAT-ARCH-022 exclusions")
        )
        lines.append("engine time \(Self.seconds(engineTime)) summed across packages")
        lines.append(
            "inventory \(inventory) · materialized \(considered) · scope \(scope.text)"
        )
        return lines.joined(separator: "\n")
    }
}

extension Workspace.Lint.Report {
    /// A duration in seconds, to two places.
    static func seconds(_ duration: Duration) -> Swift.String {
        let components = duration.components
        let hundredths = components.attoseconds / 10_000_000_000_000_000
        return "\(components.seconds).\(hundredths < 10 ? "0" : "")\(hundredths)s"
    }
}

extension Workspace.Lint.Sweep.Scope {
    public var text: Swift.String {
        switch self {
        case .all: "all"
        case .changed: "changed"
        }
    }
}

extension Workspace.Lint.Measurement: CustomStringConvertible {
    /// The single-package rendering.
    ///
    /// Findings first, then the engine's own summary line verbatim.
    /// Reproducing the summary rather than paraphrasing it means the
    /// number a developer reads locally is the number CI printed. An
    /// unmeasured verdict is followed by the engine's standard error for
    /// the same reason — verbatim, not paraphrased.
    public var description: Swift.String {
        var lines = findings
        if let summary {
            lines.append(
                "\(summary.package) · \(summary.activeRules) active rules · "
                    + "\(summary.filesLinted) files linted · \(summary.violations) violations"
            )
        }
        lines.append(verdict.text)
        lines.append(contentsOf: unmeasuredDiagnostics)
        return lines.joined(separator: "\n")
    }
}

extension Workspace.Lint.Measurement {
    /// The engine's standard error, as lines worth rendering.
    ///
    /// Populated only for an unmeasured verdict. A measured run's
    /// standard error is its summary line, which both renderings already
    /// reproduce; an unmeasured run's standard error is the engine's own
    /// account of why it established nothing — a channel it found unset,
    /// an option it rejected. ``diagnostics`` is retained precisely so
    /// that account can be shown, and a rendering that withholds it
    /// reports a mystery where the tool named a cause.
    var unmeasuredDiagnostics: [Swift.String] {
        guard verdict.isUnmeasured, summary == nil else { return [] }
        return diagnostics
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(Swift.String.init)
    }
}
