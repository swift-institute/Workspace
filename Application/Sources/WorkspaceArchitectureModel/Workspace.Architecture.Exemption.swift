extension Workspace.Architecture {
    /// A derived-model exemption: the only exemption form that exists.
    ///
    /// An exemption names its owner, its reason, the violation scope it
    /// excuses and when it expires — all four are required by construction.
    /// No authored-assertion-schema exemption exists; that schema is
    /// deferred indefinitely (principal ruling 5, swift-institute/.github#85
    /// comment 5212930927).
    public struct Exemption: Sendable, Equatable, Hashable {
        public let owner: Owner
        public let reason: Swift.String
        public let scope: Scope
        public let expiry: Expiry

        public init(
            owner: Owner,
            reason: Swift.String,
            scope: Scope,
            expiry: Expiry
        ) throws(Error) {
            guard !reason.isEmpty else {
                throw .emptyReason(owner: owner)
            }
            self.owner = owner
            self.reason = reason
            self.scope = scope
            self.expiry = expiry
        }
    }
}
