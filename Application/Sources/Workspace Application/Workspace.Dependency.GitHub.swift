private import GitHub
private import GitHub_HTTP
private import HTTP_Standard
private import JSON
private import RFC_3986
private import RFC_4648

extension Workspace.Dependency {
    /// GitHub-backed source for the read-only audit.
    enum Remote: Sendable {}
}

extension Workspace.Dependency.Remote {
    static func client() -> Workspace.Dependency.Client {
        .init(
            repository: { key in await repositoryMetadata(key) },
            source: { metadata in await source(metadata) },
            content: { key, blob in await content(key, blob: blob) }
        )
    }

    private static func source(
        _ metadata: Workspace.Dependency.Metadata
    ) async -> Workspace.Dependency.Fetch<Workspace.Dependency.Source> {
        let branch = metadata.defaultBranch.percentEncoded()
        let commit = await json("repos/\(metadata.key.identity)/commits/\(branch)")
        guard case .available(let commitDocument) = commit else {
            return commit.retyping()
        }

        let revision: Swift.String
        let treeObject: Swift.String
        do throws(JSON.Error) {
            revision = try Swift.String.deserialize(commitDocument["sha"])
            treeObject = try Swift.String.deserialize(commitDocument["commit"]["tree"]["sha"])
        } catch {
            return .malformed("\(metadata.key.identity): malformed commit metadata: \(error)")
        }

        let tree = await json(
            "repos/\(metadata.key.identity)/git/trees/\(treeObject)?recursive=1"
        )
        guard case .available(let treeDocument) = tree else {
            return tree.retyping()
        }
        do throws(JSON.Error) {
            guard !(try Swift.Bool.deserialize(treeDocument["truncated"])) else {
                return .unmeasured(
                    "\(metadata.key.identity): recursive repository tree was truncated"
                )
            }
            guard let entries = treeDocument["tree"].array else {
                return .malformed("\(metadata.key.identity): repository tree is not an array")
            }
            var manifests = [Workspace.Dependency.Source.Blob]()
            for entry in entries {
                guard try Swift.String.deserialize(entry["type"]) == "blob" else { continue }
                let path = try Swift.String.deserialize(entry["path"])
                guard Workspace.Dependency.Source.Blob.isManifest(path) else { continue }
                manifests.append(
                    .init(
                        path: path,
                        object: try Swift.String.deserialize(entry["sha"])
                    )
                )
            }
            return .available(
                .init(
                    reference: metadata.defaultBranch,
                    revision: revision,
                    manifests: manifests.sorted { $0.path < $1.path }
                )
            )
        } catch {
            return .malformed("\(metadata.key.identity): malformed repository tree: \(error)")
        }
    }

    private static func content(
        _ key: Workspace.Repository.Key,
        blob: Workspace.Dependency.Source.Blob
    ) async -> Workspace.Dependency.Fetch<[Byte]> {
        let fetched = await json("repos/\(key.identity)/git/blobs/\(blob.object)")
        guard case .available(let document) = fetched else {
            return fetched.retyping()
        }
        do throws(JSON.Error) {
            let encoding = try Swift.String.deserialize(document["encoding"])
            guard encoding == "base64" else {
                return .malformed(
                    "\(key.identity)/\(blob.path): unsupported blob encoding \(encoding)"
                )
            }
            let encoded = try Swift.String.deserialize(document["content"])
            guard let bytes = RFC_4648.Base64.decode(encoded) else {
                return .malformed("\(key.identity)/\(blob.path): malformed base64 blob")
            }
            return .available(bytes)
        } catch {
            return .malformed("\(key.identity)/\(blob.path): malformed blob response: \(error)")
        }
    }

    private static func json(
        _ endpoint: Swift.String
    ) async -> Workspace.Dependency.Fetch<JSON> {
        let uri: RFC_3986.URI
        do throws(RFC_3986.Error) {
            uri = try .init("https://api.github.com/\(endpoint)")
        } catch {
            return .malformed("invalid GitHub endpoint \(endpoint): \(error)")
        }
        let response: HTTP.Response
        do throws(Workspace.Inventory.Transport.Error) {
            response = try await Workspace.Inventory.Transport.githubCLI()(
                .init(method: .get, target: .absolute(uri))
            )
        } catch {
            return .unmeasured("GitHub transport failed for \(endpoint): \(error)")
        }

        switch response.status.code {
        case 200..<300:
            guard let body = response.body else {
                return .malformed("GitHub returned an empty response for \(endpoint)")
            }
            do throws(JSON.Error) {
                return .available(try JSON.parse(body))
            } catch {
                return .malformed("GitHub returned malformed JSON for \(endpoint): \(error)")
            }
        case 403, 429:
            return .rateLimited("GitHub rate-limited \(endpoint) (HTTP \(response.status.code))")
        case 401, 404:
            return .unavailable("GitHub cannot provide \(endpoint) (HTTP \(response.status.code))")
        default:
            return .unmeasured("GitHub returned HTTP \(response.status.code) for \(endpoint)")
        }
    }
}

private func repositoryMetadata(
    _ key: Workspace.Repository.Key
) async -> Workspace.Dependency.Fetch<Workspace.Dependency.Metadata> {
    let http = GitHub.HTTP.Client<
        Workspace.Inventory.Transport.Error,
        Never
    >(
        agent: .init(rawValue: "swift-institute-workspace"),
        version: .init(rawValue: "2022-11-28"),
        execute: Workspace.Inventory.Transport.githubCLI(),
        pagination: .none
    )
    let response: GitHub.Repository.Get.Response
    do throws(GitHub.HTTP.Error<Workspace.Inventory.Transport.Error, Never>) {
        response = try await http.repository(
            // `gh` supplies the credential; see Workspace.Inventory.Transport.
            authentication: .token(.init(rawValue: ""))
        ).get(
            .init(
                owner: .init(key.owner.underlying),
                repository: key.name
            )
        )
    } catch {
        return repositoryFailure(error, key: key)
    }

    let metadata = response.repository
    guard let canonical = Workspace.Repository.Key(identity: metadata.fullName) else {
        return .malformed(
            "\(key.identity): GitHub returned an invalid repository identity"
        )
    }
    return .available(
        .init(
            key: canonical,
            ownerIsUser: metadata.owner.type == "User",
            visibility: metadata.visibility,
            archived: metadata.isArchived,
            disabled: metadata.isDisabled,
            defaultBranch: metadata.defaultBranch
        )
    )
}

private func repositoryFailure(
    _ error: GitHub.HTTP.Error<Workspace.Inventory.Transport.Error, Never>,
    key: Workspace.Repository.Key
) -> Workspace.Dependency.Fetch<Workspace.Dependency.Metadata> {
    switch error {
    case .execute(let failure):
        return .unmeasured(
            "GitHub transport failed for repos/\(key.identity): \(failure)"
        )
    case .json(let failure):
        return .malformed(
            "\(key.identity): malformed repository metadata: \(failure)"
        )
    case .status(let status):
        switch status.code {
        case 403, 429:
            return .rateLimited(
                "GitHub rate-limited repos/\(key.identity) (HTTP \(status.code))"
            )
        case 401, 404:
            return .unavailable(
                "GitHub cannot provide repos/\(key.identity) (HTTP \(status.code))"
            )
        default:
            return .unmeasured(
                "GitHub returned HTTP \(status.code) for repos/\(key.identity)"
            )
        }
    case .header(let failure):
        return .malformed(
            "invalid GitHub repository request for \(key.identity): \(failure)"
        )
    case .path(let failure):
        return .malformed(
            "invalid GitHub repository path for \(key.identity): \(failure)"
        )
    case .query(let failure):
        return .malformed(
            "invalid GitHub repository query for \(key.identity): \(failure)"
        )
    case .scheme(let failure):
        return .malformed(
            "invalid GitHub repository scheme for \(key.identity): \(failure)"
        )
    case .pagination:
        return .unmeasured(
            "GitHub repository lookup unexpectedly attempted pagination for \(key.identity)"
        )
    @unknown default:
        return .unmeasured(
            "GitHub repository lookup failed for \(key.identity)"
        )
    }
}

extension Workspace.Dependency.Source.Blob {
    static func isManifest(_ path: Swift.String) -> Swift.Bool {
        guard let name = path.split(separator: "/").last else { return false }
        return name == "Package.swift"
            || (
                name.hasPrefix("Package@swift-")
                    && name.hasSuffix(".swift")
                    && name.count > "Package@swift-.swift".count
            )
    }
}

extension Workspace.Dependency.Fetch {
    fileprivate func retyping<Other: Sendable>() -> Workspace.Dependency.Fetch<Other> {
        switch self {
        case .available:
            .unmeasured("internal fetch retyping reached an available value")
        case .unavailable(let reason):
            .unavailable(reason)
        case .rateLimited(let reason):
            .rateLimited(reason)
        case .malformed(let reason):
            .malformed(reason)
        case .unmeasured(let reason):
            .unmeasured(reason)
        }
    }
}
