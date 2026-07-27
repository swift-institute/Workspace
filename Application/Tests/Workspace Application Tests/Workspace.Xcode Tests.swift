import File_System
import Foundation
import Testing
import Xcode_Workspace_Standard

@testable import Workspace_Application

extension Workspace.Xcode {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Workspace.Xcode.Test.Unit {
    @Test
    func `render terminates the workspace artifact with one line feed`() {
        let rendered = Workspace.Xcode.render([])

        #expect(Data(rendered.utf8).last == 0x0A)
        #expect(rendered.hasSuffix("</Workspace>\n"))
    }

    @Test
    func `render uses checkout relative application and sibling hierarchy package references`() {
        let repositories = [
            Workspace.Repository(
                name: "swift-example",
                url: "https://github.com/swift-primitives/swift-example.git",
                organization: "swift-primitives",
                layer: .primitives
            ),
            Workspace.Repository(
                name: "swift-rfc-0000",
                url: "https://github.com/swift-ietf/swift-rfc-0000.git",
                organization: "swift-ietf",
                layer: .standards
            ),
        ]

        let rendered = Workspace.Xcode.render(repositories)
        let document = Workspace.Xcode.document(repositories)

        #expect(rendered.contains("group:Application"))
        #expect(rendered.contains("group:../swift-primitives/swift-example"))
        #expect(rendered.contains("group:../swift-standards/swift-ietf/swift-rfc-0000"))
        #expect(!rendered.contains("/Users/"))
        #expect(!rendered.contains("absolute:"))
        #expect(
            document.references.map(\.location) == [
                .group("Application"),
                .group("../swift-primitives/swift-example"),
                .group("../swift-standards/swift-ietf/swift-rfc-0000"),
            ]
        )
    }
}

extension Workspace.Xcode.Test.Integration {
    @Test
    func `write keeps the generated workspace inside the checkout while references leave for sibling packages`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let checkout = base.appending(path: "Workspace")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        let root = try File.Directory(validating: checkout.path)
        let repositories = [
            Workspace.Repository(
                name: "swift-example",
                url: "https://github.com/swift-foundations/swift-example.git",
                organization: "swift-foundations",
                layer: .foundations
            ),
        ]

        try Workspace.Xcode.write(repositories, at: root)

        let generated = checkout.appending(path: "institute.xcworkspace/contents.xcworkspacedata")
        #expect(FileManager.default.fileExists(atPath: generated.path))
        #expect(!FileManager.default.fileExists(atPath: base.appending(path: "institute.xcworkspace").path))
        #expect(try Data(contentsOf: generated) == Data(Workspace.Xcode.render(repositories).utf8))
        #expect(Workspace.Xcode.current(repositories, at: root))
        #expect(try #require(Workspace.Xcode.contents(at: root)).contains("../swift-foundations/swift-example"))
    }
}
