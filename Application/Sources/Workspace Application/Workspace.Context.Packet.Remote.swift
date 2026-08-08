internal import Async_Fanout
private import HTTP_Standard
private import JSON
private import RFC_3986

extension Workspace.Context.Packet {
    enum Remote: Sendable {}
}

extension Workspace.Context.Packet.Remote {
    static func client() -> Workspace.Context.Packet.Client {
        .init { key, comments in
            let issue = await json("repos/\(key.repository.identity)/issues/\(key.number)")
            guard case .available(let document) = issue else { return issue.retyping() }
            do {
                let title = try Swift.String.deserialize(document["title"])
                let state = try Swift.String.deserialize(document["state"])
                let type = try Swift.String.deserialize(document["type"]["name"])
                let stateReason = try? Swift.String.deserialize(document["state_reason"])
                let url = try Swift.String.deserialize(document["html_url"])
                let body = (try? Swift.String.deserialize(document["body"])) ?? ""
                let assignees = try strings(document["assignees"], key: "login")
                let labels = try strings(document["labels"], key: "name")
                let parent = await parent(of: key)
                let children = await children(of: key)
                let included = await Workspace.Fanout().mapAsync(comments) { await Self.comment(at: $0) }
                var diagnostics = parent.diagnostics + children.diagnostics
                var divergences = [Swift.String]()
                var rendered = [Workspace.Context.Packet.Record.Comment]()
                for result in included {
                    switch result {
                    case .available(let comment):
                        if comment.issue == key { rendered.append(comment) }
                        else {
                            divergences.append(
                                "included comment \(comment.url) belongs to \(comment.issue.identity), not \(key.identity)"
                            )
                        }
                    case .unavailable(let reason), .malformed(let reason), .unmeasured(let reason):
                        diagnostics.append(reason)
                    }
                }
                return .available(
                    .init(
                        key: key,
                        title: title,
                        state: state,
                        type: type,
                        stateReason: stateReason,
                        url: url,
                        body: body,
                        assignees: assignees,
                        labels: labels,
                        parent: parent.value,
                        children: children.value,
                        comments: rendered,
                        divergences: divergences,
                        diagnostics: diagnostics
                    )
                )
            } catch {
                return .malformed("\(key.identity): malformed Issue response: \(error)")
            }
        }
    }

    private static func parent(of key: Workspace.Context.Packet.Key) async -> (value: Swift.String?, diagnostics: [Swift.String]) {
        switch await json("repos/\(key.repository.identity)/issues/\(key.number)/parent", absent: true) {
        case .available(let document):
            do { return (try identity(document), []) }
            catch { return (nil, ["\(key.identity): malformed native parent: \(error)"]) }
        case .unavailable(let reason):
            return reason == "native parent absent" ? (nil, []) : (nil, [reason])
        case .malformed(let reason), .unmeasured(let reason): return (nil, [reason])
        }
    }

    private static func children(of key: Workspace.Context.Packet.Key) async -> (value: [Swift.String], diagnostics: [Swift.String]) {
        switch await json("repos/\(key.repository.identity)/issues/\(key.number)/sub_issues") {
        case .available(let document):
            guard let values = document.array else {
                return ([], ["\(key.identity): native sub-issues response is not an array"])
            }
            do {
                var children = [Swift.String]()
                for value in values { children.append(try identity(value)) }
                return (children.sorted(), [])
            }
            catch { return ([], ["\(key.identity): malformed native sub-issues response: \(error)"]) }
        case .unavailable(let reason), .malformed(let reason), .unmeasured(let reason): return ([], [reason])
        }
    }

    private static func comment(at url: Swift.String) async -> Workspace.Context.Packet.Fetch<Workspace.Context.Packet.Record.Comment> {
        let endpoint: Swift.String
        if let start = url.range(of: "/repos/")?.lowerBound {
            endpoint = Swift.String(url[start...].dropFirst())
        } else if url.hasPrefix("https://github.com/") {
            let pieces = url.dropFirst("https://github.com/".count).split(separator: "#", maxSplits: 1)
            let path = pieces.first?.split(separator: "/", omittingEmptySubsequences: false) ?? []
            guard
                path.count == 4, path[2] == "issues", pieces.count == 2,
                pieces[1].hasPrefix("issuecomment-"),
                let comment = Swift.Int(pieces[1].dropFirst("issuecomment-".count))
            else { return .malformed("included comment URL is not a GitHub comment URL: \(url)") }
            endpoint = "repos/\(path[0])/\(path[1])/issues/comments/\(comment)"
        } else {
            return .malformed("included comment URL is not a GitHub comment URL: \(url)")
        }
        let response = await json(endpoint)
        guard case .available(let document) = response else { return response.retyping() }
        do {
            return .available(
                .init(
                    url: try Swift.String.deserialize(document["html_url"]),
                    issue: try commentIssue(document["issue_url"]),
                    author: try Swift.String.deserialize(document["user"]["login"]),
                    body: (try? Swift.String.deserialize(document["body"])) ?? ""
                )
            )
        } catch {
            return .malformed("included comment \(url) is malformed: \(error)")
        }
    }

    private static func strings(_ document: JSON, key: Swift.String) throws(JSON.Error) -> [Swift.String] {
        guard let values = document.array else {
            throw .typeMismatch(expected: "array", got: "non-array")
        }
        var strings = [Swift.String]()
        strings.reserveCapacity(values.count)
        for value in values {
            strings.append(try Swift.String.deserialize(value[key]))
        }
        return strings
    }

    private static func identity(_ document: JSON) throws(JSON.Error) -> Swift.String {
        let key = try key(document["repository_url"])
        return "\(key.repository.identity)#\(try Swift.Int.deserialize(document["number"]))"
    }

    private static func key(_ endpoint: JSON) throws(JSON.Error) -> Workspace.Context.Packet.Key {
        let repository = try Swift.String.deserialize(endpoint)
        let marker = "https://api.github.com/repos/"
        guard repository.hasPrefix(marker) else { throw .typeMismatch(expected: "GitHub repository URL", got: repository) }
        guard let key = Workspace.Context.Packet.Key(argument: Swift.String(repository.dropFirst(marker.count)) + "#1") else {
            throw .typeMismatch(expected: "GitHub repository URL", got: repository)
        }
        return key
    }

    private static func commentIssue(_ endpoint: JSON) throws(JSON.Error) -> Workspace.Context.Packet.Key {
        let url = try Swift.String.deserialize(endpoint)
        let marker = "https://api.github.com/repos/"
        guard url.hasPrefix(marker) else {
            throw .typeMismatch(expected: "GitHub Issue URL", got: url)
        }
        let parts = url.dropFirst(marker.count).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 4, parts[2] == "issues" else {
            throw .typeMismatch(expected: "GitHub Issue URL", got: url)
        }
        guard let key = Workspace.Context.Packet.Key(argument: "\(parts[0])/\(parts[1])#\(parts[3])") else {
            throw .typeMismatch(expected: "GitHub Issue URL", got: url)
        }
        return key
    }

    private static func json(_ endpoint: Swift.String, absent: Swift.Bool = false) async -> Workspace.Context.Packet.Fetch<JSON> {
        let uri: RFC_3986.URI
        do { uri = try .init("https://api.github.com/\(endpoint)") }
        catch { return .malformed("invalid GitHub endpoint \(endpoint): \(error)") }
        let response: HTTP.Response
        do {
            response = try await Workspace.Inventory.Transport.githubCLI()(.init(method: .get, target: .absolute(uri)))
        } catch {
            return .unmeasured("GitHub transport failed for \(endpoint): \(error)")
        }
        if absent, response.status.code == 404 { return .unavailable("native parent absent") }
        switch response.status.code {
        case 200..<300:
            guard let body = response.body else { return .malformed("GitHub returned an empty response for \(endpoint)") }
            do { return .available(try JSON.parse(body)) }
            catch { return .malformed("GitHub returned malformed JSON for \(endpoint): \(error)") }
        case 401, 404: return .unavailable("GitHub cannot provide \(endpoint) (HTTP \(response.status.code))")
        default: return .unmeasured("GitHub returned HTTP \(response.status.code) for \(endpoint)")
        }
    }
}

extension Workspace.Context.Packet.Fetch {
    fileprivate func retyping<Other: Sendable>() -> Workspace.Context.Packet.Fetch<Other> {
        switch self {
        case .available: .unmeasured("internal packet fetch retyping reached an available value")
        case .unavailable(let reason): .unavailable(reason)
        case .malformed(let reason): .malformed(reason)
        case .unmeasured(let reason): .unmeasured(reason)
        }
    }
}
