public import WorkspaceArchitectureModel

extension Workspace.Architecture.Validator {
    /// The outcome of one validation pass.
    public struct Report: Sendable, Equatable {
        /// Violations no valid exemption covers; any entry fails the run.
        public let violations: [Workspace.Architecture.Violation]
        /// Violations an unexpired, scope- and owner-matching exemption
        /// covers.
        public let excused: [Workspace.Architecture.Violation]

        public init(
            violations: [Workspace.Architecture.Violation],
            excused: [Workspace.Architecture.Violation]
        ) {
            self.violations = violations
            self.excused = excused
        }
    }
}

extension Workspace.Architecture.Validator.Report {
    public var passes: Swift.Bool {
        violations.isEmpty
    }
}
