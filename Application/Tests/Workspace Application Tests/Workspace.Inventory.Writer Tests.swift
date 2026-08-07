import File_System
import Foundation
import Git_Foundation
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
            repositories: [
                .init(
                    name: key.name.underlying,
                    url: key.url,
                    organization: key.owner.underlying,
                    layer: .primitives
                )
            ]
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
                      "organization": "swift-primitives",
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
            organization: key.owner.underlying,
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
                    organization: key.owner.underlying,
                    layer: .foundations
                )
            ]
        )

        #expect(throws: Workspace.Error.self) { _ = try unsupported.rendered() }
        #expect(throws: Workspace.Error.self) { _ = try duplicate.rendered() }
        #expect(throws: Workspace.Error.self) { _ = try noncanonical.rendered() }
    }

    /// Positive control: "Change a scratch layer; layer consistency fires
    /// without changing orgs.yaml." A repository sitting directly in one of
    /// the three layer-root organizations (here `swift-primitives`) must
    /// declare that same layer; this check reads only `Workspace.Layer` and
    /// the repository's own `organization`/`layer` fields; `orgs.yaml`
    /// belongs to a different repository entirely and this module never
    /// opens it.
    @Test
    func `A repository whose layer disagrees with its layer-root organization is rejected`() throws {
        let key = Workspace.Repository.Key(
            owner: .init("swift-primitives"),
            name: .init("swift-mislabeled")
        )
        let mismatched = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: key.name.underlying,
                    url: key.url,
                    organization: key.owner.underlying,
                    // swift-primitives is the primitives layer's root — this
                    // must fire.
                    layer: .foundations
                )
            ]
        )
        // Negative control: the same coordinate with the agreeing layer must
        // not trip the guard.
        let consistent = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: key.name.underlying,
                    url: key.url,
                    organization: key.owner.underlying,
                    layer: .primitives
                )
            ]
        )
        // A sub-organization nested under a root (ruling 139) is exempt —
        // `swift-ietf` is a standards-layer organization but is not the
        // standards root, so any layer it declares is a different concern
        // this guard does not adjudicate.
        let subOrganization = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(
                    name: "swift-rfc-9110",
                    url: "https://github.com/swift-ietf/swift-rfc-9110.git",
                    organization: "swift-ietf",
                    layer: .standards
                )
            ]
        )

        #expect(throws: Workspace.Error.self) { _ = try mismatched.rendered() }
        // Negative controls: both must render without throwing. Calling
        // `rendered()` directly (rather than wrapping in `#expect(throws:)`)
        // means an unexpected throw here fails the test through the normal
        // uncaught-error path.
        _ = try consistent.rendered()
        _ = try subOrganization.rendered()
    }
}

extension Workspace.Inventory.Test.Integration {
    @Test
    func `Dry run preserves the existing inventory and successful run atomically replaces it`() throws {
        let location = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        let root = try File.Directory(validating: location.path)
        let file = location.appending(path: "Institute.json")
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
    func `Dry regeneration reports drift without replacing tracked inventory`() async throws {
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let fixture = try Workspace.Inventory.Test.Fixture(
            configuration: configuration
        )
        defer { fixture.remove() }
        let before = try Data(contentsOf: fixture.file)
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 1)
        )
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(
                response: .init(
                    repositories: [.init(fixture: 1, name: "swift-file")]
                ),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<
            Workspace.Inventory.Test.Failure
        > {
            _ async throws(Workspace.Inventory.Test.Failure) in .init(kind: .file)
        }
        let application = Workspace.Inventory.Application(
            root: fixture.root,
            policy: policy,
            client: .init(repositories: repositories, content: content)
        )
        let existing = try Workspace.Configuration.Document.load(at: fixture.root)

        let plan = try await application.run(existing: existing, dry: true)

        guard case .replace(let output) = plan else {
            Issue.record("Expected regeneration to report a replacement")
            return
        }
        #expect(output.contains("\"name\": \"swift-file\""))
        #expect(try Data(contentsOf: fixture.file) == before)
        #expect(try fixture.git.status(at: fixture.location.path).isEmpty)
    }

    @Test
    func `Content failure leaves the existing inventory byte-for-byte unchanged`() async throws {
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let fixture = try Workspace.Inventory.Test.Fixture(
            configuration: configuration
        )
        defer { fixture.remove() }
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 1)
        )
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(response: .init(repositories: [.init(fixture: 1, name: "swift-broken")]), next: nil)
        }
        let content = GitHub.Repository.Content.Client<Workspace.Inventory.Test.Failure> {
            _ async throws(Workspace.Inventory.Test.Failure) in
            throw .status
        }
        let application = Workspace.Inventory.Application(
            root: fixture.root,
            policy: policy,
            client: .init(repositories: repositories, content: content)
        )
        let original = try Data(contentsOf: fixture.file)
        let existing = try Workspace.Configuration.Document.load(at: fixture.root)

        do throws(Workspace.Inventory.Error<Workspace.Inventory.Test.Failure>) {
            _ = try await application.run(existing: existing, dry: false)
            Issue.record("Expected content failure")
        } catch {
            guard case .content(_, .status) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
        #expect(try Data(contentsOf: fixture.file) == original)
    }

    @Test
    func `Publication rejects an intervening byte change without replacing it`() async throws {
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let fixture = try Workspace.Inventory.Test.Fixture(
            configuration: configuration
        )
        defer { fixture.remove() }
        let original = try configuration.rendered()
        let existing = try Workspace.Configuration.Document.load(at: fixture.root)
        let intervening = Swift.String(original.dropLast())
        let target = fixture.root[file: "Institute.json"]
        let replace: @Sendable () throws(File.System.Write.Atomic.Error) -> Void = {
            try target.write.atomic(intervening)
        }
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 20)
        )
        // The listing must be non-empty: an organization that returns nothing
        // now fails discovery before the writer is reached, and this test is
        // about the writer. What it discovers is immaterial — the assertion is
        // that publication refuses after the file changed underneath it.
        let repositories = GitHub.Organization.Repositories.Client {
            _ async throws(
                Either<Async.Lifecycle.Error, GitHub.Organization.Repositories.Page.Error>
            ) in
            do throws(File.System.Write.Atomic.Error) {
                try replace()
            } catch {
                throw .right(.transport)
            }
            return .init(
                response: .init(repositories: [.init(fixture: 1, name: "swift-file")]),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<Workspace.Inventory.Test.Failure> {
            _ async throws(Workspace.Inventory.Test.Failure) in .init(kind: .file)
        }
        let application = Workspace.Inventory.Application(
            root: fixture.root,
            policy: policy,
            client: .init(repositories: repositories, content: content)
        )

        do throws(Workspace.Inventory.Error<Workspace.Inventory.Test.Failure>) {
            _ = try await application.run(existing: existing, dry: false)
            Issue.record("Expected the intervening change to reject publication")
        } catch {
            guard case .workspace(.changed) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }

        #expect(try Data(contentsOf: fixture.file) == Data(intervening.utf8))
    }

    @Test
    func `Regeneration refuses a dirty Workspace worktree before discovery`() async throws {
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        let fixture = try Workspace.Inventory.Test.Fixture(
            configuration: configuration
        )
        defer { fixture.remove() }
        let existing = try Workspace.Configuration.Document.load(at: fixture.root)
        let dirty = Swift.String(try configuration.rendered().dropLast())
        try Data(dirty.utf8).write(to: fixture.file, options: .atomic)
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 1)
        )
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(
                response: .init(
                    repositories: [.init(fixture: 1, name: "swift-file")]
                ),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<
            Workspace.Inventory.Test.Failure
        > {
            _ async throws(Workspace.Inventory.Test.Failure) in .init(kind: .file)
        }
        let application = Workspace.Inventory.Application(
            root: fixture.root,
            policy: policy,
            client: .init(repositories: repositories, content: content)
        )

        do throws(Workspace.Inventory.Error<Workspace.Inventory.Test.Failure>) {
            _ = try await application.run(existing: existing, dry: false)
            Issue.record("Expected dirty-state refusal")
        } catch {
            guard case .workspace(.repository(let message)) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(
                message
                    == "inventory regeneration requires a clean Workspace worktree; "
                        + "found 1 changed path"
            )
        }
        #expect(try Data(contentsOf: fixture.file) == Data(dirty.utf8))
    }

    @Test
    func `Regeneration reports an uninspectable Workspace worktree explicitly`() async throws {
        let location =
            FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        try FileManager.default.createDirectory(
            at: location,
            withIntermediateDirectories: true
        )
        let root = try File.Directory(validating: location.path)
        let configuration = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )
        try Data(configuration.rendered().utf8).write(
            to: location.appending(path: "Institute.json"),
            options: .atomic
        )
        let existing = try Workspace.Configuration.Document.load(at: root)
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 1)
        )
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(
                response: .init(
                    repositories: [.init(fixture: 1, name: "swift-file")]
                ),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<
            Workspace.Inventory.Test.Failure
        > {
            _ async throws(Workspace.Inventory.Test.Failure) in .init(kind: .file)
        }
        let application = Workspace.Inventory.Application(
            root: root,
            policy: policy,
            client: .init(repositories: repositories, content: content)
        )

        do throws(Workspace.Inventory.Error<Workspace.Inventory.Test.Failure>) {
            _ = try await application.run(existing: existing, dry: false)
            Issue.record("Expected worktree inspection failure")
        } catch {
            guard case .workspace(.repository(let message)) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(
                message.hasPrefix(
                    "inventory regeneration cannot inspect the Workspace worktree:"
                )
            )
        }
    }
}
