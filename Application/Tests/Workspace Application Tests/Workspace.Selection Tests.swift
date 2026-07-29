import File_System
import Foundation
import JSON
import Testing

@testable import Workspace_Application

extension Workspace.Selection {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Workspace.Selection.Test {
    static var inventory: Workspace.Configuration {
        .init(
            version: 1,
            scope: "test",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                repository(owner: "swift-foundations", name: "swift-color", layer: .foundations),
                repository(
                    owner: "swift-foundations",
                    name: "swift-unselected",
                    layer: .foundations
                ),
                repository(
                    owner: "swift-primitives",
                    name: "swift-dimension-primitives",
                    layer: .primitives
                ),
            ]
        )
    }

    static func key(
        owner: Swift.String,
        name: Swift.String
    ) -> Workspace.Repository.Key {
        .init(owner: .init(owner), name: .init(name))
    }

    static func repository(
        owner: Swift.String,
        name: Swift.String,
        layer: Workspace.Layer
    ) -> Workspace.Repository {
        let key = key(owner: owner, name: name)
        return .init(
            name: key.name.underlying,
            url: key.url,
            organization: key.owner.underlying,
            layer: layer
        )
    }
}

extension Workspace.Selection.Test.Unit {
    @Test
    func `Resolution preserves inventory order rather than selection order`() throws {
        let selection = Workspace.Selection(
            version: 1,
            repositories: [
                Workspace.Selection.Test.key(
                    owner: "swift-primitives",
                    name: "swift-dimension-primitives"
                ),
                Workspace.Selection.Test.key(
                    owner: "swift-foundations",
                    name: "swift-color"
                ),
            ]
        )

        let resolved = try selection.resolved(
            in: Workspace.Selection.Test.inventory,
            origin: .committed(count: selection.repositories.count)
        )

        #expect(
            resolved.repositories.map(\.name)
                == ["swift-color", "swift-dimension-primitives"]
        )
        #expect(!resolved.repositories.map(\.name).contains("swift-unselected"))
    }

    @Test
    func `Repository keys serialize as canonical owner and name identities`() throws {
        let key = Workspace.Selection.Test.key(
            owner: "swift-primitives",
            name: "swift-dimension-primitives"
        )

        let encoded = key.jsonString()
        let decoded = try Workspace.Repository.Key(jsonString: encoded)

        #expect(encoded == "\"swift-primitives/swift-dimension-primitives\"")
        #expect(decoded == key)
    }
}

extension Workspace.Selection.Test.`Edge Case` {
    @Test
    func `Unsupported version duplicate and empty selections fail closed`() {
        let key = Workspace.Selection.Test.key(
            owner: "swift-primitives",
            name: "swift-dimension-primitives"
        )

        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection(version: 2, repositories: [key]).validated()
        }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection(version: 1, repositories: [key, key]).validated()
        }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection(version: 1, repositories: []).validated()
        }
    }

    @Test
    func `Unknown repository fails resolution`() {
        let selection = Workspace.Selection(
            version: 1,
            repositories: [
                Workspace.Selection.Test.key(
                    owner: "swift-foundations",
                    name: "swift-unknown"
                )
            ]
        )

        #expect(throws: Workspace.Error.self) {
            _ = try selection.resolved(
                in: Workspace.Selection.Test.inventory,
                origin: .committed(count: selection.repositories.count)
            )
        }
    }

    @Test
    func `Malformed identities unexpected fields and duplicate members fail decoding`() {
        #expect(throws: JSON.Error.self) {
            _ = try Workspace.Selection(
                jsonString: """
                    {
                      "version": 1,
                      "repositories": ["swift-foundations"]
                    }
                    """
            )
        }
        #expect(throws: JSON.Error.self) {
            _ = try Workspace.Selection(
                jsonString: """
                    {
                      "version": 1,
                      "repositories": ["swift-foundations/swift-color"],
                      "scope": "proof"
                    }
                    """
            )
        }
        #expect(throws: JSON.Error.self) {
            _ = try Workspace.Selection(
                jsonString: """
                    {
                      "version": 1,
                      "repositories": ["swift-foundations/swift-color"],
                      "repositories": ["swift-primitives/swift-dimension-primitives"]
                    }
                    """
            )
        }
    }
}

extension Workspace.Selection.Test.Integration {
    @Test
    func `Missing and malformed selection files fail loading`() throws {
        let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        let root = try File.Directory(validating: location.path)

        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.load(at: root)
        }

        try Data("{".utf8).write(
            to: location.appending(path: "Selection.json"),
            options: .atomic
        )
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.load(at: root)
        }
    }
}

// MARK: - Local override

extension Workspace.Selection.Test {
    static var color: Workspace.Repository.Key {
        key(owner: "swift-foundations", name: "swift-color")
    }

    static var dimension: Workspace.Repository.Key {
        key(owner: "swift-primitives", name: "swift-dimension-primitives")
    }

    static var unselected: Workspace.Repository.Key {
        key(owner: "swift-foundations", name: "swift-unselected")
    }

    /// The committed policy the override tests depart from.
    static var committed: Workspace.Selection {
        .init(version: 1, repositories: [color])
    }

    static func override(
        version: Swift.Int = 1,
        add: [Workspace.Repository.Key] = [],
        remove: [Workspace.Repository.Key] = []
    ) -> Workspace.Selection.Override {
        .init(version: version, add: add, remove: remove)
    }

    /// A disposable checkout carrying the given documents verbatim.
    static func checkout(
        selection: Swift.String?,
        override: Swift.String? = nil
    ) throws -> (root: File.Directory, remove: () -> Void) {
        let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        if let selection {
            try Data(selection.utf8).write(
                to: location.appending(path: "Selection.json"),
                options: .atomic
            )
        }
        if let override {
            try Data(override.utf8).write(
                to: location.appending(path: "Selection.local.json"),
                options: .atomic
            )
        }
        return (
            try File.Directory(validating: location.path),
            { try? FileManager.default.removeItem(at: location) }
        )
    }

    static let committedDocument = """
        {
          "version": 1,
          "repositories": ["swift-foundations/swift-color"]
        }
        """
}

extension Workspace.Selection.Test.Unit {
    @Test
    func `An override adds to and removes from the committed selection`() throws {
        let merged = try Workspace.Selection.Test.override(
            add: [Workspace.Selection.Test.dimension, Workspace.Selection.Test.unselected],
            remove: [Workspace.Selection.Test.color]
        )
        .applied(to: Workspace.Selection.Test.committed)

        #expect(
            merged.repositories == [
                Workspace.Selection.Test.dimension,
                Workspace.Selection.Test.unselected,
            ]
        )
    }

    @Test
    func `An origin without an override names the committed document alone`() {
        let origin = Workspace.Selection.Origin.committed(count: 5)

        #expect(origin.description == "selection: Selection.json — 5 selected; no local override")
        #expect(origin.effective == 5)
        #expect(origin.added.isEmpty)
        #expect(origin.removed.isEmpty)
    }

    @Test
    func `An overridden origin states both documents and names every withheld package`() {
        let origin = Workspace.Selection.Origin.overridden(
            committed: 5,
            added: [Workspace.Selection.Test.dimension],
            removed: [Workspace.Selection.Test.color]
        )

        #expect(origin.effective == 5)
        #expect(origin.description.contains("Selection.json — 5 selected"))
        #expect(origin.description.contains("Selection.local.json — 1 added, 1 removed"))
        #expect(origin.description.contains("5 in effect"))
        #expect(
            origin.description.contains(
                "Selection.local.json withholds: swift-foundations/swift-color"
            )
        )
    }
}

extension Workspace.Selection.Test.`Edge Case` {
    @Test
    func `Unsupported version empty duplicate and self-contradicting overrides fail closed`() {
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.Test.override(
                version: 2,
                add: [Workspace.Selection.Test.dimension]
            ).validated()
        }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.Test.override().validated()
        }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.Test.override(
                add: [Workspace.Selection.Test.dimension, Workspace.Selection.Test.dimension]
            ).validated()
        }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.Test.override(
                remove: [Workspace.Selection.Test.color, Workspace.Selection.Test.color]
            ).validated()
        }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.Test.override(
                add: [Workspace.Selection.Test.color],
                remove: [Workspace.Selection.Test.color]
            ).validated()
        }
    }

    @Test
    func `A stale override fails rather than degrading to a no-op`() {
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.Test.override(add: [Workspace.Selection.Test.color])
                .applied(to: Workspace.Selection.Test.committed)
        }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.Test.override(remove: [Workspace.Selection.Test.dimension])
                .applied(to: Workspace.Selection.Test.committed)
        }
    }

    @Test
    func `An override that empties the selection fails, as the committed document would`() {
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.Test.override(remove: [Workspace.Selection.Test.color])
                .applied(to: Workspace.Selection.Test.committed)
        }
    }

    @Test
    func `A repository the override adds but the inventory lacks is attributed to the override`()
        throws
    {
        let unknown = Workspace.Selection.Test.key(
            owner: "swift-foundations",
            name: "swift-unknown"
        )
        let merged = try Workspace.Selection.Test.override(add: [unknown])
            .applied(to: Workspace.Selection.Test.committed)

        let error = #expect(throws: Workspace.Error.self) {
            _ = try merged.resolved(
                in: Workspace.Selection.Test.inventory,
                origin: .overridden(committed: 1, added: [unknown], removed: [])
            )
        }

        let message = Swift.String(describing: try #require(error))
        #expect(message.contains("Selection.local.json adds repository not present"))
        #expect(!message.contains("Selection.json contains repository not present"))
    }

    @Test
    func `Malformed overrides fail decoding rather than loading as partial deltas`() {
        #expect(throws: JSON.Error.self) {
            _ = try Workspace.Selection.Override(
                jsonString: """
                    {
                      "version": 1,
                      "add": ["swift-primitives/swift-dimension-primitives"]
                    }
                    """
            )
        }
        #expect(throws: JSON.Error.self) {
            _ = try Workspace.Selection.Override(
                jsonString: """
                    {
                      "version": 1,
                      "add": [],
                      "remove": [],
                      "repositories": ["swift-foundations/swift-color"]
                    }
                    """
            )
        }
        #expect(throws: JSON.Error.self) {
            _ = try Workspace.Selection.Override(
                jsonString: """
                    {
                      "version": 1,
                      "add": ["swift-foundations/swift-color"],
                      "add": ["swift-primitives/swift-dimension-primitives"],
                      "remove": []
                    }
                    """
            )
        }
    }
}

extension Workspace.Selection.Test.Integration {
    @Test
    func `A checkout without an override reports the committed selection in effect`() throws {
        let checkout = try Workspace.Selection.Test.checkout(
            selection: Workspace.Selection.Test.committedDocument
        )
        defer { checkout.remove() }

        let resolved = try Workspace.Selection.effective(
            at: checkout.root,
            in: Workspace.Selection.Test.inventory
        )

        #expect(resolved.repositories.map(\.name) == ["swift-color"])
        #expect(resolved.origin == .committed(count: 1))
    }

    @Test
    func `A checkout with an override reports both documents and the merged checkout`() throws {
        let checkout = try Workspace.Selection.Test.checkout(
            selection: Workspace.Selection.Test.committedDocument,
            override: """
                {
                  "version": 1,
                  "add": ["swift-primitives/swift-dimension-primitives"],
                  "remove": []
                }
                """
        )
        defer { checkout.remove() }

        let resolved = try Workspace.Selection.effective(
            at: checkout.root,
            in: Workspace.Selection.Test.inventory
        )

        #expect(resolved.repositories.map(\.name) == ["swift-color", "swift-dimension-primitives"])
        #expect(
            resolved.origin
                == .overridden(
                    committed: 1,
                    added: [Workspace.Selection.Test.dimension],
                    removed: []
                )
        )
    }

    @Test
    func `A malformed override fails the command rather than falling back to committed policy`()
        throws
    {
        let checkout = try Workspace.Selection.Test.checkout(
            selection: Workspace.Selection.Test.committedDocument,
            override: "{"
        )
        defer { checkout.remove() }

        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.effective(
                at: checkout.root,
                in: Workspace.Selection.Test.inventory
            )
        }
    }

    @Test
    func `An override cannot rescue a missing or malformed committed selection`() throws {
        let complete = """
            {
              "version": 1,
              "add": ["swift-primitives/swift-dimension-primitives"],
              "remove": []
            }
            """

        let absent = try Workspace.Selection.Test.checkout(selection: nil, override: complete)
        defer { absent.remove() }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.effective(
                at: absent.root,
                in: Workspace.Selection.Test.inventory
            )
        }

        let malformed = try Workspace.Selection.Test.checkout(selection: "{", override: complete)
        defer { malformed.remove() }
        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Selection.effective(
                at: malformed.root,
                in: Workspace.Selection.Test.inventory
            )
        }
    }
}
