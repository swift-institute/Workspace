import Testing

@testable import Workspace_Application

@Suite
struct `Workspace Lint Manifest Tests` {
    /// A verbatim capture of the release's published `MANIFEST.txt`.
    static let published = """
        digest=e837b75b3cb9780cd2b48981e0a940ce1102325330dc1344c3cfe2f9c1ea1657
        engine=a109ffbd8242dc1d741619a6784064670efa0166
        swift-primitives-linter-rules=ca403273c117b97763e77b28ebb24a2bdb532d16
        swift-standards-linter-rules=66a16b020b82e84b13f9271f1088c37b70fddc75
        swift-institute-linter-rules=f2dbe5dece6de4ed3b28ea71bb04574950bd758c
        swift-linter-rules=cc96b6b6d0074e0baa18067e662f200a85ac09d2
        swift-linter-primitives=35c094f08c26245315ea47d0632a8d85de54aa1d
        built-at=2026-07-28T09:09:53Z
        swift-image=swift:6.3
        """

    /// The macOS build of the same digest. Build time and toolchain
    /// differ; every revision is identical. Parity must hold across
    /// exactly this pair, because it is the pair that exists.
    static let platform = """
        digest=e837b75b3cb9780cd2b48981e0a940ce1102325330dc1344c3cfe2f9c1ea1657
        engine=a109ffbd8242dc1d741619a6784064670efa0166
        swift-primitives-linter-rules=ca403273c117b97763e77b28ebb24a2bdb532d16
        swift-standards-linter-rules=66a16b020b82e84b13f9271f1088c37b70fddc75
        swift-institute-linter-rules=f2dbe5dece6de4ed3b28ea71bb04574950bd758c
        swift-linter-rules=cc96b6b6d0074e0baa18067e662f200a85ac09d2
        swift-linter-primitives=35c094f08c26245315ea47d0632a8d85de54aa1d
        built-at=2026-07-27T19:55:11Z
        platform=macos-arm64
        xcode=26.6
        """

    @Test
    func `parses the published manifest`() throws {
        let manifest = try Workspace.Lint.Manifest.parse(Self.published, label: "fixture")
        #expect(
            manifest.digest == "e837b75b3cb9780cd2b48981e0a940ce1102325330dc1344c3cfe2f9c1ea1657"
        )
        #expect(manifest.value(for: "engine") == "a109ffbd8242dc1d741619a6784064670efa0166")
    }

    @Test
    func `platform builds of one digest agree on every revision`() throws {
        let linux = try Workspace.Lint.Manifest.parse(Self.published, label: "linux")
        let macos = try Workspace.Lint.Manifest.parse(Self.platform, label: "macos")
        #expect(linux.digest == macos.digest)
        for entry in linux.revisions {
            #expect(macos.value(for: entry.key) == entry.value)
        }
    }

    /// Build time, toolchain, and platform legitimately differ between
    /// the two builds of one digest. Comparing them would report a
    /// divergence on every install and train people to ignore the check.
    @Test
    func `incidental build metadata is not a revision`() throws {
        let macos = try Workspace.Lint.Manifest.parse(Self.platform, label: "macos")
        let keys = macos.revisions.map(\.key)
        #expect(!keys.contains("built-at"))
        #expect(!keys.contains("platform"))
        #expect(!keys.contains("xcode"))
        #expect(keys.contains("engine"))
    }

    /// Two manifests with no digest would otherwise compare equal, and
    /// the parity check would report agreement between two builds it
    /// cannot identify.
    @Test
    func `a manifest without a digest is rejected`() {
        #expect(throws: Workspace.Error.self) {
            try Workspace.Lint.Manifest.parse(
                "engine=a109ffbd8242dc1d741619a6784064670efa0166",
                label: "fixture"
            )
        }
    }

    @Test
    func `a non-hexadecimal digest is rejected`() {
        #expect(throws: Workspace.Error.self) {
            try Workspace.Lint.Manifest.parse("digest=not-a-digest", label: "fixture")
        }
    }
}
