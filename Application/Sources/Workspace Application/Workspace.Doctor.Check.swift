extension Workspace.Doctor {
    /// One doctor check: a named, statically scoped evaluation over a
    /// population of subjects, with declared controls.
    ///
    /// The controls are a known-positive subject that must fire and a
    /// known-negative subject that must not. They run through
    /// ``run(population:inventory:)`` — the same `evaluate` code path as
    /// the measurement, not a top-level preflight — so a control failure
    /// proves the evaluation itself is broken and aborts the check at
    /// `unmeasured`.
    public struct Check<Subject: Sendable>: Sendable {
        public let name: Swift.String
        public let scope: Scope
        public let controls: Controls
        public let evaluate: @Sendable (Subject) -> [Finding]

        public init(
            name: Swift.String,
            scope: Scope,
            controls: Controls,
            evaluate: @escaping @Sendable (Subject) -> [Finding]
        ) {
            self.name = name
            self.scope = scope
            self.controls = controls
            self.evaluate = evaluate
        }
    }
}

extension Workspace.Doctor.Check {
    /// Measures the population and returns the check's outcome.
    ///
    /// The controls run first, through the same `evaluate` path as the
    /// subjects; a control failure aborts at `unmeasured`. An empty
    /// population against a non-empty `inventory` is `unmeasured`, never
    /// `ok`. This method can only end in `ok`, `finding`, or `unmeasured` —
    /// `notApplicable` exists solely on the runner's scope gate, before a
    /// measurement is attempted.
    public func run(population: [Subject], inventory: Int) -> Workspace.Doctor.Outcome {
        guard !evaluate(controls.positive).isEmpty else {
            return unmeasured(reason: "the known-positive control did not fire")
        }
        guard evaluate(controls.negative).isEmpty else {
            return unmeasured(reason: "the known-negative control fired")
        }
        guard !population.isEmpty || inventory == 0 else {
            return unmeasured(
                reason: "empty population against an inventory of \(inventory)"
            )
        }

        let findings = population.flatMap(evaluate)
        guard let severity = findings.map(\.severity).max() else {
            return .init(
                check: name,
                scope: scope,
                result: .ok(population: population.count),
                findings: []
            )
        }
        return .init(
            check: name,
            scope: scope,
            result: .finding(severity: severity, population: population.count),
            findings: findings
        )
    }

    /// The outcome of a check whose preconditions could not be established —
    /// gathering the population failed before evaluation could begin.
    public func unmeasured(reason: Swift.String) -> Workspace.Doctor.Outcome {
        .init(
            check: name,
            scope: scope,
            result: .unmeasured(reason: reason),
            findings: []
        )
    }

    /// The outcome of a check whose declared scope exceeds the run's
    /// access — reported as not applicable. Only the runner's scope gate
    /// may use this, and only *before* attempting the measurement.
    public var omitted: Workspace.Doctor.Outcome {
        .init(
            check: name,
            scope: scope,
            result: .notApplicable(scope: scope),
            findings: []
        )
    }
}
