public import GitHub

extension Workspace.Inventory.Private {
    /// A repository or organization the private pass could not read —
    /// distinct from `deleted`, `denied`, or `absent`.
    ///
    /// ``Client/discoverPrivate(_:)`` fails closed by *record*, not by
    /// *abort*, at this boundary: the public ``Client/discover(_:)`` throws
    /// and stops the whole run the moment one repository's content read
    /// fails, because the committed file it feeds must never publish a
    /// silently short roster. The private pass feeds no committed file — it
    /// feeds a read-only digest a downstream verifier compares against — so
    /// the correct failure shape is the opposite: one inaccessible
    /// repository (a lost App installation grant, a transient transport
    /// failure) must not blank out every sibling repository's evidence for
    /// the run. Losing that evidence silently would be indistinguishable
    /// from the repository having been deleted, which is exactly the
    /// silent-shortening hazard the public path already refuses. Recording
    /// `Unmeasured` instead is what keeps the two paths refusing the *same*
    /// hazard through different mechanics appropriate to each one's
    /// consumer.
    public struct Unmeasured: Equatable, Sendable {
        public let scope: Scope
        /// `"\(error)"` of the underlying typed failure — captured, not
        /// swallowed, so a caller can distinguish a permission loss from a
        /// transport error without this type depending on either error
        /// type's concrete shape.
        public let reason: Swift.String

        public init(scope: Scope, reason: Swift.String) {
            self.scope = scope
            self.reason = reason
        }
    }
}

extension Workspace.Inventory.Private.Unmeasured {
    public enum Scope: Equatable, Sendable {
        /// A specific repository's content (`Package.swift`) could not be
        /// read, even though its organization's listing succeeded.
        case repository(Workspace.Repository.Key)
        /// An organization's private listing itself failed — every private
        /// repository it might hold is unmeasured, not zero.
        case organization(GitHub.Organization.Name)
    }
}
