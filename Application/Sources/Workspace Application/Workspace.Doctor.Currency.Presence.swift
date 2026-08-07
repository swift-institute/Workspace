extension Workspace.Doctor.Currency {
    public enum Presence: Equatable, Sendable {
        /// In `Institute.json` but not discovered on GitHub, and no
        /// discovered repository of the same bare name accounts for it
        /// either (see ``moved(from:to:)``).
        case committed
        /// Discovered on GitHub but missing from `Institute.json`, and no
        /// committed repository of the same bare name accounts for it
        /// either (see ``moved(from:to:)``).
        case discovered
        /// The same repository name is committed under one organization
        /// and discovered under another — a cross-org move, or a wrong
        /// `organization` field paired with a correct `name`. Both read
        /// the same from a bare-name join, which is exactly the defect
        /// this case exists to distinguish (Workspace#84).
        case moved(from: Swift.String, to: Swift.String)
        /// The full coordinate (organization + name) matches, but a
        /// field beyond the coordinate itself disagrees between
        /// `Institute.json` and the live discovery.
        case mismatch(field: Swift.String, committed: Swift.String, discovered: Swift.String)
        /// In both, at the same coordinate, with every validated field
        /// agreeing — current.
        case both
    }
}
