import GitHub
import GitHub_HTTP
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Workspace_Application

extension Workspace.Inventory.Test.Unit {
    @Test
    func `Private discovery admits a private repository and records every eligibility reason`()
        async throws
    {
        let owner = GitHub.Organization.Name("swift-foundations")
        let denied = Workspace.Repository.Key(owner: owner, name: .init("swift-denied"))
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [denied],
            limit: .init(fixture: 1, items: 20)
        )
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(
                response: .init(repositories: [
                    .init(fixture: 1, name: "swift-private", visibility: .private),
                    .init(fixture: 2, name: "swift-public", visibility: .public),
                    .init(fixture: 3, name: "swift-archived", archived: true, visibility: .private),
                    .init(fixture: 4, name: "swift-disabled", disabled: true, visibility: .private),
                    .init(fixture: 5, name: "swift-denied", visibility: .private),
                    .init(fixture: 6, name: "swift-absent", visibility: .private),
                ]),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<Never> { request async throws(Never) in
            request.repository.underlying == "swift-private" ? .init(kind: .file) : nil
        }

        let discovery = try await Workspace.Inventory.Client(
            repositories: repositories,
            content: content
        ).discoverPrivate(policy)

        #expect(discovery.repositories.map(\.key.name.underlying) == ["swift-private"])
        #expect(
            discovery.exclusions.map(\.reason) == [
                .visibility(.public),
                .archived,
                .disabled,
                .denied,
                .absent,
            ]
        )
        #expect(discovery.unmeasured.isEmpty)
    }

    /// The one deliberate asymmetry with `discover(_:)`: an empty private
    /// listing is read as zero, not as a failed measurement, because (unlike
    /// the public roster) no independent fact says every policy organization
    /// holds at least one private repository — several legitimately hold
    /// none.
    @Test
    func `An organization with no private repositories is zero, not a failure`() async throws {
        let owner = GitHub.Organization.Name("swift-standards")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .standards)],
            denied: [],
            limit: .init(fixture: 1, items: 20)
        )
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(response: .init(repositories: []), next: nil)
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in nil }

        let discovery = try await Workspace.Inventory.Client(
            repositories: repositories,
            content: content
        ).discoverPrivate(policy)

        #expect(discovery.repositories.isEmpty)
        #expect(discovery.unmeasured.isEmpty)
    }

    /// A repository whose `Package.swift` cannot be resolved — for GitHub,
    /// this is the same signature an empty, branchless repository produces:
    /// there is no content to read on any ref, so the content GET returns
    /// nothing regardless of why. Fail-closed exclusion, not admission,
    /// covers both causes without this type needing to tell them apart.
    @Test
    func `A repository with no readable Package.swift is excluded, never admitted`() async throws {
        let owner = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 20)
        )
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(
                response: .init(repositories: [
                    .init(fixture: 1, name: "swift-empty", visibility: .private)
                ]),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in nil }

        let discovery = try await Workspace.Inventory.Client(
            repositories: repositories,
            content: content
        ).discoverPrivate(policy)

        #expect(discovery.repositories.isEmpty)
        #expect(discovery.exclusions.map(\.reason) == [.absent])
        #expect(discovery.unmeasured.isEmpty)
    }
}

extension Workspace.Inventory.Test.`Edge Case` {
    /// R10 positive control: a private repository that was reachable
    /// (its organization's listing succeeded and returned it) becomes
    /// unreadable at the content step — a lost fine-grained grant, a
    /// transient transport failure. The population this draws from can
    /// actually exhibit the hazard, because the fixture's own content
    /// client is the one refusing it; this is not a sample from where
    /// inaccessibility is structurally impossible.
    ///
    /// The requirement under test: it becomes `UNMEASURED`, not deleted —
    /// it must not silently vanish from the run, and it must not corrupt or
    /// halt the sibling repository's own result.
    @Test
    func `An inaccessible known private repository becomes unmeasured, not deleted`() async throws {
        let owner = GitHub.Organization.Name("swift-foundations")
        let inaccessible = Workspace.Repository.Key(
            owner: owner,
            name: .init("swift-lost-grant")
        )
        let policy = try Workspace.Inventory.Policy(
            organizations: [.init(name: owner, layer: .foundations)],
            denied: [],
            limit: .init(fixture: 1, items: 20)
        )
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(
                response: .init(repositories: [
                    .init(fixture: 1, name: "swift-lost-grant", visibility: .private),
                    .init(fixture: 2, name: "swift-still-fine", visibility: .private),
                ]),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<Workspace.Inventory.Test.Failure> {
            request async throws(Workspace.Inventory.Test.Failure) in
            if request.repository.underlying == "swift-lost-grant" {
                throw .status
            }
            return .init(kind: .file)
        }

        let discovery = try await Workspace.Inventory.Client(
            repositories: repositories,
            content: content
        ).discoverPrivate(policy)

        #expect(discovery.repositories.map(\.key.name.underlying) == ["swift-still-fine"])
        #expect(discovery.exclusions.isEmpty)
        #expect(discovery.unmeasured.count == 1)
        guard case .repository(let scopedKey) = discovery.unmeasured[0].scope else {
            Issue.record("Unexpected unmeasured scope: \(discovery.unmeasured)")
            return
        }
        #expect(scopedKey == inaccessible)
        #expect(discovery.unmeasured[0].reason.contains("status"))
    }

    /// The organization-level counterpart: the private listing itself fails
    /// for one organization. Every private repository it might hold is
    /// unmeasured, not silently zero, and the run still completes for every
    /// other organization.
    @Test
    func `An organization whose private listing fails is unmeasured, and discovery continues`()
        async throws
    {
        let failing = GitHub.Organization.Name("swift-standards")
        let healthy = GitHub.Organization.Name("swift-foundations")
        let policy = try Workspace.Inventory.Policy(
            organizations: [
                .init(name: failing, layer: .standards),
                .init(name: healthy, layer: .foundations),
            ],
            denied: [],
            limit: .init(fixture: 1, items: 20)
        )
        let repositories = GitHub.Organization.Repositories.Client {
            request async throws(
                Either<Async.Lifecycle.Error, GitHub.Organization.Repositories.Page.Error>
            ) in
            if request.organization == failing {
                throw .right(.transport)
            }
            return .init(
                response: .init(repositories: [
                    .init(fixture: 1, name: "swift-healthy", visibility: .private)
                ]),
                next: nil
            )
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in
            .init(kind: .file)
        }

        let discovery = try await Workspace.Inventory.Client(
            repositories: repositories,
            content: content
        ).discoverPrivate(policy)

        #expect(discovery.repositories.map(\.key.name.underlying) == ["swift-healthy"])
        #expect(discovery.unmeasured.count == 1)
        guard case .organization(let scopedName) = discovery.unmeasured[0].scope else {
            Issue.record("Unexpected unmeasured scope: \(discovery.unmeasured)")
            return
        }
        #expect(scopedName == failing)
    }

    @Test
    func `Cancellation during private discovery is not erased into a client failure`() async throws {
        let policy = Workspace.Inventory.Policy.institute()
        let repositories = GitHub.Organization.Repositories.Client { _ in
            .init(response: .init(repositories: []), next: nil)
        }
        let content = GitHub.Repository.Content.Client<Never> { _ async throws(Never) in nil }
        let client = Workspace.Inventory.Client(repositories: repositories, content: content)
        let task = Task {
            try await client.discoverPrivate(policy)
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as Workspace.Inventory.Error<Never> {
            guard case .cancellation = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected erased error: \(error)")
        }
    }
}
