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
    func `render uses relative application and package references`() {
        let repositories = [
            Workspace.Repository(
                name: "swift-example",
                url: "https://github.com/swift-example/swift-example.git",
                layer: .primitives
            )
        ]

        let rendered = Workspace.Xcode.render(repositories)
        let document = Workspace.Xcode.document(repositories)

        #expect(rendered.contains("group:Application"))
        #expect(rendered.contains("group:Packages/swift-example"))
        #expect(!rendered.contains("/Users/"))
        #expect(!rendered.contains("absolute:"))
        #expect(document.references.map(\.location) == [
            .group("Application"),
            .group("Packages/swift-example")
        ])
    }
}
