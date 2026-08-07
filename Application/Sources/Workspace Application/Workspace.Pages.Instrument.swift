public import JSON

extension Workspace.Pages {
    /// What identifies the instrument that produced a page inventory: the
    /// Workspace revision, the `Institute.json` blob it read, and which
    /// selection was in effect.
    ///
    /// `selection` is `"policy"` for a canonical run — no local override in
    /// effect — and otherwise a verbatim rendering of the narrowing delta;
    /// an inventory whose `selection` is not `"policy"` is non-canonical
    /// and must never be cited as a fleet page inventory. This is the rule
    /// `Workspace.Coherence.Instrument.selection` already documents,
    /// restated here rather than imported, per issue #82.
    public struct Instrument: Equatable, Sendable, JSON.Serializable {
        public let workspaceCommit: Swift.String
        public let workspaceJsonBlob: Swift.String
        public let selection: Swift.String

        public init(
            workspaceCommit: Swift.String,
            workspaceJsonBlob: Swift.String,
            selection: Swift.String
        ) {
            self.workspaceCommit = workspaceCommit
            self.workspaceJsonBlob = workspaceJsonBlob
            self.selection = selection
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "workspaceCommit": value.workspaceCommit.json,
                "workspaceJsonBlob": value.workspaceJsonBlob.json,
                "selection": value.selection.json,
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
            return try Self(
                workspaceCommit: Swift.String(json: workspaceCommit),
                workspaceJsonBlob: Swift.String(json: workspaceJsonBlob),
                selection: Swift.String(json: selection)
            )
        }
    }
}
