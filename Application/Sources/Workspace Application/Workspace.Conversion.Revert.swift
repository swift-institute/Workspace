public import JSON

extension Workspace.Conversion {
    /// The one rehearsed and receipted revert the gate names.
    ///
    /// ``Outcome`` is never authored directly — the only public
    /// initializer (``init(coordinate:revertCommit:restoredBlob:expectedPreConversionBlob:)``)
    /// computes it from the equality of `restoredBlob` and the page's
    /// recorded `preConversionBlob`, so a receipt can never claim
    /// `restored` while disagreeing with its own `pages` entry.
    public struct Revert: Equatable, Sendable, JSON.Serializable {
        public let coordinate: Workspace.Repository.Key
        public let revertCommit: Swift.String
        public let restoredBlob: Swift.String
        public let outcome: Outcome

        /// Computes ``outcome`` from equality with `expectedPreConversionBlob`
        /// — the `preConversionBlob` this coordinate's page record carries.
        public init(
            coordinate: Workspace.Repository.Key,
            revertCommit: Swift.String,
            restoredBlob: Swift.String,
            expectedPreConversionBlob: Swift.String
        ) {
            self.coordinate = coordinate
            self.revertCommit = revertCommit
            self.restoredBlob = restoredBlob
            self.outcome = restoredBlob == expectedPreConversionBlob ? .restored : .failed
        }

        /// Deserialization-only: `outcome` is read back verbatim from the
        /// receipt rather than recomputed, since decoding a receipt has no
        /// access to the page population that produced it. ``check`` mode
        /// is what re-derives and validates this field against the
        /// receipt's own ``Workspace/Conversion/Page``.
        fileprivate init(
            coordinate: Workspace.Repository.Key,
            revertCommit: Swift.String,
            restoredBlob: Swift.String,
            outcome: Outcome
        ) {
            self.coordinate = coordinate
            self.revertCommit = revertCommit
            self.restoredBlob = restoredBlob
            self.outcome = outcome
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "coordinate": value.coordinate.json,
                "revertCommit": value.revertCommit.json,
                "restoredBlob": value.restoredBlob.json,
                "outcome": value.outcome.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let coordinate = object["coordinate"] else { throw .missingKey("coordinate") }
            guard let revertCommit = object["revertCommit"] else { throw .missingKey("revertCommit") }
            guard let restoredBlob = object["restoredBlob"] else { throw .missingKey("restoredBlob") }
            guard let outcome = object["outcome"] else { throw .missingKey("outcome") }
            return try Self(
                coordinate: Workspace.Repository.Key(json: coordinate),
                revertCommit: Swift.String(json: revertCommit),
                restoredBlob: Swift.String(json: restoredBlob),
                outcome: Outcome(json: outcome)
            )
        }
    }
}
