public import File_System
public import JSON

extension Workspace.Coherence {
    /// A mechanical failure attribution: present iff the verdict is
    /// ``Verdict/incoherent``.
    ///
    /// `package`/`organization`/`layer` are derived from the first
    /// diagnostic's file path through ``Workspace/Layout`` — the sole
    /// name → organization → path authority — never guessed from the
    /// diagnostic text itself. A diagnostic whose path matches no selected
    /// repository's materialized directory (a toolchain-internal file, for
    /// instance) leaves all three `nil`; the diagnostic text is still
    /// recorded, so the run is never silently unattributed.
    public struct Attribution: Equatable, Sendable, JSON.Serializable {
        public let stage: Stage
        public let package: Swift.String?
        public let organization: Swift.String?
        public let layer: Swift.String?
        public let firstDiagnostic: Swift.String
        public let headsChangedSinceLastGreen: [Swift.String]

        public init(
            stage: Stage,
            package: Swift.String?,
            organization: Swift.String?,
            layer: Swift.String?,
            firstDiagnostic: Swift.String,
            headsChangedSinceLastGreen: [Swift.String]
        ) {
            self.stage = stage
            self.package = package
            self.organization = organization
            self.layer = layer
            self.firstDiagnostic = firstDiagnostic
            self.headsChangedSinceLastGreen = headsChangedSinceLastGreen
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "stage": value.stage.json,
                "package": value.package.json,
                "organization": value.organization.json,
                "layer": value.layer.json,
                "firstDiagnostic": value.firstDiagnostic.json,
                "headsChangedSinceLastGreen": value.headsChangedSinceLastGreen.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            guard let stage = object["stage"] else { throw .missingKey("stage") }
            guard let firstDiagnostic = object["firstDiagnostic"] else {
                throw .missingKey("firstDiagnostic")
            }
            guard let headsChangedSinceLastGreen = object["headsChangedSinceLastGreen"] else {
                throw .missingKey("headsChangedSinceLastGreen")
            }
            return try Self(
                stage: Stage(json: stage),
                package: Swift.String?(json: object["package"] ?? .null),
                organization: Swift.String?(json: object["organization"] ?? .null),
                layer: Swift.String?(json: object["layer"] ?? .null),
                firstDiagnostic: Swift.String(json: firstDiagnostic),
                headsChangedSinceLastGreen: [Swift.String](json: headsChangedSinceLastGreen)
            )
        }
    }
}

extension Workspace.Coherence {
    /// The first `error:`-carrying line in a build's captured output, or
    /// the last non-empty line when no diagnostic is recognisable — a
    /// failed build with no line matching the compiler's own diagnostic
    /// shape is still reported, never silently dropped.
    static func firstDiagnostic(
        standardOutput: [Swift.UInt8]?,
        standardError: [Swift.UInt8]?
    ) -> Swift.String {
        let combined =
            Swift.String(decoding: standardOutput ?? [], as: Swift.UTF8.self)
            + "\n"
            + Swift.String(decoding: standardError ?? [], as: Swift.UTF8.self)
        let lines = combined.split(separator: "\n", omittingEmptySubsequences: true)
        if let diagnostic = lines.first(where: { $0.contains(": error:") }) {
            return Swift.String(diagnostic)
        }
        return lines.last.map(Swift.String.init) ?? "no diagnostic captured"
    }

    /// Maps a diagnostic line's leading `path:line:col:` file path to the
    /// selected repository whose materialized directory contains it, via
    /// ``Workspace/Layout`` — never by pattern-matching the package name
    /// out of the diagnostic text.
    static func attribute(
        _ diagnostic: Swift.String,
        repositories: [Workspace.Repository],
        root: Workspace.Root
    ) -> Workspace.Repository? {
        guard let colon = diagnostic.firstIndex(of: ":") else { return nil }
        let path = Swift.String(diagnostic[diagnostic.startIndex..<colon])
        for repository in repositories {
            guard let directory = try? Workspace.Layout.directory(for: repository, at: root.hierarchy)
            else { continue }
            if path.hasPrefix(directory.description) { return repository }
        }
        return nil
    }
}
