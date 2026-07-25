public import GitHub

extension Workspace.Inventory {
    public struct Client<Listing, Content>: Sendable
    where
        Listing: Swift.Error,
        Content: Swift.Error
    {
        public let repositories: GitHub.Organization.Repositories.Client<Listing>
        public let content: GitHub.Repository.Content.Client<Content>

        public init(
            repositories: GitHub.Organization.Repositories.Client<Listing>,
            content: GitHub.Repository.Content.Client<Content>
        ) {
            self.repositories = repositories
            self.content = content
        }
    }
}

extension Workspace.Inventory.Client {
    public func discover(
        _ policy: Workspace.Inventory.Policy
    ) async throws(Workspace.Inventory.Error<Listing, Content>) -> Workspace.Inventory.Discovery {
        guard let path = GitHub.Repository.Content.Path(segments: ["Package.swift"]) else {
            throw .path
        }

        var included = [Workspace.Inventory.Repository]()
        var excluded = [Workspace.Inventory.Exclusion]()
        var names = [GitHub.Repository.Name: Workspace.Repository.Key]()

        for organization in policy.organizations {
            guard !Task<Never, Never>.isCancelled else { throw .cancellation }

            let request = GitHub.Organization.Repositories.Request(
                organization: organization.name,
                type: .public,
                page: .first,
                size: .maximum
            )
            let summaries: [GitHub.Repository.Summary]
            do throws(GitHub.Organization.Repositories.Traversal.Error<Listing>) {
                summaries = try await repositories.all(
                    request,
                    limit: policy.limit,
                    duplicate: .reject,
                    order: .server
                )
            } catch {
                if case .cancellation = error { throw .cancellation }
                throw .repositories(organization.name, error)
            }

            for summary in summaries {
                guard !Task<Never, Never>.isCancelled else { throw .cancellation }
                let key = Workspace.Repository.Key(owner: organization.name, name: summary.name)

                if let reason = Self.reason(summary, key: key, policy: policy) {
                    excluded.append(.init(repository: key, reason: reason))
                    continue
                }

                let response: GitHub.Repository.Content.Response?
                do throws(Content) {
                    response = try await content.get(
                        .init(
                            organization: organization.name,
                            repository: summary.name,
                            path: path
                        )
                    )
                } catch {
                    if Task<Never, Never>.isCancelled { throw .cancellation }
                    throw .content(key, error)
                }

                guard !Task<Never, Never>.isCancelled else { throw .cancellation }
                guard let response else {
                    excluded.append(.init(repository: key, reason: .absent))
                    continue
                }
                guard response.kind == .file else {
                    excluded.append(.init(repository: key, reason: .kind(response.kind)))
                    continue
                }

                if let first = names[summary.name], first != key {
                    throw .collision(summary.name, first, key)
                }
                names[summary.name] = key
                included.append(.init(id: summary.id, key: key, layer: organization.layer))
            }
        }

        return .init(repositories: included, exclusions: excluded)
    }

    private static func reason(
        _ repository: GitHub.Repository.Summary,
        key: Workspace.Repository.Key,
        policy: Workspace.Inventory.Policy
    ) -> Workspace.Inventory.Eligibility.Reason? {
        guard repository.visibility == .public else {
            return .visibility(repository.visibility)
        }
        guard !repository.archived else { return .archived }
        guard !repository.disabled else { return .disabled }
        guard !repository.fork else { return .fork }
        guard !policy.denied.contains(key) else { return .denied }
        return nil
    }
}
