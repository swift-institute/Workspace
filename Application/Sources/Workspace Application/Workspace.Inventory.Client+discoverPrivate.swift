public import GitHub

extension Workspace.Inventory.Client {
    /// The private mirror of ``discover(_:)``: the same policy, the same
    /// eligibility grounds, the opposite visibility and the opposite failure
    /// discipline.
    ///
    /// **Same roster, opposite gate.** `policy.organizations` is the one
    /// declared roster of package-hosting organizations — this walks exactly
    /// those, never a wider or name-inferred set, so a private package sits
    /// under the same governance boundary its public sibling would. The
    /// gate `Client.reason(_:key:policy:)` enforces inverts: a repository is
    /// eligible here only when it *is* `.private`; every other exclusion
    /// ground (archived, disabled, denied, absent, wrong content kind) is
    /// unchanged.
    ///
    /// **No `vacant` guard.** `discover(_:)` treats an empty *public* listing
    /// as a failed measurement, because every non-vacant policy organization
    /// is independently known to publish at least one public repository —
    /// an empty page is evidence of a broken read, not of an empty
    /// organization. No such independent fact holds for private listings:
    /// several policy organizations legitimately hold zero private
    /// repositories today, and nothing declares which. An empty private page
    /// is therefore read as zero, not as failure — the one deliberate
    /// asymmetry with the public path, and it is why this is a separate
    /// method rather than a visibility parameter on `discover(_:)`.
    ///
    /// **Records failure instead of aborting on it.** `discover(_:)` throws
    /// the instant one organization's listing or one repository's content
    /// read fails, because it feeds the committed file and a partial read
    /// must never publish as if it were complete. This method feeds no
    /// committed file. An organization whose listing fails becomes
    /// ``Workspace/Inventory/Private/Unmeasured/Scope/organization(_:)``; a
    /// repository whose content read fails becomes
    /// ``Workspace/Inventory/Private/Unmeasured/Scope/repository(_:)``; the
    /// pass continues with every other organization and repository rather
    /// than discarding their evidence too. `Task` cancellation is the one
    /// failure this still propagates immediately — it is not evidence about
    /// any repository, and swallowing it would hang the caller instead of
    /// stopping cooperatively.
    public func discoverPrivate(
        _ policy: Workspace.Inventory.Policy
    ) async throws(Workspace.Inventory.Error<Content>) -> Workspace.Inventory.Private.Discovery {
        guard let path = GitHub.Repository.Content.Path(segments: ["Package.swift"]) else {
            throw .path
        }

        var included = [Workspace.Inventory.Repository]()
        var excluded = [Workspace.Inventory.Exclusion]()
        var unmeasured = [Workspace.Inventory.Private.Unmeasured]()
        var names = [GitHub.Repository.Name: Workspace.Repository.Key]()

        for organization in policy.organizations {
            guard !Task<Never, Never>.isCancelled else { throw .cancellation }

            let request = GitHub.Organization.Repositories.Request(
                organization: organization.name,
                type: .private,
                page: .first,
                size: .maximum
            )
            let summaries: [GitHub.Repository.Summary]
            do throws(Either<Async.Lifecycle.Error, GitHub.Organization.Repositories.Traversal.Error>) {
                summaries = try await repositories.all(
                    request,
                    limit: policy.limit,
                    duplicate: .reject,
                    order: .server
                )
            } catch {
                if case .left(.cancelled) = error { throw .cancellation }
                unmeasured.append(
                    .init(scope: .organization(organization.name), reason: "\(error)")
                )
                continue
            }

            for summary in summaries {
                guard !Task<Never, Never>.isCancelled else { throw .cancellation }
                let key = Workspace.Repository.Key(owner: organization.name, name: summary.name)

                if let reason = Self.privateReason(summary, key: key, policy: policy) {
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
                    unmeasured.append(.init(scope: .repository(key), reason: "\(error)"))
                    continue
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

        return .init(repositories: included, exclusions: excluded, unmeasured: unmeasured)
    }

    /// Why `repository` is ineligible for the *private* roster, or `nil` if
    /// it is on it.
    ///
    /// Identical to `discover(_:)`'s private `reason(_:key:policy:)` except
    /// the visibility gate is inverted: eligible here means `.private`,
    /// where the public method requires `.public`. Every other ground —
    /// archived, disabled, denied — is the same policy, the same set, the
    /// same reasoning; forking it would let the two rosters drift on grounds
    /// that have nothing to do with visibility.
    private static func privateReason(
        _ repository: GitHub.Repository.Summary,
        key: Workspace.Repository.Key,
        policy: Workspace.Inventory.Policy
    ) -> Workspace.Inventory.Eligibility.Reason? {
        guard repository.visibility == .private else {
            return .visibility(repository.visibility)
        }
        guard !repository.archived else { return .archived }
        guard !repository.disabled else { return .disabled }
        guard !policy.denied.contains(key) else { return .denied }
        return nil
    }
}
