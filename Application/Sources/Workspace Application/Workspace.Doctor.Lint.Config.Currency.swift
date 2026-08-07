internal import Async_Fanout
import File_System

extension Workspace.Doctor {
    /// One local `swift-linter` remote-config cache entry, against a live
    /// fetch of the same source.
    ///
    /// `swift-linter` downloads its canonical configuration on first use
    /// under whatever directory it runs from and caches it at
    /// `.swiftlint/RemoteConfigCache/v1/<escaped-source>.yml`, annotated
    /// with the source URL and download timestamp in its own first three
    /// lines. Nothing refreshes that cache on its own — Workspace#86
    /// (receipt gap 2) measured one lagging origin by hours — so a local
    /// lint run can silently measure against stale canonical rules.
    public struct ConfigCache: Equatable, Sendable {
        public let root: Swift.String
        public let source: Swift.String
        public let current: Swift.Bool

        public init(root: Swift.String, source: Swift.String, current: Swift.Bool) {
            self.root = root
            self.source = source
            self.current = current
        }
    }
}

extension Workspace.Doctor {
    /// Workspace#87's second half: the resolution-staleness check covers
    /// dependency pins; this covers the other local cache that can go
    /// stale silently, `swift-linter`'s downloaded canonical
    /// configuration. Institute-scoped for the same reason
    /// ``resolutionCurrency`` is — reading the live canonical file needs
    /// `gh`.
    ///
    /// Scoped to caches this checkout can actually find: the checkout
    /// root and every materialized repository's own directory, since
    /// `swift-linter` caches per invocation directory rather than in one
    /// fixed location (`institute lint`'s sweep runs it once per package
    /// root). A repository that was never linted locally has no cache
    /// and contributes nothing — that is the ordinary case, not a gap.
    public static let lintConfigCurrency = Check<ConfigCache>(
        name: "lint-config-currency",
        scope: .instituteInternal,
        controls: .init(
            positive: .init(
                root: "control",
                source: "https://raw.githubusercontent.com/control/control/main/.swiftlint.yml",
                current: false
            ),
            negative: .init(
                root: "control",
                source: "https://raw.githubusercontent.com/control/control/main/.swiftlint.yml",
                current: true
            )
        )
    ) { cache in
        guard !cache.current else { return [] }
        return [
            .init(
                severity: .warning,
                message: "\(cache.root): the cached lint config from \(cache.source) lags "
                    + "origin — re-run swift-linter there (or clear the cache) to refresh it"
            )
        ]
    }

    func lintConfigCurrency(
        _ materialized: [(Workspace.Repository, File.Directory)]
    ) async -> Outcome {
        var roots: [(name: Swift.String, directory: File.Directory)] = [
            ("(checkout root)", root.checkout)
        ]
        roots.append(contentsOf: materialized.map { ($0.0.name, $0.1) })

        var found = [(root: Swift.String, source: Swift.String, cached: Swift.String)]()
        for entry in roots {
            let cache = entry.directory[directory: ".swiftlint"][directory: "RemoteConfigCache"][
                directory: "v1"
            ]
            guard cache.stat.exists else { continue }
            guard let files = try? await cache.files() else { continue }
            for file in files {
                guard file.name.description.hasSuffix(".yml") else { continue }
                guard let text = try? contents(of: file) else { continue }
                guard let parsed = Self.parseCache(text) else { continue }
                found.append((entry.name, parsed.source, parsed.body))
            }
        }

        guard !found.isEmpty else {
            return Self.lintConfigCurrency.run(population: [], inventory: 0)
        }

        var distinct = [Swift.String]()
        var seen = Set<Swift.String>()
        for entry in found where seen.insert(entry.source).inserted {
            distinct.append(entry.source)
        }

        let measured = await fanout.map(
            distinct,
            completed: progress.steps("reading canonical lint config", of: distinct.count)
        ) { source in
            do throws(Workspace.Error) {
                return Swift.Result<Swift.String, Workspace.Error>.success(
                    try self.fetchRaw(source)
                )
            } catch {
                return .failure(error)
            }
        }
        var live: [Swift.String: Swift.Result<Swift.String, Workspace.Error>] = [:]
        for (source, result) in zip(distinct, measured) { live[source] = result }

        var population = [ConfigCache]()
        for entry in found {
            guard case .success(let content) = live[entry.source] else {
                return Self.lintConfigCurrency.unmeasured(
                    reason: "cannot read the canonical config at \(entry.source) — lint-config "
                        + "currency is unmeasured without the network, never fresh: "
                        + Self.diagnostic(live[entry.source])
                )
            }
            population.append(
                .init(root: entry.root, source: entry.source, current: content == entry.cached)
            )
        }

        return Self.lintConfigCurrency.run(population: population, inventory: found.count)
    }

    /// Splits a cached config file into its declared source URL and the
    /// original content beneath `swift-linter`'s own three-line header
    /// (`#` / `# Automatically downloaded from <url> by SwiftLint on
    /// <date> at <time>.` / `#`). `nil` when the header does not match
    /// that exact shape — a cache this cannot parse is skipped rather
    /// than reported as stale or as a failure; a format change in
    /// `swift-linter` silently narrows this check's coverage rather than
    /// raising a false alarm, which is a deliberately named limitation
    /// rather than an oversight.
    private static func parseCache(
        _ text: Swift.String
    ) -> (source: Swift.String, body: Swift.String)? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > 3, lines[0] == "#", lines[2] == "#" else { return nil }
        let marker = "# Automatically downloaded from "
        guard lines[1].hasPrefix(marker) else { return nil }
        let rest = lines[1].dropFirst(marker.count)
        guard let separator = rest.range(of: " by SwiftLint on ") else { return nil }
        let source = Swift.String(rest[rest.startIndex..<separator.lowerBound])
        let body = lines[3...].joined(separator: "\n")
        return (source, body)
    }

    /// The live content at a `raw.githubusercontent.com/<org>/<repo>/<branch>/<path>`
    /// URL, read through the repository-contents API with the raw media
    /// type so the response is the file's bytes rather than a
    /// base64-wrapped JSON envelope.
    private func fetchRaw(_ source: Swift.String) throws(Workspace.Error) -> Swift.String {
        let prefix = "https://raw.githubusercontent.com/"
        guard source.hasPrefix(prefix) else {
            throw .configuration("\(source) is not a raw.githubusercontent.com URL")
        }
        let components = source.dropFirst(prefix.count).split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard components.count >= 4 else {
            throw .configuration("cannot read an org/repository/branch/path from \(source)")
        }
        let path = components[3...].joined(separator: "/")
        return try tool(
            "gh",
            [
                "api",
                "-H", "Accept: application/vnd.github.raw+json",
                "repos/\(components[0])/\(components[1])/contents/\(path)?ref=\(components[2])",
            ]
        )
    }

    private static func diagnostic(
        _ result: Swift.Result<Swift.String, Workspace.Error>?
    ) -> Swift.String {
        switch result {
        case .failure(let error): "\(error)"
        case .success, nil: "its fetch was never requested — the gather missed its own population"
        }
    }

    private func contents(of file: File) throws(Workspace.Error) -> Swift.String {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try file.read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            throw .filesystem("cannot read \(file): \(error)")
        }
    }
}
