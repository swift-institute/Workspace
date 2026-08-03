import Testing

@testable import Workspace_Application

@Suite
struct `Workspace Lint Currency Tests` {
    /// A verbatim capture of an installed `MANIFEST.txt`.
    static let installed = """
        digest=6d0eb3bf33f2b4b991f154c5dcc48c6abb689e11e8bfe40773cf238e96c30b4a
        engine=fe3ec365fc3655552fae59b74ff2c0498e260589
        swift-primitives-linter-rules=e8cc9ac6bd512b298b986b723035ab211b3743ae
        swift-standards-linter-rules=b92fb3fd12526280e472e661bf4c70f4df911c7d
        swift-institute-linter-rules=0e7304f7d4394bbf92b043c7876cd41341092b05
        swift-linter-rules=4f1d20cf132819be1c4b9516a2fc000d7ba3e04e
        swift-linter-primitives=701d4dd2855073793def0abfa348f0df72257b53
        built-at=2026-08-01T12:11:24Z
        platform=macos-arm64
        xcode=26.6
        """

    /// The heads that build was made from — every input matching.
    static let matching: [Swift.String: Swift.String] = [
        "engine": "fe3ec365fc3655552fae59b74ff2c0498e260589",
        "swift-primitives-linter-rules": "e8cc9ac6bd512b298b986b723035ab211b3743ae",
        "swift-standards-linter-rules": "b92fb3fd12526280e472e661bf4c70f4df911c7d",
        "swift-institute-linter-rules": "0e7304f7d4394bbf92b043c7876cd41341092b05",
        "swift-linter-rules": "4f1d20cf132819be1c4b9516a2fc000d7ba3e04e",
        "swift-linter-primitives": "701d4dd2855073793def0abfa348f0df72257b53",
    ]

    /// Where the fixture manifest is pretending to have been read from.
    static let source = "/fixture/.workspace/lint/MANIFEST.txt"

    @Test
    func `a current install reports nothing`() throws {
        let manifest = try Workspace.Lint.Manifest.parse(Self.installed, label: "fixture")
        #expect(
            Workspace.Lint.currency(
                of: manifest,
                against: Self.matching,
                at: Self.source
            ).isEmpty
        )
    }

    @Test
    func `a moved rule pack is named, with the remedy`() throws {
        let manifest = try Workspace.Lint.Manifest.parse(Self.installed, label: "fixture")
        var heads = Self.matching
        heads["swift-institute-linter-rules"] =
            "eab2cddebfb196027fa85d0c3586f6719381b599"
        let findings = Workspace.Lint.currency(
            of: manifest,
            against: heads,
            at: Self.source
        )
        #expect(findings.count == 4)
        #expect(findings.first == Workspace.Lint.stale)
        #expect(
            findings[1] == "  swift-institute-linter-rules: installed 0e7304f, eab2cdd on main"
        )
        #expect(findings.last == Workspace.Lint.republish)
    }

    @Test
    func `every input that moved is named, not only the first`() throws {
        let manifest = try Workspace.Lint.Manifest.parse(Self.installed, label: "fixture")
        var heads = Self.matching
        heads["engine"] = "1a80ddd4b14accd2efb62e15802d41ee185a24d3"
        heads["swift-linter-rules"] = "50ea9b51507073efddf88cf929c842e63c1ead5b"
        let findings = Workspace.Lint.currency(
            of: manifest,
            against: heads,
            at: Self.source
        )
        #expect(findings.count == 5)
        #expect(findings[1] == "  engine: installed fe3ec36, 1a80ddd on main")
        #expect(findings[2] == "  swift-linter-rules: installed 4f1d20c, 50ea9b5 on main")
    }

    /// The refusal must name the manifest it judged.
    ///
    /// Two installed trees on one machine is the ordinary case — the
    /// `--fix` path ascends from the package to the nearest one — and a
    /// refusal naming only a revision cannot be checked by a reader who
    /// does not know which tree was reached. Inspecting some other
    /// manifest and finding it current is consistent with the refusal
    /// being correct, so without this line the correct refusal reads as
    /// a defect.
    @Test
    func `the refusal names the installation it judged`() throws {
        let manifest = try Workspace.Lint.Manifest.parse(Self.installed, label: "fixture")
        var heads = Self.matching
        heads["engine"] = "1a80ddd4b14accd2efb62e15802d41ee185a24d3"
        let findings = Workspace.Lint.currency(
            of: manifest,
            against: heads,
            at: Self.source
        )
        let provenance = try #require(
            findings.first { $0.contains("this verdict is about the installation") }
        )
        #expect(provenance.contains(Self.source))
        #expect(
            provenance.contains(
                "6d0eb3bf33f2b4b991f154c5dcc48c6abb689e11e8bfe40773cf238e96c30b4a"
            )
        )
        #expect(provenance.contains("built 2026-08-01T12:11:24Z"))
    }

    /// A current install still says nothing at all — the provenance line
    /// rides on the refusal, and does not become per-run chatter.
    @Test
    func `a current install names no installation either`() throws {
        let manifest = try Workspace.Lint.Manifest.parse(Self.installed, label: "fixture")
        let findings = Workspace.Lint.currency(
            of: manifest,
            against: Self.matching,
            at: Self.source
        )
        #expect(!findings.contains { $0.contains(Self.source) })
    }

    /// A manifest that stopped recording an input is a refusal, not a
    /// skip: an unrecorded revision is exactly the case where a stale
    /// binary would otherwise pass.
    @Test
    func `an input absent from the manifest refuses`() throws {
        let text = Self.installed.split(separator: "\n").filter {
            !$0.hasPrefix("swift-linter-primitives=")
        }.joined(separator: "\n")
        let manifest = try Workspace.Lint.Manifest.parse(text, label: "fixture")
        let findings = Workspace.Lint.currency(
            of: manifest,
            against: Self.matching,
            at: Self.source
        )
        #expect(findings.count == 4)
        #expect(
            findings[1]
                == "  swift-linter-primitives: absent from the installed manifest, 701d4dd on main"
        )
    }

    /// The mapping and the release workflow's digest step must name the
    /// same six inputs. A rule pack added upstream and not added here
    /// would be an input the guard never checks.
    @Test
    func `every input the manifest records is covered`() throws {
        let manifest = try Workspace.Lint.Manifest.parse(Self.installed, label: "fixture")
        let covered = Swift.Set(Workspace.Lint.Currency.inputs.map(\.key))
        let recorded = Swift.Set(manifest.revisions.map(\.key))
        #expect(covered == recorded)
    }
}
