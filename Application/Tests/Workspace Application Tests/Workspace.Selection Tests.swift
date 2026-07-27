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

        let resolved = try selection.resolved(in: Workspace.Selection.Test.inventory)

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
            _ = try selection.resolved(in: Workspace.Selection.Test.inventory)
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
