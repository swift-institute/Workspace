extension Workspace.Verification.Run {
    /// Why a lint leg produced no measurement, in a form that can cross the
    /// receipt boundary.
    ///
    /// **Why this type exists (R34.1).** The lint leg's reason used to be
    /// free text interpolating the subject's absolute path — `"cannot run
    /// the lint gate at \(path): \(error)"` — and it forwarded the linter's
    /// own unmeasured reason verbatim, which likewise quotes absolute
    /// package and hierarchy paths. ``Workspace/Verification/Redaction``
    /// rightly refuses to seal a receipt carrying an absolute machine path,
    /// so a lint leg that went unmeasured could never seal *at all*: the
    /// refusal was not a lint failure but an instrument defect, and it is
    /// the original cause of the lint leg being dropped from the requested
    /// contract rather than fixed.
    ///
    /// Every case below names a stage and, where one exists, the leak-safe
    /// ``Workspace/Error/Kind`` of the failure. None interpolates a path, a
    /// command line, or any captured text, so none can be refused by
    /// ``Workspace/Verification/Redaction`` — the reason a reader gets is
    /// smaller than the old free text but, unlike it, actually arrives.
    public enum Refusal: Equatable, Sendable, CustomStringConvertible {
        /// The subject's lint target could not be resolved.
        case unresolvableTarget(Workspace.Error.Kind)
        /// The subject's rule set could not be resolved from its
        /// `Lint.swift` or its position in the layer hierarchy.
        case unresolvableConfiguration(Workspace.Error.Kind)
        /// No usable swift-linter installation could be established.
        case unavailableInstallation(Workspace.Error.Kind)
        /// The linter ran and declined to measure, but its own reason
        /// carries content this instrument will not seal. The full reason
        /// is still printed by `institute package lint` locally; only the
        /// receipt withholds it.
        case unsealableMeasurementReason
    }
}

extension Workspace.Verification.Run.Refusal {
    public var description: Swift.String {
        switch self {
        case .unresolvableTarget(let kind):
            "the lint gate could not resolve the subject as a lint target (\(kind))"
        case .unresolvableConfiguration(let kind):
            "the lint gate could not resolve the subject's rule set (\(kind))"
        case .unavailableInstallation(let kind):
            "the lint gate could not establish a swift-linter installation (\(kind))"
        case .unsealableMeasurementReason:
            "the lint gate declined to measure, for a reason that cannot cross the receipt "
                + "boundary"
        }
    }
}
