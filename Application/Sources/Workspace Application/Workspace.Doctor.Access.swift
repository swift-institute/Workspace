extension Workspace.Doctor {
    /// What the run can reach, decided by the caller per run.
    ///
    /// A contributor run carries no Institute access: checks scoped
    /// ``Workspace/Doctor/Scope/instituteInternal`` are gated to
    /// `notApplicable` before their measurement is attempted, and their
    /// absence is named in the report rather than silently skipped.
    /// Absence of Institute access is not a defect in the checkout and
    /// never fails the run.
    public enum Access: Sendable {
        /// No Institute access; institute-internal checks do not run.
        case contributor
        /// Institute access, carrying the means to measure the
        /// institute-internal checks: an inventory discovery over the
        /// live GitHub organizations.
        case institute(
            inventory: @Sendable () async throws(Workspace.Error) -> Workspace.Inventory.Discovery
        )
    }
}
