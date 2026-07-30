public import JSON

extension Workspace.Conversion {
    /// What identifies the instrument that produced a conversion receipt:
    /// the Workspace revision, the inventory it read, which selection was
    /// in effect, the page population it seals (by digest, not by
    /// re-enumeration), and the pre-registered protocol freeze it certifies
    /// against.
    ///
    /// `selection` follows the rule ``Workspace/Coherence/Instrument`` and
    /// ``Workspace/Pages/Instrument`` already document — `"policy"` for a
    /// canonical run, otherwise a verbatim rendering of the narrowing
    /// delta — and a receipt whose `selection` is not `"policy"` is
    /// non-canonical and must never be cited as a fleet conversion result.
    public struct Instrument: Equatable, Sendable, JSON.Serializable {
        public let workspaceCommit: Swift.String
        public let workspaceJsonBlob: Swift.String
        public let selection: Swift.String
        public let pageInventoryDigest: Swift.String
        public let protocolCommit: Swift.String
        public let protocolBlob: Swift.String

        public init(
            workspaceCommit: Swift.String,
            workspaceJsonBlob: Swift.String,
            selection: Swift.String,
            pageInventoryDigest: Swift.String,
            protocolCommit: Swift.String = Workspace.Conversion.protocolCommit,
            protocolBlob: Swift.String = Workspace.Conversion.protocolBlob
        ) {
            self.workspaceCommit = workspaceCommit
            self.workspaceJsonBlob = workspaceJsonBlob
            self.selection = selection
            self.pageInventoryDigest = pageInventoryDigest
            self.protocolCommit = protocolCommit
            self.protocolBlob = protocolBlob
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "workspaceCommit": value.workspaceCommit.json,
                "workspaceJsonBlob": value.workspaceJsonBlob.json,
                "selection": value.selection.json,
                "pageInventoryDigest": value.pageInventoryDigest.json,
                "protocolCommit": value.protocolCommit.json,
                "protocolBlob": value.protocolBlob.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let workspaceCommit = object["workspaceCommit"] else {
                throw .missingKey("workspaceCommit")
            }
            guard let workspaceJsonBlob = object["workspaceJsonBlob"] else {
                throw .missingKey("workspaceJsonBlob")
            }
            guard let selection = object["selection"] else { throw .missingKey("selection") }
            guard let pageInventoryDigest = object["pageInventoryDigest"] else {
                throw .missingKey("pageInventoryDigest")
            }
            guard let protocolCommit = object["protocolCommit"] else {
                throw .missingKey("protocolCommit")
            }
            guard let protocolBlob = object["protocolBlob"] else { throw .missingKey("protocolBlob") }
            return try Self(
                workspaceCommit: Swift.String(json: workspaceCommit),
                workspaceJsonBlob: Swift.String(json: workspaceJsonBlob),
                selection: Swift.String(json: selection),
                pageInventoryDigest: Swift.String(json: pageInventoryDigest),
                protocolCommit: Swift.String(json: protocolCommit),
                protocolBlob: Swift.String(json: protocolBlob)
            )
        }
    }
}
