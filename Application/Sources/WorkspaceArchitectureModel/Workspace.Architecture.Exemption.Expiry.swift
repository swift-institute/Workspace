extension Workspace.Architecture.Exemption {
    /// A calendar day in `YYYY-MM-DD` form, validated at construction.
    ///
    /// The canonical form is lexicographically ordered, so comparison needs
    /// no calendar arithmetic and no Foundation.
    public struct Expiry: Sendable, Equatable, Hashable {
        public let rawValue: Swift.String

        public init(rawValue: Swift.String) throws(Workspace.Architecture.Exemption.Error) {
            let characters = Swift.Array(rawValue.utf8)
            guard
                characters.count == 10,
                characters[4] == Swift.UInt8(ascii: "-"),
                characters[7] == Swift.UInt8(ascii: "-"),
                characters.enumerated().allSatisfy({ (index, byte) in
                    index == 4 || index == 7
                        || (byte >= Swift.UInt8(ascii: "0") && byte <= Swift.UInt8(ascii: "9"))
                })
            else {
                throw .malformedExpiry(rawValue)
            }
            self.rawValue = rawValue
        }
    }
}

extension Workspace.Architecture.Exemption.Expiry: Comparable {
    public static func < (
        lhs: Workspace.Architecture.Exemption.Expiry,
        rhs: Workspace.Architecture.Exemption.Expiry
    ) -> Swift.Bool {
        lhs.rawValue < rhs.rawValue
    }
}
