extension Workspace.Inventory.Effective.Roster {
    /// Why a supplied roster could not be accepted.
    ///
    /// Four distinct failures, kept distinct: a caller that cannot read its
    /// own roster file, one that wrote something this schema does not
    /// describe, and one that supplied nothing at all are three different
    /// operational problems, and only the last is a *measurement* claim.
    public enum Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        /// The roster file could not be read.
        case unreadable(Swift.String)
        /// The bytes are not a roster document this schema version accepts.
        case malformed(Swift.String)
        /// The roster carries no repositories. Refused rather than
        /// digested: an empty population has a perfectly good SHA-256, and
        /// publishing it would state that the Institute has no private
        /// repositories — a false measurement, where a typed UNMEASURED
        /// would have been an honest one.
        case emptyPopulation
    }
}

extension Workspace.Inventory.Effective.Roster.Error {
    public var description: Swift.String {
        switch self {
        case .unreadable(let path): "cannot read the supplied roster at \(path)"
        case .malformed(let reason): "the supplied roster is not a valid roster document: \(reason)"
        case .emptyPopulation:
            "the supplied roster carries no repositories; refusing to digest an empty "
                + "population, which would publish a real digest of a measurement nobody made"
        }
    }
}
