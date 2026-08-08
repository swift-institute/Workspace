internal import Async_Fanout
private import GitHub
private import SPM_Standard

extension Workspace.Dependency.Audit {
    func run() async -> Workspace.Dependency.Report {
        let controls = await controls()
        return await run(controls: controls)
    }

    func run(
        controls: Workspace.Dependency.Controls
    ) async -> Workspace.Dependency.Report {
        let keys = repositories.compactMap(Workspace.Repository.Key.init(repository:))
        guard controls.passed, keys.count == repositories.count else {
            return .init(
                inventoryReference: inventoryReference,
                inventoryRevision: inventoryRevision,
                sanctioned: sanctioned.sorted(by: Workspace.Repository.Key.precedes),
                controls: controls,
                subjects: keys.map {
                    .init(
                        repository: $0,
                        reference: nil,
                        revision: nil,
                        state: .unmeasured,
                        reason: "runtime controls or inventory-key control failed"
                    )
                },
                manifests: [],
                edges: [],
                identities: [],
                exclusions: []
            )
        }

        let measurements = await fanout.mapAsync(keys) { key in
            await measure(key)
        }
        let subjects = measurements.map(\.subject)
        let manifests = measurements.flatMap(\.manifests)
        let pending = measurements.flatMap(\.edges)
        let exclusions = measurements.flatMap(\.exclusions)

        let declared = Array(Set(pending.map(\.declared)))
            .sorted(by: Workspace.Repository.Key.precedes)
        let resolutions = await fanout.mapAsync(declared) { key in
            Workspace.Dependency.Resolution(
                declared: key,
                fetch: await client.repository(key)
            )
        }
        let resolved = resolve(resolutions)
        let edges = pending.map { edge in
            guard let resolution = resolved.edges[edge.declared] else {
                return Workspace.Dependency.Edge(
                    repository: edge.repository,
                    manifest: edge.manifest,
                    reference: edge.reference,
                    revision: edge.revision,
                    line: edge.line,
                    declaredURL: edge.declaredURL,
                    canonicalURL: nil,
                    identity: edge.declared.identity,
                    state: .unmeasured,
                    reason: "repository identity was not resolved"
                )
            }
            return Workspace.Dependency.Edge(
                repository: edge.repository,
                manifest: edge.manifest,
                reference: edge.reference,
                revision: edge.revision,
                line: edge.line,
                declaredURL: edge.declaredURL,
                canonicalURL: resolution.canonicalURL,
                identity: resolution.identity,
                state: resolution.state,
                reason: resolution.reason
            )
        }

        return .init(
            inventoryReference: inventoryReference,
            inventoryRevision: inventoryRevision,
            sanctioned: sanctioned.sorted(by: Workspace.Repository.Key.precedes),
            controls: controls,
            subjects: subjects,
            manifests: manifests,
            edges: edges,
            identities: resolved.identities,
            exclusions: exclusions
        )
    }
}

extension Workspace.Dependency.Audit {
    private func measure(
        _ key: Workspace.Repository.Key
    ) async -> Workspace.Dependency.Measurement {
        let repository = await client.repository(key)
        guard case .available(let metadata) = repository else {
            let problem = repository.failure
            return failure(
                key,
                state: problem?.state ?? .unmeasured,
                reason: problem?.reason ?? "repository metadata was not measured"
            )
        }
        if let reason = exclusion(key, metadata: metadata) {
            return failure(key, state: .excluded, reason: reason)
        }

        let fetched = await client.source(metadata)
        guard case .available(let source) = fetched else {
            let problem = fetched.failure
            return failure(
                key,
                state: problem?.state ?? .unmeasured,
                reason: problem?.reason ?? "repository source was not measured"
            )
        }
        guard !source.manifests.isEmpty else {
            return failure(
                key,
                reference: source.reference,
                revision: source.revision,
                state: .malformed,
                reason: "repository tree contains no Package.swift or Package@swift-*.swift"
            )
        }

        var manifests = [Workspace.Dependency.Manifest]()
        var edges = [Workspace.Dependency.Pending.Edge]()
        var exclusions = [Workspace.Dependency.Exclusion]()
        var subjectState = Workspace.Dependency.State.measured
        var subjectReason: Swift.String?

        for blob in source.manifests.sorted(by: { $0.path < $1.path }) {
            let fetched = await client.content(metadata.key, blob)
            guard case .available(let bytes) = fetched else {
                let problem = fetched.failure
                let state = problem?.state ?? .unmeasured
                let reason = problem?.reason ?? "manifest content was not measured"
                manifests.append(
                    .init(
                        repository: key,
                        path: blob.path,
                        reference: source.reference,
                        revision: source.revision,
                        state: state,
                        reason: reason
                    )
                )
                if subjectState == .measured {
                    subjectState = state
                    subjectReason = "\(blob.path): \(reason)"
                }
                continue
            }

            do throws(Package.Dependency.Declaration.Parser.Error) {
                let declarations = try parser.parse(bytes)
                var malformed = false
                for declaration in declarations {
                    switch declaration {
                    case .url(let url, let line):
                        guard let declared = Workspace.Repository.Key(url: url) else {
                            malformed = true
                            exclusions.append(
                                .init(
                                    repository: key,
                                    manifest: blob.path,
                                    reference: source.reference,
                                    revision: source.revision,
                                    line: line,
                                    kind: .malformed,
                                    value: url,
                                    reason:
                                        "URL is not canonical https://github.com/owner/repository.git"
                                )
                            )
                            continue
                        }
                        edges.append(
                            .init(
                                repository: key,
                                manifest: blob.path,
                                reference: source.reference,
                                revision: source.revision,
                                line: line,
                                declaredURL: url,
                                declared: declared
                            )
                        )
                    case .path(let value, let line):
                        exclusions.append(
                            .init(
                                repository: key,
                                manifest: blob.path,
                                reference: source.reference,
                                revision: source.revision,
                                line: line,
                                kind: .path,
                                value: value,
                                reason: "path dependency has no canonical repository URL"
                            )
                        )
                    case .registry(let value, let line):
                        exclusions.append(
                            .init(
                                repository: key,
                                manifest: blob.path,
                                reference: source.reference,
                                revision: source.revision,
                                line: line,
                                kind: .registry,
                                value: value,
                                reason: "registry dependency has no canonical repository URL"
                            )
                        )
                    case .malformed(let reason, let line):
                        malformed = true
                        exclusions.append(
                            .init(
                                repository: key,
                                manifest: blob.path,
                                reference: source.reference,
                                revision: source.revision,
                                line: line,
                                kind: .malformed,
                                value: nil,
                                reason: reason
                            )
                        )
                    }
                }
                manifests.append(
                    .init(
                        repository: key,
                        path: blob.path,
                        reference: source.reference,
                        revision: source.revision,
                        state: malformed ? .malformed : .measured,
                        reason: malformed ? "one or more package declarations are malformed" : nil
                    )
                )
                if malformed, subjectState == .measured {
                    subjectState = .malformed
                    subjectReason = "\(blob.path): one or more package declarations are malformed"
                }
            } catch {
                manifests.append(
                    .init(
                        repository: key,
                        path: blob.path,
                        reference: source.reference,
                        revision: source.revision,
                        state: .malformed,
                        reason: error.description
                    )
                )
                if subjectState == .measured {
                    subjectState = .malformed
                    subjectReason = "\(blob.path): \(error)"
                }
            }
        }

        return .init(
            subject: .init(
                repository: key,
                reference: source.reference,
                revision: source.revision,
                state: subjectState,
                reason: subjectReason
            ),
            manifests: manifests,
            edges: edges,
            exclusions: exclusions
        )
    }

    private func failure(
        _ key: Workspace.Repository.Key,
        reference: Swift.String? = nil,
        revision: Swift.String? = nil,
        state: Workspace.Dependency.State,
        reason: Swift.String
    ) -> Workspace.Dependency.Measurement {
        .init(
            subject: .init(
                repository: key,
                reference: reference,
                revision: revision,
                state: state,
                reason: reason
            ),
            manifests: [],
            edges: [],
            exclusions: []
        )
    }

    private func exclusion(
        _ expected: Workspace.Repository.Key,
        metadata: Workspace.Dependency.Metadata
    ) -> Swift.String? {
        guard metadata.visibility == .public else {
            return "repository is not public"
        }
        guard metadata.key == expected else {
            return "inventory URL redirects to \(metadata.key.identity)"
        }
        guard !metadata.archived else { return "repository is archived" }
        guard !metadata.disabled else { return "repository is disabled" }
        guard !policy.denied.contains(metadata.key) else {
            return "repository is denied by the inventory policy"
        }
        let owners = Set(policy.organizations.map(\.name))
        guard owners.contains(metadata.key.owner) else {
            return "repository owner is outside the inventory policy"
        }
        return nil
    }
}
