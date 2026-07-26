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
    func `A missing authority repository clones at its nested layout location`() throws {
        let fixture = try Workspace.Sync.Fixture()
        defer { fixture.remove() }
        let sync = Workspace.Sync(
            root: try File.Directory(validating: fixture.root.path),
            configuration: .init(
                version: 1,
                scope: "swift-institute",
                swift: "6.3",
                xcode: "26.0",
                repositories: [
                    .init(
                        name: "swift-rfc-0000",
                        url: fixture.remote.path,
                        organization: "swift-ietf",
                        layer: .standards
                    )
                ]
            ),
            client: fixture.client
        )

        try sync.run(dry: false)

        let cloned = fixture.root.appending(
            path: "swift-standards/swift-ietf/swift-rfc-0000/.git"
        )
        #expect(FileManager.default.fileExists(atPath: cloned.path))
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
