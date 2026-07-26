extension Workspace.Doctor {
    /// One measured problem, produced by a check's evaluation of one subject.
    public struct Finding: Equatable, Sendable {
        public let severity: Severity
        public let message: Swift.String

        public init(severity: Severity, message: Swift.String) {
            self.severity = severity
            self.message = message
        }
    }
}
