import File_System
import SPM_Standard
import Testing

@testable import Workspace_Application

extension Workspace.Lint.Target {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Workspace.Lint.Target.Test.Unit {
    @Test
    func `declared target kinds resolve to their SwiftPM roots`() throws {
        let package = File.Directory("/fixture/package")
        let roots = try Workspace.Lint.Target.roots(
            [
                .init(name: .init(_unchecked: "Library"), kind: .regular),
                .init(name: .init(_unchecked: "Tool"), kind: .executable),
                .init(name: .init(_unchecked: "Library Tests"), kind: .test),
                .init(name: .init(_unchecked: "Generator"), kind: .plugin),
                .init(name: .init(_unchecked: "Macros"), kind: .macro),
                .init(name: .init(_unchecked: "CLibrary"), kind: .system),
                .init(name: .init(_unchecked: "Artifact"), kind: .binary, path: "Artifact.zip"),
            ],
            at: package
        )

        #expect(
            roots.map(\.description) == [
                "/fixture/package/Sources/Library",
                "/fixture/package/Sources/Tool",
                "/fixture/package/Tests/Library Tests",
                "/fixture/package/Plugins/Generator",
                "/fixture/package/Sources/Macros",
                "/fixture/package/Sources/CLibrary",
            ]
        )
    }

    @Test
    func `explicit target paths win without admitting neighboring trees`() throws {
        let package = File.Directory("/fixture/package")
        let roots = try Workspace.Lint.Target.roots(
            [
                .init(
                    name: .init(_unchecked: "Library"),
                    kind: .regular,
                    path: "Code/Library"
                ),
                .init(
                    name: .init(_unchecked: "Declared Tests"),
                    kind: .test,
                    path: "Tests/Declared"
                ),
            ],
            at: package
        )
        let paths = roots.map(\.description)

        #expect(paths == ["/fixture/package/Code/Library", "/fixture/package/Tests/Declared"])
        #expect(!paths.contains("/fixture/package/Scripts"))
        #expect(!paths.contains("/fixture/package/Experiments"))
        #expect(!paths.contains("/fixture/package/Research"))
        #expect(!paths.contains("/fixture/package/Tests/Undeclared"))
    }
}

extension Workspace.Lint.Target.Test.`Edge Case` {
    @Test
    func `a package-root target makes the whole package declared scope`() throws {
        let package = File.Directory("/fixture/package")
        let roots = try Workspace.Lint.Target.roots(
            [
                .init(name: .init(_unchecked: "Package"), kind: .regular, path: ".")
            ],
            at: package
        )

        #expect(roots.map(\.description) == ["/fixture/package"])
    }

    @Test
    func `duplicate declared roots are scanned once`() throws {
        let package = File.Directory("/fixture/package")
        let roots = try Workspace.Lint.Target.roots(
            [
                .init(name: .init(_unchecked: "One"), kind: .regular, path: "Sources/Shared"),
                .init(name: .init(_unchecked: "Two"), kind: .regular, path: "Sources/Shared"),
            ],
            at: package
        )

        #expect(roots.map(\.description) == ["/fixture/package/Sources/Shared"])
    }

    @Test
    func `absolute and escaping target paths are refused`() throws {
        let package = File.Directory("/fixture/package")

        #expect(throws: Workspace.Error.self) {
            try Workspace.Lint.Target.roots(
                [.init(name: .init(_unchecked: "Absolute"), kind: .regular, path: "/outside")],
                at: package
            )
        }
        #expect(throws: Workspace.Error.self) {
            try Workspace.Lint.Target.roots(
                [.init(name: .init(_unchecked: "Escape"), kind: .regular, path: "../outside")],
                at: package
            )
        }
    }
}
