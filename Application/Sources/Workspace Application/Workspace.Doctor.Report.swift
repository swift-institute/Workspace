extension Workspace.Doctor {
    /// Every check's outcome for one run, with the run's exit status and
    /// rendered summary.
    public struct Report: Equatable, Sendable {
        public let outcomes: [Outcome]

        public init(outcomes: [Outcome]) {
            self.outcomes = outcomes
        }
    }
}

extension Workspace.Doctor.Report {
    /// The run's exit status: 2 if any check is `unmeasured`, else 1 if
    /// any check measured an `error` finding, else 0. `notApplicable`
    /// and `warning` findings contribute 0.
    public var status: Int32 {
        if unmeasured > 0 { return 2 }
        if errors > 0 { return 1 }
        return 0
    }

    public var errors: Int {
        outcomes.flatMap(\.findings).count { $0.severity == .error }
    }

    public var warnings: Int {
        outcomes.flatMap(\.findings).count { $0.severity == .warning }
    }

    public var unmeasured: Int {
        outcomes.count {
            if case .unmeasured = $0.result { return true }
            return false
        }
    }

    /// How many checks were gated to `notApplicable` by scope.
    public var omitted: Int {
        outcomes.count {
            if case .notApplicable = $0.result { return true }
            return false
        }
    }

    private var ok: Int {
        outcomes.count {
            if case .ok = $0.result { return true }
            return false
        }
    }

    private var withFindings: Int {
        outcomes.count {
            if case .finding = $0.result { return true }
            return false
        }
    }

    /// The measured populations, per check, in run order. A check that
    /// did not measure (`unmeasured`, `notApplicable`) does not appear.
    public var populations: [(check: Swift.String, population: Int)] {
        outcomes.compactMap { outcome in
            switch outcome.result {
            case .ok(let population), .finding(_, let population):
                (outcome.check, population)
            case .unmeasured, .notApplicable:
                nil
            }
        }
    }
}

extension Workspace.Doctor.Report: CustomStringConvertible {
    public var description: Swift.String {
        var lines = [Swift.String]()
        for outcome in outcomes {
            lines.append("\(outcome.check): \(outcome.result)")
            for finding in outcome.findings {
                lines.append("  \(finding.severity): \(finding.message)")
            }
        }
        lines.append(summary)
        lines.append(verdict)
        return lines.joined(separator: "\n")
    }

    /// One line counting the run's outcomes, naming what did not run,
    /// and stating the measured populations — not only finding counts.
    private var summary: Swift.String {
        var segments = ["\(ok) ok"]
        if withFindings > 0 { segments.append("\(withFindings) with findings") }
        if unmeasured > 0 { segments.append("\(unmeasured) unmeasured") }
        if omitted > 0 {
            segments.append("\(omitted) not run (institute-internal)")
        }

        let counted = "\(outcomes.count) checks: \(segments.joined(separator: ", "))"
        guard !populations.isEmpty else { return counted }
        let measured =
            populations
            .map { "\($0.check) \($0.population)" }
            .joined(separator: ", ")
        return "\(counted); measured populations: \(measured)"
    }

    /// The run's verdict. A run containing an `unmeasured` check is
    /// never described as passing.
    private var verdict: Swift.String {
        switch status {
        case 2:
            "doctor: not passing — \(unmeasured) check(s) unmeasured."
        case 1:
            "doctor: not passing — \(errors) error(s), \(warnings) warning(s)."
        default:
            "doctor: passed — \(ok + withFindings) check(s) measured, "
                + "\(omitted) not run (institute-internal), \(warnings) warning(s)."
        }
    }
}
