extension Workspace.Verification.Inventory.Digest {
    /// Why a pair of wire fields is not a valid inventory digest.
    public enum Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        /// `"unmeasured"` with no cause — the state this type exists to
        /// make unrepresentable, and the one the fleet was shipping.
        case unmeasuredWithoutCause
        /// A real digest accompanied by a cause: the two are mutually
        /// exclusive, and accepting both would leave a reader unable to
        /// tell which one the run actually meant.
        case measuredWithCause
        /// Neither `"unmeasured"` nor 64 lowercase hexadecimal digits.
        case notLowercaseHex64
    }
}

extension Workspace.Verification.Inventory.Digest.Error {
    public var description: Swift.String {
        switch self {
        case .unmeasuredWithoutCause:
            "an unmeasured inventory digest requires a cause; \"unmeasured\" on its own "
                + "records that a measurement is missing without recording why"
        case .measuredWithCause:
            "a measured inventory digest cannot also carry an unmeasured cause"
        case .notLowercaseHex64:
            "an inventory digest must be 64 lowercase hexadecimal digits, or \"unmeasured\" "
                + "with a cause"
        }
    }
}
