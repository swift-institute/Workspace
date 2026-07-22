import Testing

@testable import workspace

@Test
func rendersRelativeReferences() {
    let repositories = [
        Workspace.Repository(
            name: "swift-example",
            url: "https://github.com/swift-example/swift-example.git",
            layer: .primitives
        )
    ]
    let rendered = Workspace.Xcode.render(repositories)
    #expect(rendered.contains("group:Packages/swift-example"))
    #expect(!rendered.contains("/Users/"))
    #expect(!rendered.contains("absolute:"))
}
