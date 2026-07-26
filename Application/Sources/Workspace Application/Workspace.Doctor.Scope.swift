extension Workspace.Doctor {
    /// Who can run a check, declared statically on the check itself.
    ///
    /// The scope is gated *before* a measurement is attempted: a
    /// contributor run never begins an `instituteInternal` measurement,
    /// so "did not run, by scope" can never masquerade as "ran and found
    /// nothing".
    public enum Scope: Equatable, Sendable {
        /// Runnable by anyone with a bare clone; no Institute access.
        case contributor
        /// Needs Institute access; reported as not run for contributors.
        case instituteInternal
    }
}

extension Workspace.Doctor.Scope: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .contributor: "contributor"
        case .instituteInternal: "institute-internal"
        }
    }
}
