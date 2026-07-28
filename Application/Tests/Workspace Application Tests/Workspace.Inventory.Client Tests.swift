import GitHub
import GitHub_HTTP
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Workspace_Application

extension Workspace.Inventory.Test.Unit {
    @Test
    func `Published GitHub HTTP client executes without a networking package type`() async throws {
        let http = GitHub.HTTP.Client<Never, Never>(
            agent: .init(rawValue: "Workspace Tests"),
            version: .init(rawValue: "2022-11-28"),
            execute: { request async throws(Never) in
                #expect(
                    request.target.rawValue
                        == "https://api.github.com/repos/swift-foundations/swift-github/contents/Package.swift"
                )
                return .init(status: .init(404))
            },
            pagination: .none
        )
        let client = Workspace.Inventory.client(http, authentication: .none)
        guard let path = GitHub.Repository.Content.Path(segments: ["Package.swift"]) else {
            Issue.record("Expected Package.swift to be a valid GitHub content path")
            return
        }

        let response = try await client.content.get(
            .init(
                organization: .init("swift-foundations"),
                repository: .init("swift-github"),
                path: path
            )
        )

        #expect(response == nil)
    }

    @Test
    func `Institute policy has the exact public organization roster and excludes meta`() {
        let policy = Workspace.Inventory.Policy.institute()

        #expect(
            policy.organizations.map(\.name.underlying) == [
                "swift-primitives",
                "swift-standards",
                "swift-ietf",
                "swift-iso",
                "swift-w3c",
                "swift-whatwg",
                "swift-ieee",
                "swift-iec",
                "swift-ecma",
                "swift-incits",
                "swift-nist",
                "swift-linux-foundation",
                "swift-microsoft",
                "swift-arm-ltd",
                "swift-intel",
                "swift-riscv",
                "swift-foundations",
            ]
        )
        #expect(
            policy.organizations.map(\.layer) == [
                .primitives,
                .standards, .standards, .standards, .standards, .standards,
                .standards, .standards, .standards, .standards, .standards,
                .standards, .standards, .standards, .standards, .standards,
                .foundations,
            ]
        )
        #expect(!policy.organizations.map(\.name.underlying).contains("swift-institute"))

        // Three layers only (principal ruling, 2026-07-28). Asserted as an
        // absence because the failure mode is silent: discovering into either
        // org would re-materialize a root above L3.
        #expect(!policy.organizations.map(\.name.underlying).contains("swift-components"))
        #expect(!policy.organizations.map(\.name.underlying).contains("swift-applications"))
        #expect(!policy.organizations.map(\.layer).contains(.components))
        #expect(!policy.organizations.map(\.layer).contains(.applications))
    }

    @Test
    func `Discovery traverses pages, admits a fork, and records every eligibility reason`()
        async throws
    {
        let owner = GitHub.Organization.Name("swift-foundations")
        let denied = Workspace.Repository.Key(
            owner: owner,
            name: .init("swift-denied")
        )
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [denied],
            limit: .init(fixture: 3, items: 20)
        )

        let repositories = GitHub.Organization.Repositories.Client<Never> { request async throws(Never) in
            if request.page == .first {
                return .init(
                    response: .init(repositories: [
                        .init(fixture: 1, name: "swift-file"),
                        .init(fixture: 2, name: "swift-archived", archived: true),
                        .init(fixture: 3, name: "swift-disabled", disabled: true),
                        // Admitted, not excluded — the principal ruled
                        // institute-owned forks onto the roster on 2026-07-28.
                        // It sits among the excluded fixtures deliberately: the
                        // reason list below is the positive control proving the
                        // ruling narrowed eligibility by exactly one ground and
                        // left the other six firing.
                        .init(fixture: 4, name: "swift-fork", fork: true),
                        .init(fixture: 5, name: "swift-private", visibility: .private),
                    ]),
                    next: .init(
                        organization: request.organization,
                        type: request.type,
                        page: .init(fixture: 2),
                        size: request.size
                    )
                )
            }
            return .init(
                response: .init(repositories: [
                    .init(fixture: 6, name: "swift-denied"),
                    .init(fixture: 7, name: "swift-absent"),
                    .init(fixture: 8, name: "swift-directory"),
                ]),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<Never> { request async throws(Never) in
            switch request.repository.underlying {
            case "swift-file": .init(kind: .file)
            case "swift-fork": .init(kind: .file)
            case "swift-directory": .init(kind: .directory)
            default: nil
            }
        }

        let discovery = try await Workspace.Inventory.Client(
            repositories: repositories,
            content: content
        ).discover(policy)

        #expect(discovery.repositories.map(\.key.name.underlying) == ["swift-file", "swift-fork"])
        #expect(
            discovery.exclusions.map(\.reason) == [
                .archived,
                .disabled,
                .visibility(.private),
                .denied,
                .absent,
                .kind(.directory),
            ]
        )
    }
}

extension Workspace.Inventory.Test.`Edge Case` {
    @Test
    func `Item bound is a typed repository traversal failure`() async throws {
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 1)
        )
        let repositories = GitHub.Organization.Repositories.Client<Never> { _ async throws(Never) in
            .init(
                response: .init(repositories: [
                    .init(fixture: 1, name: "swift-one"),
                    .init(fixture: 2, name: "swift-two"),
                ]),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in nil }

        do throws(Workspace.Inventory.Error<Never, Never>) {
            _ = try await Workspace.Inventory.Client(
                repositories: repositories,
                content: content
            ).discover(policy)
            Issue.record("Expected the item bound to fail")
        } catch {
            guard case .repositories(owner, .items) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
    }

    @Test
    func `Page bound is a typed repository traversal failure`() async throws {
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 10)
        )
        let repositories = GitHub.Organization.Repositories.Client<Never> { request async throws(Never) in
            .init(
                response: .init(repositories: []),
                next: .init(
                    organization: request.organization,
                    type: request.type,
                    page: .init(fixture: request.page.rawValue + 1),
                    size: request.size
                )
            )
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in nil }

        do throws(Workspace.Inventory.Error<Never, Never>) {
            _ = try await Workspace.Inventory.Client(
                repositories: repositories,
                content: content
            ).discover(policy)
            Issue.record("Expected the traversal bound to fail")
        } catch {
            guard case .repositories(owner, .pages) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
    }

    @Test
    func `Cancellation is not erased into a client failure`() async throws {
        let policy = Workspace.Inventory.Policy.institute()
        let repositories = GitHub.Organization.Repositories.Client<Never> { _ async throws(Never) in
            .init(response: .init(repositories: []), next: nil)
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in nil }
        let client = Workspace.Inventory.Client(repositories: repositories, content: content)
        let task = Task {
            try await client.discover(policy)
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as Workspace.Inventory.Error<Never, Never> {
            guard case .cancellation = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected erased error: \(error)")
        }
    }

    @Test
    func `Malformed content failure stays typed and names its repository`() async throws {
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
            throw .malformed
        }

        do throws(Workspace.Inventory.Error<Workspace.Inventory.Test.Failure, Workspace.Inventory.Test.Failure>) {
            _ = try await Workspace.Inventory.Client(
                repositories: repositories,
                content: content
            ).discover(policy)
            Issue.record("Expected malformed content to fail")
        } catch {
            guard case .content(let key, .malformed) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(key.owner == owner)
            #expect(key.name.underlying == "swift-broken")
        }
    }

    @Test
    func `Eligible name collision across owners is rejected`() async throws {
        let first = GitHub.Organization.Name("swift-standards")
        let second = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [
                .init(name: first, layer: .standards),
                .init(name: second, layer: .foundations),
            ],
            denied: [],
            limit: .init(fixture: 1, items: 10)
        )
        let repositories = GitHub.Organization.Repositories.Client<Never> { request async throws(Never) in
            .init(
                response: .init(repositories: [
                    .init(
                        fixture: request.organization == first ? 1 : 2,
                        name: "swift-collision"
                    )
                ]),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in
            .init(kind: .file)
        }

        do throws(Workspace.Inventory.Error<Never, Never>) {
            _ = try await Workspace.Inventory.Client(
                repositories: repositories,
                content: content
            ).discover(policy)
            Issue.record("Expected name collision")
        } catch {
            guard case .collision(let name, let old, let new) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(name.underlying == "swift-collision")
            #expect(old.owner == first)
            #expect(new.owner == second)
        }
    }
}

extension Workspace.Inventory.Test.Integration {
    @Test
    func `Shuffled repository pages produce byte-identical merged inventory`() async throws {
        let first = GitHub.Repository.Summary(fixture: 1, name: "swift-alpha")
        let second = GitHub.Repository.Summary(fixture: 2, name: "swift-beta")
        let left = try await Self.discovery([[second], [first]])
        let right = try await Self.discovery([[first], [second]])
        let existing = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )

        let leftOutput = try Workspace.Inventory.Merge()(left, into: existing).rendered()
        let rightOutput = try Workspace.Inventory.Merge()(right, into: existing).rendered()

        #expect(leftOutput == rightOutput)
    }

    private static func discovery(
        _ pages: [[GitHub.Repository.Summary]]
    ) async throws(Workspace.Inventory.Error<Never, Never>) -> Workspace.Inventory.Discovery {
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy: Workspace.Inventory.Policy
        do throws(Workspace.Inventory.Policy.Error) {
            policy = try .init(
                organizations: [.init(name: owner, layer: .foundations)],
                denied: [],
                limit: .init(fixture: UInt(pages.count), items: 10)
            )
        } catch {
            preconditionFailure("Invalid synthetic inventory policy: \(error)")
        }
        let repositories = GitHub.Organization.Repositories.Client<Never> { request async throws(Never) in
            let index = Int(request.page.rawValue - 1)
            let next: GitHub.Organization.Repositories.Request? =
                index + 1 < pages.count
                ? .init(
                    organization: request.organization,
                    type: request.type,
                    page: .init(fixture: request.page.rawValue + 1),
                    size: request.size
                )
                : nil
            return .init(response: .init(repositories: pages[index]), next: next)
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in
            .init(kind: .file)
        }

        return try await Workspace.Inventory.Client(
            repositories: repositories,
            content: content
        ).discover(policy)
    }
}
