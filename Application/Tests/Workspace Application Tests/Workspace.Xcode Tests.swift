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
    func `render uses relative application and org-layout package references`() {
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
        #expect(rendered.contains("group:swift-primitives/swift-example"))
        #expect(rendered.contains("group:swift-standards/swift-ietf/swift-rfc-0000"))
        #expect(!rendered.contains("/Users/"))
        #expect(!rendered.contains("absolute:"))
        #expect(
            document.references.map(\.location) == [
                .group("Application"),
                .group("swift-primitives/swift-example"),
                .group("swift-standards/swift-ietf/swift-rfc-0000"),
            ]
        )
    }
}
