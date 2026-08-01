import Testing

@testable import Workspace_Application

/// Fixtures, never live repository state.
///
/// The gate decides whether the ecosystem's source gets rewritten, so its
/// behaviour has to be pinned to text that cannot move. A test that read
/// a real package would pass or fail according to whatever that package
/// declared this week, which is the opposite of a control.
@Suite
struct `Workspace Lint Shadow Tests` {
    typealias Shadow = Workspace.Lint.Shadow

    @Test
    func `a nested error enum is a declaration`() {
        let reading = Shadow.read(
            """
            extension Affine.Discrete.Ratio {
                public enum Error: Swift.Error, Hashable {
                    case zeroDenominator
                }
            }
            """,
            at: "Sources/A/A.swift"
        )
        #expect(reading.declarations.count == 1)
        #expect(reading.declarations.first?.name == .error)
        #expect(reading.declarations.first?.line == 2)
        #expect(reading.declarations.first?.file == "Sources/A/A.swift")
    }

    @Test(arguments: [
        ("public enum Error: Swift.Error {}", Shadow.error),
        ("typealias Error = Failure", Shadow.error),
        ("struct Sequence<Element> {}", Shadow.sequence),
        ("public final class Collection {}", Shadow.collection),
        ("protocol Error {}", Shadow.error),
        ("actor Collection {}", Shadow.collection),
        ("associatedtype Error", Shadow.error),
    ])
    func `every declaring construct is caught`(source: Swift.String, name: Shadow) {
        let reading = Shadow.read(source, at: "F.swift")
        #expect(reading.declarations.map(\.name) == [name])
    }

    @Test
    func `a generic parameter shadows`() {
        let reading = Shadow.read(
            "func decode<Error: Swift.Error>(_ value: Error) throws {}",
            at: "F.swift"
        )
        #expect(reading.declarations.map(\.name) == [.error])
    }

    @Test
    func `a generic parameter on init shadows`() {
        let reading = Shadow.read("init<Error>(_ value: Error) {}", at: "F.swift")
        #expect(reading.declarations.map(\.name) == [.error])
    }

    @Test
    func `a generic constraint is a use, not a shadow`() {
        let reading = Shadow.read(
            "func each<T: Collection>(_ values: T) -> Set<Error> { [] }",
            at: "F.swift"
        )
        #expect(reading.declarations.isEmpty)
    }

    @Test
    func `an ordinary reference is not a declaration`() {
        let reading = Shadow.read(
            """
            public struct Trap: Error, Hashable {}
            let failures: [any Error] = []
            #expect(throws: Error.self)
            """,
            at: "F.swift"
        )
        #expect(reading.declarations.isEmpty)
    }

    @Test
    func `a whole-line comment is not a declaration`() {
        let reading = Shadow.read(
            """
            /// The `enum Error` this type reports through.
            // struct Collection {}
             * enum Sequence
            """,
            at: "F.swift"
        )
        #expect(reading.declarations.isEmpty)
    }

    @Test(arguments: [
        "@_exported import Dependencies",
        "@_exported public import Dependencies",
        "@_exported import struct Dependencies.Client",
        "@_exported import Dependencies.Sub",
    ])
    func `a re-export names its module`(source: Swift.String) {
        #expect(Shadow.read(source, at: "F.swift").reexports == ["Dependencies"])
    }

    @Test
    func `a plain import is not a re-export`() {
        #expect(Shadow.read("public import Dependencies", at: "F.swift").reexports.isEmpty)
    }

    static func scan(
        _ package: Swift.String,
        declaring declarations: [Shadow] = [],
        reexporting reexports: Swift.Set<Swift.String> = [],
        providing modules: Swift.Set<Swift.String> = []
    ) -> Shadow.Scan {
        .init(
            package: package,
            declarations: declarations.enumerated().map { index, name in
                .init(
                    name: name,
                    file: "Sources/M/F.swift",
                    line: index + 1,
                    text: "public enum \(name.rawValue) {}"
                )
            },
            reexports: reexports,
            modules: modules
        )
    }

    @Test
    func `a declaring package excludes the unsafe fixer and names its site`() {
        let exclusion = Shadow.exclusion(
            for: Self.scan("/p/declares", declaring: [.error])
        )
        #expect(exclusion?.package == "/p/declares")
        #expect(exclusion?.reason.contains("`Error`") == true)
        #expect(exclusion?.reason.contains("Sources/M/F.swift:1") == true)
    }

    @Test
    func `a clean package proceeds`() {
        #expect(Shadow.exclusion(for: Self.scan("/p/clean")) == nil)
    }

    @Test
    func `a re-export of a declaring module excludes the unsafe fixer`() {
        let excluded = Shadow.exclusions(across: [
            Self.scan("/p/source", declaring: [.error], providing: ["Records"]),
            Self.scan("/p/consumer", reexporting: ["Records"], providing: ["Server"]),
            Self.scan("/p/other", providing: ["Other"]),
        ])
        #expect(excluded.map(\.package) == ["/p/source", "/p/consumer"])
        #expect(excluded[1].reason.contains("re-exports `Records`") == true)
        #expect(excluded[1].reason.contains("/p/source") == true)
    }

    @Test
    func `a re-export chain is closed transitively`() {
        let excluded = Shadow.exclusions(across: [
            Self.scan("/p/consumer", reexporting: ["Middle"], providing: ["Top"]),
            Self.scan("/p/middle", reexporting: ["Records"], providing: ["Middle"]),
            Self.scan("/p/source", declaring: [.collection], providing: ["Records"]),
        ])
        #expect(Swift.Set(excluded.map(\.package)) == ["/p/consumer", "/p/middle", "/p/source"])
    }

    @Test
    func `an unresolvable re-export excludes the unsafe fixer, not detection`() {
        let excluded = Shadow.exclusions(across: [
            Self.scan("/p/consumer", reexporting: ["Testing"], providing: ["Top"])
        ])
        #expect(excluded.map(\.package) == ["/p/consumer"])
        #expect(excluded[0].reason.contains("resolves to no package") == true)
    }

    @Test(arguments: [
        ("ASCII Primitives", "ASCII_Primitives"),
        ("Institute Linter Rule Naming", "Institute_Linter_Rule_Naming"),
        ("RFC-9110", "RFC_9110"),
        ("Already_Mangled", "Already_Mangled"),
    ])
    func `a target directory mangles to the module the compiler sees`(
        directory: Swift.String,
        module: Swift.String
    ) {
        #expect(Shadow.mangled(directory) == module)
    }

    @Test
    func `a package re-exporting only clean modules proceeds`() {
        let excluded = Shadow.exclusions(across: [
            Self.scan("/p/consumer", reexporting: ["Records"], providing: ["Top"]),
            Self.scan("/p/source", providing: ["Records"]),
        ])
        #expect(excluded.isEmpty)
    }
}
