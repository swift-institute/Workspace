extension Workspace.Doctor {
    /// The three-state result of a doctor check, plus the hard-constrained
    /// not-applicable state.
    ///
    /// | Result | Meaning | Exit contribution |
    /// |---|---|---|
    /// | `ok(population:)` | measured, n subjects covered, no findings | 0 |
    /// | `finding(severity:population:)` | measured, problems listed | 1 for `.error`, 0 for `.warning` |
    /// | `unmeasured(reason:)` | preconditions could not be established | 2 |
    /// | `notApplicable(scope:)` | statically out of scope for this run | 0 |
    ///
    /// A measurement that has begun may only end in `ok`, `finding`, or
    /// `unmeasured`: ``Workspace/Doctor/Check`` can construct only those
    /// three, and `notApplicable` is produced solely by the runner's
    /// scope gate *before* a measurement is attempted. An empty population
    /// against a non-empty inventory is `unmeasured`, never `ok`.
    public enum Result: Equatable, Sendable {
        case ok(population: Int)
        case finding(severity: Severity, population: Int)
        case unmeasured(reason: Swift.String)
        case notApplicable(scope: Scope)
    }
}

extension Workspace.Doctor.Result: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .ok(let population):
            "ok (population \(population))"
        case .finding(let severity, let population):
            "\(severity) findings (population \(population))"
        case .unmeasured(let reason):
            "unmeasured — \(reason)"
        case .notApplicable(let scope):
            "not run (\(scope))"
        }
    }
}
