import File_System
import Foundation
import GitHub
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Workspace_Application

extension Workspace.Inventory.Test.Unit {
    @Test
    func `Render is byte-identical for schema version one`() throws {
        let key = Workspace.Repository.Key(
            owner: .init("swift-primitives"),
            name: .init("swift-alpha-primitives")
        )
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [.init(name: key.name.underlying, url: key.url, layer: .primitives)]
        )

        let first = try configuration.rendered()
        let second = try configuration.rendered()

        #expect(first == second)
        #expect(
            first == """
                {
                  "repositories": [
                    {
                      "layer": "primitives",
                      "name": "swift-alpha-primitives",
                      "url": "https://github.com/swift-primitives/swift-alpha-primitives.git"
                    }
                  ],
                  "scope": "swift-institute",
                  "swift": "6.3.3",
                  "version": 1,
                  "xcode": "26.6"
                }

                """
        )
    }

    @Test
    func `Render rejects unsupported schema duplicate names and noncanonical URLs`() {
        let key = Workspace.Repository.Key(
            owner: .init("swift-foundations"),
            name: .init("swift-file")
        )
        let repository = Workspace.Repository(
            name: key.name.underlying,
            url: key.url,
            layer: .foundations
        )
        let unsupported = Workspace.Configuration(
            version: 2,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let duplicate = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [repository, repository]
        )
        let noncanonical = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: key.name.underlying,
                    url: "https://example.com/swift-file.git",
                    layer: .foundations
                )
            ]
        )

        #expect(throws: Workspace.Error.self) { _ = try unsupported.rendered() }
        #expect(throws: Workspace.Error.self) { _ = try duplicate.rendered() }
        #expect(throws: Workspace.Error.self) { _ = try noncanonical.rendered() }
    }
}

extension Workspace.Inventory.Test.Integration {
    @Test
    func `Dry run preserves the existing inventory and successful run atomically replaces it`() throws {
        let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        let root = try File.Directory(validating: location.path)
        let file = location.appending(path: "Workspace.json")
        let existing = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let before = try existing.rendered()
        try Data(before.utf8).write(to: file, options: .atomic)
        let document = try Workspace.Configuration.Document.load(at: root)
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.7",
            repositories: []
        )
        let writer = Workspace.Inventory.Writer(root: root)

        let dry = try writer.plan(configuration)
        #expect(dry == .replace(try configuration.rendered()))
        #expect(try Data(contentsOf: file) == Data(before.utf8))

        let applied = try writer.run(configuration, replacing: document)
        #expect(applied == dry)
        #expect(try Data(contentsOf: file) == Data(configuration.rendered().utf8))
    }

    @Test
    func `Content failure leaves the existing inventory byte-for-byte unchanged`() async throws {
        let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        let file = location.appending(path: "Workspace.json")
        let root = try File.Directory(validating: location.path)
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 1)
        )
        let repositories = GitHub.Organization.Repositories.Client<Workspace.Inventory.Test.Failure> {
            _ async throws(Workspace.Inventory.Test.Failure) in
            .init(response: .init(repositories: [.init(fixture: 1, name: "swift-broken")]), next: nil)
        }
        let content = GitHub.Repository.Content.Client<Workspace.Inventory.Test.Failure> {
            _ async throws(Workspace.Inventory.Test.Failure) in
            throw .status
        }
        let application = Workspace.Inventory.Application(
            root: root,
            policy: policy,
            client: .init(repositories: repositories, content: content)
        )
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let original = try configuration.rendered()
        try Data(original.utf8).write(to: file, options: .atomic)
        let existing = try Workspace.Configuration.Document.load(at: root)

        do throws(Workspace.Inventory.Error<Workspace.Inventory.Test.Failure, Workspace.Inventory.Test.Failure>) {
            _ = try await application.run(existing: existing, dry: false)
            Issue.record("Expected content failure")
        } catch {
            guard case .content(_, .status) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
        #expect(try Data(contentsOf: file) == Data(original.utf8))
    }

    @Test
    func `Publication rejects an intervening byte change without replacing it`() async throws {
        let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        let file = location.appending(path: "Workspace.json")
        let root = try File.Directory(validating: location.path)
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let original = try configuration.rendered()
        try Data(original.utf8).write(to: file, options: .atomic)
        let existing = try Workspace.Configuration.Document.load(at: root)
        let intervening = Swift.String(original.dropLast())
        let target = root[file: "Workspace.json"]
        let replace: @Sendable () throws(File.System.Write.Atomic.Error) -> Void = {
            try target.write.atomic(intervening)
        }
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 1)
        )
        let repositories = GitHub.Organization.Repositories.Client<Workspace.Inventory.Test.Failure> {
            _ async throws(Workspace.Inventory.Test.Failure) in
            do throws(File.System.Write.Atomic.Error) {
                try replace()
            } catch {
                throw .status
            }
            return .init(response: .init(repositories: []), next: nil)
        }
        let content = GitHub.Repository.Content.Client<Workspace.Inventory.Test.Failure> {
            _ async throws(Workspace.Inventory.Test.Failure) in nil
        }
        let application = Workspace.Inventory.Application(
            root: root,
            policy: policy,
            client: .init(repositories: repositories, content: content)
        )

        do throws(Workspace.Inventory.Error<Workspace.Inventory.Test.Failure, Workspace.Inventory.Test.Failure>) {
            _ = try await application.run(existing: existing, dry: false)
            Issue.record("Expected the intervening change to reject publication")
        } catch {
            guard case .workspace(.changed) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }

        #expect(try Data(contentsOf: file) == Data(intervening.utf8))
    }
}
