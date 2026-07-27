import File_System
import Foundation
import Testing

@testable import Workspace_Application

extension Workspace.Composition {
    @Suite
    struct Test {
        @Suite struct Integration {}
        @Suite struct `Edge Case` {}
    }
}

extension Workspace.Composition.Test {
    /// A throwaway workspace: a consumer package declaring one URL dependency,
    /// and that dependency present at its org-layout checkout.
    struct Fixture {
        let base: URL
        let root: URL
        let manifest: URL
        let composition: Workspace.Composition

        init() throws {
            let temporary =
                FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            let checkout = temporary.appending(path: "Workspace")
            try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
            let workspaceRoot = try Workspace.Root(
                checkout: File.Directory(validating: checkout.path)
            )
            base = URL(
                fileURLWithPath: workspaceRoot.hierarchy.description,
                isDirectory: true
            )
            root = URL(
                fileURLWithPath: workspaceRoot.checkout.description,
                isDirectory: true
            )
            manifest = base.appending(path: "swift-foundations/example/consumer/Package.swift")

            try FileManager.default.createDirectory(
                at: base.appending(path: "swift-foundations/example/consumer"),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: base.appending(path: "swift-standards/example/swift-dep"),
                withIntermediateDirectories: true
            )
            // A workspace repository present on disk but NOT declared by the
            // consumer manifest — the "nothing to compose" case.
            try FileManager.default.createDirectory(
                at: base.appending(path: "swift-standards/example/swift-other"),
                withIntermediateDirectories: true
            )
            try Self.manifestSource.write(to: manifest, atomically: true, encoding: .utf8)

            composition = Workspace.Composition(
                root: workspaceRoot,
                configuration: .init(
                    version: 1,
                    scope: "example",
                    swift: "6.3.3",
                    xcode: "26.6",
                    repositories: [
                        .init(
                            name: "consumer",
                            url: "https://github.com/example/consumer.git",
                            organization: "example",
                            layer: .foundations
                        ),
                        .init(
                            name: "swift-dep",
                            url: "https://github.com/example/swift-dep.git",
                            organization: "example",
                            layer: .standards
                        ),
                        .init(
                            name: "swift-other",
                            url: "https://github.com/example/swift-other.git",
                            organization: "example",
                            layer: .standards
                        ),
                    ]
                )
            )
        }

        // Stays in the type body deliberately. [API-IMPL-008] would move this
        // to an extension, but `Fixture` is nested inside the `@Suite` type
        // `Workspace.Composition.Test`, and [API-ERR-001]'s `@Suite`-member
        // exemption for bare `throws` does not follow a member out into an
        // extension. `Swift.String(contentsOf:encoding:)` throws untyped, so
        // there is no `E` to name and no typed form that satisfies both rules.
        func read() throws -> Swift.String {
            try Swift.String(contentsOf: manifest, encoding: .utf8)
        }
    }
}

extension Workspace.Composition.Test.Fixture {
    static let manifestSource = """
        // swift-tools-version: 6.3.3
        import PackageDescription

        let package = Package(
            name: "consumer",
            dependencies: [
                .package(url: "https://github.com/example/swift-dep.git", branch: "main")
            ],
            targets: []
        )

        """

    func remove() { try? FileManager.default.removeItem(at: base) }
}

extension Workspace.Composition.Test.Integration {
    @Test
    func `compose rewrites the manifest to a local path and records it`() throws {
        let fixture = try Workspace.Composition.Test.Fixture()
        defer { fixture.remove() }

        try fixture.composition.compose(consumer: "consumer", dependency: "swift-dep")

        let rewritten = try fixture.read()
        #expect(
            rewritten.contains(
                ".package(path: \"\(fixture.composition.root.hierarchy)/swift-standards/example/swift-dep\")"
            )
        )
        #expect(!rewritten.contains("https://github.com/example/swift-dep.git"))

        let ledger = try Workspace.Composition.State.load(
            at: File.Directory(validating: fixture.root.path)
        )
        #expect(ledger.record(consumer: "consumer", dependency: "swift-dep") != nil)
    }

    @Test
    func `restore returns the manifest byte-for-byte and clears the ledger`() throws {
        let fixture = try Workspace.Composition.Test.Fixture()
        defer { fixture.remove() }

        let original = try fixture.read()
        try fixture.composition.compose(consumer: "consumer", dependency: "swift-dep")
        try fixture.composition.restore(consumer: "consumer", dependency: "swift-dep")

        #expect(try fixture.read() == original)

        let ledger = try Workspace.Composition.State.load(
            at: File.Directory(validating: fixture.root.path)
        )
        #expect(ledger.records.isEmpty)
    }
}

extension Workspace.Composition.Test.`Edge Case` {
    @Test
    func `composing a dependency the manifest does not declare throws`() throws {
        let fixture = try Workspace.Composition.Test.Fixture()
        defer { fixture.remove() }

        // `swift-other` is a workspace repo present on disk, but the consumer
        // manifest declares no dependency on it — nothing to compose.
        #expect(throws: Workspace.Error.self) {
            try fixture.composition.compose(consumer: "consumer", dependency: "swift-other")
        }
    }

    @Test
    func `double compose throws`() throws {
        let fixture = try Workspace.Composition.Test.Fixture()
        defer { fixture.remove() }

        try fixture.composition.compose(consumer: "consumer", dependency: "swift-dep")
        #expect(throws: Workspace.Error.self) {
            try fixture.composition.compose(consumer: "consumer", dependency: "swift-dep")
        }
    }

    @Test
    func `restore without an active composition throws`() throws {
        let fixture = try Workspace.Composition.Test.Fixture()
        defer { fixture.remove() }

        #expect(throws: Workspace.Error.self) {
            try fixture.composition.restore(consumer: "consumer", dependency: "swift-dep")
        }
    }

    @Test
    func `verify without resolved state throws`() throws {
        let fixture = try Workspace.Composition.Test.Fixture()
        defer { fixture.remove() }

        #expect(throws: Workspace.Error.self) {
            try fixture.composition.verify(consumer: "consumer", dependency: "swift-dep")
        }
    }

    @Test
    func `a non-workspace repository throws`() throws {
        let fixture = try Workspace.Composition.Test.Fixture()
        defer { fixture.remove() }

        #expect(throws: Workspace.Error.self) {
            try fixture.composition.compose(consumer: "consumer", dependency: "unknown")
        }
    }
}
