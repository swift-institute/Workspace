extension Workspace.Lint {
    /// The result of one sweep, and the exit status it implies.
    ///
    /// Three tallies rather than two. A sweep that reported only
    /// "packages" and "violations" would have nowhere to put a package
    /// it failed to measure, and anything without a place to go gets
    /// absorbed into the clean count.
    public struct Report: Sendable {
        public let scope: Sweep.Scope

        /// Packages in `Workspace.json`.
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

    /// The packages that dominated the run, slowest first.
    ///
    /// A sweep whose total is driven by a handful of packages is a
    /// different problem from one that is uniformly slow, and an
    /// aggregate alone cannot tell them apart. In this ecosystem the
    /// difference is structural: a consumer whose rule closure is
    /// exactly a baked bundle is linted by the prebuilt runner, while
    /// one the classifier cannot route compiles its declared rule packs
    /// on the spot — orders of magnitude apart, not percentages.
    public var slowest: [Workspace.Lint.Measurement] {
        measurements
            .sorted { $0.duration > $1.duration }
            .prefix(while: { $0.duration > .zero })
            .prefix(5)
            .map { $0 }
    }

    /// Exit status, matching `workspace doctor`'s vocabulary.
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
        }
        for measurement in violations {
            lines.append("\(measurement.verdict.text)  \(measurement.package)")
        }

        if !unmaterialized.isEmpty {
            lines.append("")
            lines.append(
                "not materialized (\(unmaterialized.count)): "
                    + unmaterialized.sorted().joined(separator: ", ")
            )
        }

        if !slowest.isEmpty {
            lines.append("")
            lines.append("slowest packages:")
            for measurement in slowest {
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
    /// number a developer reads locally is the number CI printed.
    public var description: Swift.String {
        var lines = findings
        if let summary {
            lines.append(
                "\(summary.package) · \(summary.activeRules) active rules · "
                    + "\(summary.filesLinted) files linted · \(summary.violations) violations"
            )
        }
        lines.append(verdict.text)
        return lines.joined(separator: "\n")
    }
}
