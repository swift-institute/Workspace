import File_System
import Foundation
import Testing

@testable import Workspace_Application

extension Workspace.Sync {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Workspace.Sync.Test.Integration {
    @Test
    func `Dry run changes neither repository metadata nor files`() throws {
        let fixture = try Workspace.Sync.Fixture()
        defer { fixture.remove() }
        try fixture.push("second", contents: "second\n")
        let before = try fixture.state()

        try fixture.application().run(dry: true)

        #expect(try fixture.state() == before)
        #expect(try fixture.residue().isEmpty)
    }

    @Test
    func `Force pushed remote leaves local repository untouched`() throws {
        let fixture = try Workspace.Sync.Fixture()
        defer { fixture.remove() }
        try fixture.replaceRemote()
        let before = try fixture.state()

        try fixture.application().run(dry: false)

        #expect(try fixture.state() == before)
        #expect(try fixture.residue().isEmpty)
    }

    @Test
    func `A resolved selection clones only its authority repository and renders only that reference`() throws {
        let fixture = try Workspace.Sync.Fixture()
        defer { fixture.remove() }
        let selected = Workspace.Repository(
            name: "swift-rfc-0000",
            url: fixture.remote.path,
            organization: "swift-ietf",
            layer: .standards
        )
        let unselected = Workspace.Repository(
            name: "swift-unused",
            url: "https://github.com/swift-foundations/swift-unused.git",
            organization: "swift-foundations",
            layer: .foundations
        )
        let root = try File.Directory(validating: fixture.root.path)
        let sync = Workspace.Sync(
            root: root,
            selection: .init(repositories: [selected]),
            client: fixture.client
        )

        try sync.run(dry: false)

        let cloned = fixture.root.appending(
            path: "swift-standards/swift-ietf/swift-rfc-0000/.git"
        )
        #expect(FileManager.default.fileExists(atPath: cloned.path))
        let excluded = fixture.root.appending(
            path: Workspace.Layout.reference(for: unselected)
        )
        #expect(!FileManager.default.fileExists(atPath: excluded.path))
        let workspace = try #require(Workspace.Xcode.contents(at: root))
        #expect(workspace.contains(Workspace.Layout.reference(for: selected)))
        #expect(!workspace.contains(Workspace.Layout.reference(for: unselected)))
    }

    @Test
    func `Proven descendant fast forwards local main`() throws {
        let fixture = try Workspace.Sync.Fixture()
        defer { fixture.remove() }
        try fixture.push("second", contents: "second\n")
        let before = try fixture.state()

        try fixture.application().run(dry: false)

        let after = try fixture.state()
        #expect(after.head != before.head)
        #expect(after.head == after.origin)
        #expect(after.status.isEmpty)
        #expect(try fixture.residue().isEmpty)
    }
}
