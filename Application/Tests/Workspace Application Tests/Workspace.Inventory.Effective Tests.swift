import File_System
import Foundation
import GitHub
import JSON
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Workspace_Application

extension Workspace.Inventory.Test.Unit {
    @Test
    func `Effective combines the committed public roster with a live private discovery`() throws {
        let publicConfiguration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: "swift-alpha-primitives",
                    url: "https://github.com/swift-primitives/swift-alpha-primitives.git",
                    organization: "swift-primitives",
                    layer: .primitives
                )
            ]
        )
        let discovery = Workspace.Inventory.Private.Discovery(
            repositories: [
                .init(
                    id: .init(1),
                    key: .init(owner: .init("swift-foundations"), name: .init("swift-private-package")),
                    layer: .foundations
                )
            ],
            exclusions: [],
            unmeasured: []
        )

        let effective = try Workspace.Inventory.Effective(
            public: publicConfiguration,
            private: discovery
        )

        #expect(effective.public.repositories.map(\.name) == ["swift-alpha-primitives"])
        #expect(effective.private.repositories.map(\.name) == ["swift-private-package"])
        #expect(
            effective.combined.repositories.map(\.name)
                == ["swift-alpha-primitives", "swift-private-package"]
        )
        // `private` never carries the public repository, and `combined`
        // carries both — the two "separate safe digests plus one effective
        // combined digest" the acceptance predicate requires are therefore
        // over genuinely different populations, not the same content twice.
        #expect(effective.public.repositories.count == 1)
        #expect(effective.private.repositories.count == 1)
        #expect(effective.combined.repositories.count == 2)
    }

    @Test
    func `A private repository name colliding with a different public owner fails closed`() {
        let publicConfiguration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: "swift-shared-name",
                    url: "https://github.com/swift-primitives/swift-shared-name.git",
                    organization: "swift-primitives",
                    layer: .primitives
                )
            ]
        )
        let discovery = Workspace.Inventory.Private.Discovery(
            repositories: [
                .init(
                    id: .init(1),
                    key: .init(owner: .init("swift-foundations"), name: .init("swift-shared-name")),
                    layer: .foundations
                )
            ],
            exclusions: [],
            unmeasured: []
        )

        #expect(throws: Workspace.Inventory.Effective.Error.self) {
            _ = try Workspace.Inventory.Effective(public: publicConfiguration, private: discovery)
        }
    }

    /// Positive control: "Run generation from two different starting file
    /// orders; canonical output/digest match." The public roster is fixed;
    /// only the *order* the private pass observed its two repositories in
    /// differs between the two `Effective` values under comparison.
    @Test
    func `Combined output is byte-identical regardless of private discovery order`() throws {
        let publicConfiguration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let first = Workspace.Inventory.Repository(
            id: .init(1),
            key: .init(owner: .init("swift-foundations"), name: .init("swift-alpha")),
            layer: .foundations
        )
        let second = Workspace.Inventory.Repository(
            id: .init(2),
            key: .init(owner: .init("swift-foundations"), name: .init("swift-beta")),
            layer: .foundations
        )

        let left = try Workspace.Inventory.Effective(
            public: publicConfiguration,
            private: .init(repositories: [second, first], exclusions: [], unmeasured: [])
        )
        let right = try Workspace.Inventory.Effective(
            public: publicConfiguration,
            private: .init(repositories: [first, second], exclusions: [], unmeasured: [])
        )

        #expect(left.private.repositories == right.private.repositories)
        #expect(left.combined.canonical == right.combined.canonical)

        #expect(left.combined.digest == right.combined.digest)
        #expect(left.private.digest == right.private.digest)
    }

    @Test
    func `Public, private, and combined digest independently and differ when content differs`()
        throws
    {
        let publicConfiguration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: "swift-alpha-primitives",
                    url: "https://github.com/swift-primitives/swift-alpha-primitives.git",
                    organization: "swift-primitives",
                    layer: .primitives
                )
            ]
        )
        let discovery = Workspace.Inventory.Private.Discovery(
            repositories: [
                .init(
                    id: .init(1),
                    key: .init(owner: .init("swift-foundations"), name: .init("swift-private-package")),
                    layer: .foundations
                )
            ],
            exclusions: [],
            unmeasured: []
        )
        let effective = try Workspace.Inventory.Effective(public: publicConfiguration, private: discovery)
        let publicDigest = effective.public.digest
        let privateDigest = effective.private.digest
        let combinedDigest = effective.combined.digest

        for digest in [publicDigest, privateDigest, combinedDigest] {
            #expect(digest.count == 64)
            let isLowercaseHex = digest.allSatisfy(\.isHexDigit)
            #expect(isLowercaseHex)
        }
        #expect(Set([publicDigest, privateDigest, combinedDigest]).count == 3)
    }

    @Test
    func `Output for public scope marks the private limb not-requested and exits complete`()
        throws
    {
        let effective = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            private: .init(repositories: [], exclusions: [], unmeasured: [])
        )

        let output = Workspace.Inventory.Effective.Output(
            scope: .public,
            effective: effective,
            unmeasured: []
        )

        #expect(output.private == nil)
        #expect(output.exitCode == 0)
        #expect(output.canonical.contains(#""private":{"status":"not-requested"}"#))
        #expect(output.canonical.contains(#""schemaVersion":1"#))
        #expect(!output.canonical.contains("\n"))
    }

    @Test
    func `Output is byte-identical across two runs over identical inputs`() throws {
        func report() throws -> Workspace.Inventory.Effective.Output {
            let effective = try Workspace.Inventory.Effective(
                public: Self.publicConfiguration,
                private: Self.privateDiscovery
            )
            return .init(
                scope: .effective,
                effective: effective,
                unmeasured: []
            )
        }

        #expect(try report().canonical == report().canonical)
    }

    @Test
    func `Changed input changes the combined digest and the report bytes`() throws {
        let one = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            private: Self.privateDiscovery
        )
        let two = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            private: .init(repositories: [], exclusions: [], unmeasured: [])
        )

        let first = Workspace.Inventory.Effective.Output(
            scope: .effective, effective: one, unmeasured: []
        )
        let second = Workspace.Inventory.Effective.Output(
            scope: .effective, effective: two, unmeasured: []
        )

        #expect(first.combined.digest != second.combined.digest)
        #expect(first.canonical != second.canonical)
        #expect(first.public.digest == second.public.digest)
    }

    @Test
    func `Unmeasured residue is carried as typed rows and exits UNMEASURED`() throws {
        let effective = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            private: .init(repositories: [], exclusions: [], unmeasured: [])
        )

        let output = Workspace.Inventory.Effective.Output(
            scope: .effective,
            effective: effective,
            unmeasured: [
                .init(scope: .organization(.init("swift-foundations")), reason: "listing failed"),
                .init(
                    scope: .repository(
                        .init(owner: .init("swift-foundations"), name: .init("swift-private"))
                    ),
                    reason: "content read failed"
                ),
            ]
        )

        #expect(output.exitCode == 2)
        #expect(output.unmeasured.count == 2)
        #expect(output.unmeasured[0].kind == .organization)
        #expect(output.unmeasured[0].coordinate == "swift-foundations")
        #expect(output.unmeasured[1].kind == .repository)
        #expect(output.unmeasured[1].coordinate == "swift-foundations/swift-private")
        // The absence is typed and recorded, never invented away.
        #expect(output.canonical.contains(#""kind":"organization""#))
        #expect(output.canonical.contains(#""reason":"listing failed""#))
    }

    @Test
    func `Output round-trips through its own serialization`() throws {
        let effective = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            private: Self.privateDiscovery
        )
        let output = Workspace.Inventory.Effective.Output(
            scope: .effective,
            effective: effective,
            unmeasured: [.init(scope: .organization(.init("swift-standards")), reason: "denied")]
        )

        let decoded = try Workspace.Inventory.Effective.Output(jsonString: output.canonical)

        #expect(decoded == output)
        #expect(decoded.canonical == output.canonical)
    }

    @Test
    func `Writer lands canonical LF-terminated bytes at owner-only permissions`() throws {
        let (_, location) = try Self.scratchRoot()
        defer { try? FileManager.default.removeItem(at: location) }
        let effective = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            private: .init(repositories: [], exclusions: [], unmeasured: [])
        )
        let output = Workspace.Inventory.Effective.Output(
            scope: .public, effective: effective, unmeasured: []
        )
        let destination = location.appending(path: "effective.json")
        let path = try File.Path(destination.path)

        try output.write(to: path)
        // Idempotent over an existing regular file: the atomic replace runs
        // again rather than refusing its own previous output.
        try output.write(to: path)

        let bytes = try Data(contentsOf: destination)
        #expect(Swift.String(decoding: bytes, as: Swift.UTF8.self) == output.canonical + "\n")
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        #expect((attributes[.posixPermissions] as? Swift.Int) == 0o600)
    }

    @Test
    func `Writer refuses a symlink target`() throws {
        let (_, location) = try Self.scratchRoot()
        defer { try? FileManager.default.removeItem(at: location) }
        let effective = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            private: .init(repositories: [], exclusions: [], unmeasured: [])
        )
        let output = Workspace.Inventory.Effective.Output(
            scope: .public, effective: effective, unmeasured: []
        )
        let real = location.appending(path: "elsewhere.json")
        try Data().write(to: real)
        let link = location.appending(path: "link.json")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: real
        )

        #expect(throws: Workspace.Error.self) {
            try output.write(to: try File.Path(link.path))
        }
        // A dangling link is refused too, not silently replaced.
        let dangling = location.appending(path: "dangling.json")
        try FileManager.default.createSymbolicLink(
            at: dangling,
            withDestinationURL: location.appending(path: "missing.json")
        )
        #expect(throws: Workspace.Error.self) {
            try output.write(to: try File.Path(dangling.path))
        }
    }

    @Test
    func `Writer refuses a pre-existing non-regular target`() throws {
        let (_, location) = try Self.scratchRoot()
        defer { try? FileManager.default.removeItem(at: location) }
        let effective = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            private: .init(repositories: [], exclusions: [], unmeasured: [])
        )
        let output = Workspace.Inventory.Effective.Output(
            scope: .public, effective: effective, unmeasured: []
        )
        let directory = location.appending(path: "directory.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        #expect(throws: Workspace.Error.self) {
            try output.write(to: try File.Path(directory.path))
        }
    }

    private static var publicConfiguration: Workspace.Configuration {
        .init(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: "swift-alpha-primitives",
                    url: "https://github.com/swift-primitives/swift-alpha-primitives.git",
                    organization: "swift-primitives",
                    layer: .primitives
                )
            ]
        )
    }

    private static var privateDiscovery: Workspace.Inventory.Private.Discovery {
        .init(
            repositories: [
                .init(
                    id: .init(1),
                    key: .init(
                        owner: .init("swift-foundations"),
                        name: .init("swift-private-package")
                    ),
                    layer: .foundations
                )
            ],
            exclusions: [],
            unmeasured: []
        )
    }


}

extension Workspace.Inventory.Test.Unit {
    @Test
    func `A supplied roster digests identically to the live pass over the same population`()
        throws
    {
        let configuration = Self.publicConfiguration
        let live = try Workspace.Inventory.Effective(
            public: configuration,
            private: Self.privateDiscovery
        )
        let supplied = try Workspace.Inventory.Effective(
            public: configuration,
            roster: .init(
                repositories: [
                    .init(
                        owner: .init("swift-foundations"),
                        name: .init("swift-private-package")
                    )
                ],
                unmeasured: []
            ),
            policy: .institute()
        )

        // The comparability claim, made mechanically: a roster-derived
        // digest is only useful if it equals what a live pass over the same
        // population would have produced.
        #expect(live.combined.canonical == supplied.combined.canonical)
        #expect(live.combined.digest == supplied.combined.digest)
        #expect(live.private.digest == supplied.private.digest)
    }

    @Test
    func `A permuted roster digests identically`() throws {
        let rows: [Workspace.Repository.Key] = [
            .init(owner: .init("swift-foundations"), name: .init("swift-a")),
            .init(owner: .init("swift-primitives"), name: .init("swift-b")),
            .init(owner: .init("swift-standards"), name: .init("swift-c")),
        ]
        let forward = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            roster: .init(repositories: rows, unmeasured: []),
            policy: .institute()
        )
        let reversed = try Workspace.Inventory.Effective(
            public: Self.publicConfiguration,
            roster: .init(repositories: rows.reversed(), unmeasured: []),
            policy: .institute()
        )

        // Order is canonicalized, never semantic: `Effective` sorts by
        // (layer order, owner/name) on the way in, so the caller's
        // enumeration order — which for the sweep is whatever order eight
        // concurrent org listings happened to return — cannot change the
        // digest.
        #expect(forward.combined.canonical == reversed.combined.canonical)
        #expect(forward.combined.digest == reversed.combined.digest)
    }

    @Test
    func `An empty roster is refused rather than digested`() throws {
        let (_, location) = try Self.scratchRoot()
        defer { try? FileManager.default.removeItem(at: location) }
        let file = location.appending(path: "roster.json")
        try Data(#"{"schemaVersion":1,"repositories":[],"unmeasured":[]}"#.utf8).write(to: file)

        #expect(throws: Workspace.Inventory.Effective.Roster.Error.emptyPopulation) {
            try Workspace.Inventory.Effective.Roster.read(File.Path(file.path))
        }
    }

    @Test
    func `A roster file round-trips and carries its unmeasured residue`() throws {
        let (_, location) = try Self.scratchRoot()
        defer { try? FileManager.default.removeItem(at: location) }
        let file = location.appending(path: "roster.json")
        let roster = Workspace.Inventory.Effective.Roster(
            repositories: [
                .init(owner: .init("swift-foundations"), name: .init("swift-private-package"))
            ],
            unmeasured: [
                .init(kind: .organization, coordinate: "swift-ietf", reason: "listing failed")
            ]
        )
        try Data(roster.json.serialize(sortKeys: true).utf8).write(to: file)

        let read = try Workspace.Inventory.Effective.Roster.read(File.Path(file.path))
        #expect(read == roster)
        // A caller that could not list an organization says so, and the
        // report publishes it — an incomplete roster cannot pass itself off
        // as a complete population.
        #expect(read.unmeasured.count == 1)
    }

    @Test
    func `A coordinate outside the policy's organizations is refused`() throws {
        #expect(throws: Workspace.Inventory.Effective.Error.self) {
            try Workspace.Inventory.Effective(
                public: Self.publicConfiguration,
                roster: .init(
                    repositories: [.init(owner: .init("some-other-org"), name: .init("swift-x"))],
                    unmeasured: []
                ),
                policy: .institute()
            )
        }
    }

    @Test
    func `A malformed roster is a typed refusal, not an empty population`() throws {
        let (_, location) = try Self.scratchRoot()
        defer { try? FileManager.default.removeItem(at: location) }
        let file = location.appending(path: "roster.json")
        try Data(#"{"schemaVersion":2,"repositories":[]}"#.utf8).write(to: file)

        #expect(throws: Workspace.Inventory.Effective.Roster.Error.self) {
            try Workspace.Inventory.Effective.Roster.read(File.Path(file.path))
        }
    }
}

extension Workspace.Inventory.Test.Unit {
    private static func scratchRoot() throws -> (Workspace.Root, URL) {
        let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        let directory = try File.Directory(validating: location.path)
        return (try Workspace.Root(checkout: directory), location)
    }
}
