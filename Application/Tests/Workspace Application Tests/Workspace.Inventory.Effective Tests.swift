import File_System
import Foundation
import GitHub
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

        let (root, location) = try Self.scratchRoot()
        defer { try? FileManager.default.removeItem(at: location) }
        #expect(try left.combined.digest(at: root) == right.combined.digest(at: root))
        #expect(try left.private.digest(at: root) == right.private.digest(at: root))
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
        let (root, location) = try Self.scratchRoot()
        defer { try? FileManager.default.removeItem(at: location) }

        let publicDigest = try effective.public.digest(at: root)
        let privateDigest = try effective.private.digest(at: root)
        let combinedDigest = try effective.combined.digest(at: root)

        for digest in [publicDigest, privateDigest, combinedDigest] {
            #expect(digest.count == 64)
            #expect(digest.allSatisfy(\.isHexDigit))
        }
        #expect(Set([publicDigest, privateDigest, combinedDigest]).count == 3)
    }

    private static func scratchRoot() throws -> (Workspace.Root, URL) {
        let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        let directory = try File.Directory(validating: location.path)
        return (try Workspace.Root(checkout: directory), location)
    }
}
