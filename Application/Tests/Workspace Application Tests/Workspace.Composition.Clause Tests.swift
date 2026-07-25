import Testing

@testable import Workspace_Application

extension Workspace.Composition.Clause {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Workspace.Composition.Clause.Test.Unit {
    private typealias Clause = Workspace.Composition.Clause

    private static let manifest = """
        // swift-tools-version: 6.3.3
        import PackageDescription

        let package = Package(
            name: "consumer",
            dependencies: [
                .package(url: "https://github.com/foo/swift-alpha.git", branch: "main"),
                .package(url: "https://github.com/foo/swift-beta.git", .upToNextMajor(from: "1.0.0")),
                .package(path: "../swift-gamma")
            ],
            targets: []
        )
        """

    @Test
    func `all finds every package clause in source order`() {
        let clauses = Clause.all(in: Self.manifest)
        #expect(clauses.count == 3)
        #expect(clauses[0].declaredURL == "https://github.com/foo/swift-alpha.git")
        #expect(clauses[1].declaredURL == "https://github.com/foo/swift-beta.git")
        #expect(clauses[2].declaredPath == "../swift-gamma")
    }

    @Test
    func `nested parentheses in a requirement do not close the clause early`() {
        let clauses = Clause.all(in: Self.manifest)
        #expect(clauses[1].text.hasSuffix("(from: \"1.0.0\"))"))
        #expect(clauses[1].declaredURL == "https://github.com/foo/swift-beta.git")
    }

    @Test
    func `url locates the clause by derived identity`() {
        let clause = Clause.url(identity: "swift-beta", in: Self.manifest)
        #expect(clause?.declaredURL == "https://github.com/foo/swift-beta.git")
    }

    @Test
    func `url returns nil when no dependency has that identity`() {
        #expect(Clause.url(identity: "swift-delta", in: Self.manifest) == nil)
    }

    @Test(arguments: [
        ("https://github.com/foo/swift-alpha.git", "swift-alpha"),
        ("https://github.com/foo/swift-alpha", "swift-alpha"),
        ("https://github.com/foo/swift-alpha.git/", "swift-alpha"),
        ("https://github.com/Foo/Swift-Alpha.git", "swift-alpha"),
    ])
    func `identity derivation strips git, slash, and case`(
        url: Swift.String,
        expected: Swift.String
    ) {
        #expect(Clause.identity(ofURL: url) == expected)
    }

    @Test
    func `compose then restore is byte-identical`() {
        let original = Self.manifest
        let clause = Clause.url(identity: "swift-alpha", in: original)!
        let planned = ".package(path: \"/abs/Packages/swift-alpha\")"

        let composed = clause.replacing(with: planned, in: original)
        #expect(composed.contains(planned))
        #expect(!composed.contains("https://github.com/foo/swift-alpha.git"))

        let composedClause = Clause.all(in: composed).first { $0.text == planned }!
        let restored = composedClause.replacing(with: clause.text, in: composed)
        #expect(restored == original)
    }
}

extension Workspace.Composition.Clause.Test.`Edge Case` {
    private typealias Clause = Workspace.Composition.Clause

    @Test
    func `a parenthesis inside a quoted path does not truncate the clause`() {
        let source = "deps: [.package(path: \"/tmp/a(b)/swift-x\")]"
        let clause = Clause.all(in: source).first
        #expect(clause?.declaredPath == "/tmp/a(b)/swift-x")
        #expect(clause?.text == ".package(path: \"/tmp/a(b)/swift-x\")")
    }

    @Test
    func `unbalanced parentheses stop enumeration without trapping`() {
        let source = ".package(url: \"https://example.com/x.git\""
        #expect(Clause.all(in: source).isEmpty)
    }

    @Test
    func `a url clause reports no declared path and a path clause no declared url`() {
        let url = Clause.all(in: ".package(url: \"https://e.com/x.git\", branch: \"main\")").first
        #expect(url?.declaredPath == nil)
        let path = Clause.all(in: ".package(path: \"/x\")").first
        #expect(path?.declaredURL == nil)
    }
}
