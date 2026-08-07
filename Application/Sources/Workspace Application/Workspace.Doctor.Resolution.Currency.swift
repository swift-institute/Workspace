internal import Async_Fanout
import File_System
private import JSON

extension Workspace.Doctor {
    /// One branch-pinned dependency's resolution staleness, enriched
    /// beyond ``Pin`` with how far behind the pin has fallen: how many
    /// commits separate it from the branch tip, and the date of the
    /// commit currently pinned.
    ///
    /// `behind` and `pinnedAt` read `0`/`""` for a pin that is not
    /// stale — ``pins`` already reports that population size, and this
    /// check's own population mirrors it (every pin, not only the stale
    /// ones) so an empty gather against a non-empty inventory still
    /// reads as unmeasured rather than a clean population no measurement
    /// actually covered.
    public struct Staleness: Equatable, Sendable {
        public let package: Swift.String
        public let dependency: Swift.String
        public let branch: Swift.String
        public let pinned: Swift.String
        public let tip: Swift.String
        public let behind: Swift.Int
        public let pinnedAt: Swift.String

        public init(
            package: Swift.String,
            dependency: Swift.String,
            branch: Swift.String,
            pinned: Swift.String,
            tip: Swift.String,
            behind: Swift.Int,
            pinnedAt: Swift.String
        ) {
            self.package = package
            self.dependency = dependency
            self.branch = branch
            self.pinned = pinned
            self.tip = tip
            self.behind = behind
            self.pinnedAt = pinnedAt
        }
    }
}

extension Workspace.Doctor {
    /// How stale a local dependency resolution is, beyond the plain
    /// pinned-vs-tip mismatch ``pins`` already reports for every
    /// contributor. Workspace#87: two forensic passes on 2026-07-30 cost
    /// real time chasing what a green gate over a stale pin actually
    /// measured — this makes the gap itself, in commits and in the age
    /// of the pinned commit, an observable fact rather than something
    /// only a fresh `swift-array-primitives#3`/`swift-pool-primitives#4`
    /// -style forensic pass could recover.
    ///
    /// Institute-scoped, not contributor-scoped like ``pins``: the
    /// distance and age come from GitHub's compare API, which needs
    /// `gh`, unlike the plain `git ls-remote` tip check every
    /// contributor already runs. Advisory — staleness is legitimate
    /// mid-work — so every finding is a warning.
    public static let resolutionCurrency = Check<Staleness>(
        name: "resolution-currency",
        scope: .instituteInternal,
        controls: .init(
            positive: .init(
                package: "control",
                dependency: "control-dependency",
                branch: "main",
                pinned: "0000000000000000000000000000000000000000",
                tip: "1111111111111111111111111111111111111111",
                behind: 3,
                pinnedAt: "2026-01-01T00:00:00Z"
            ),
            negative: .init(
                package: "control",
                dependency: "control-dependency",
                branch: "main",
                pinned: "0000000000000000000000000000000000000000",
                tip: "0000000000000000000000000000000000000000",
                behind: 0,
                pinnedAt: "2026-01-01T00:00:00Z"
            )
        )
    ) { staleness in
        guard staleness.behind > 0 else { return [] }
        return [
            .init(
                severity: .warning,
                message: "\(staleness.package): \(staleness.dependency) is \(staleness.behind) "
                    + "commit\(staleness.behind == 1 ? "" : "s") behind its \(staleness.branch) tip "
                    + "— pinned at \(staleness.pinned.prefix(12)) (committed \(staleness.pinnedAt)), "
                    + "tip is \(staleness.tip.prefix(12)); re-resolve to advance"
            )
        ]
    }

    /// Enriches ``pinPopulation(_:)`` 's stale subset with commit
    /// distance and the pinned commit's own date, one GitHub compare
    /// request per distinct `(location, pinned, tip)` triple — the
    /// branch-pinned ecosystem means many packages usually share the
    /// exact same stale pin, so this de-duplicates exactly as
    /// ``pins(_:)`` already does for tip lookups.
    func resolutionCurrency(
        _ materialized: [(Workspace.Repository, File.Directory)]
    ) async -> Outcome {
        let gathered: (population: [(pin: Pin, location: Swift.String)], documents: Swift.Int)
        switch await pinPopulation(materialized) {
        case .failure(let reason): return Self.resolutionCurrency.unmeasured(reason: "\(reason)")
        case .success(let value): gathered = value
        }

        let stale = gathered.population.filter { $0.pin.pinned != $0.pin.tip }
        var distinct = [(location: Swift.String, pinned: Swift.String, tip: Swift.String)]()
        var seen = Set<Swift.String>()
        for entry in stale where seen.insert(Self.compareKey(entry)).inserted {
            distinct.append((entry.location, entry.pin.pinned, entry.pin.tip))
        }

        let measured = await fanout.map(
            distinct,
            completed: progress.steps("reading commit distance", of: distinct.count)
        ) { request in
            do throws(Workspace.Error) {
                return Swift.Result<(behind: Swift.Int, pinnedAt: Swift.String), Workspace.Error>
                    .success(try self.compare(request))
            } catch {
                return .failure(error)
            }
        }
        var comparisons: [Swift.String: Swift.Result<(behind: Swift.Int, pinnedAt: Swift.String), Workspace.Error>] = [:]
        for (request, result) in zip(distinct, measured) {
            comparisons[Self.compareKey(request)] = result
        }

        var population = [Staleness]()
        for entry in gathered.population {
            guard entry.pin.pinned != entry.pin.tip else {
                population.append(
                    .init(
                        package: entry.pin.package,
                        dependency: entry.pin.dependency,
                        branch: entry.pin.branch,
                        pinned: entry.pin.pinned,
                        tip: entry.pin.tip,
                        behind: 0,
                        pinnedAt: ""
                    )
                )
                continue
            }
            let key = Self.compareKey(entry)
            guard case .success(let comparison) = comparisons[key] else {
                return Self.resolutionCurrency.unmeasured(
                    reason: "cannot compare \(entry.pin.dependency)'s pin "
                        + "\(entry.pin.pinned.prefix(12)) against its \(entry.pin.branch) tip "
                        + "\(entry.pin.tip.prefix(12)) — resolution currency is unmeasured "
                        + "without the network, never fresh: \(Self.diagnostic(comparisons[key]))"
                )
            }
            population.append(
                .init(
                    package: entry.pin.package,
                    dependency: entry.pin.dependency,
                    branch: entry.pin.branch,
                    pinned: entry.pin.pinned,
                    tip: entry.pin.tip,
                    behind: comparison.behind,
                    pinnedAt: comparison.pinnedAt
                )
            )
        }

        return Self.resolutionCurrency.run(population: population, inventory: gathered.documents)
    }

    private static func compareKey(_ entry: (pin: Pin, location: Swift.String)) -> Swift.String {
        "\(entry.location) \(entry.pin.pinned) \(entry.pin.tip)"
    }

    private static func compareKey(
        _ request: (location: Swift.String, pinned: Swift.String, tip: Swift.String)
    ) -> Swift.String {
        "\(request.location) \(request.pinned) \(request.tip)"
    }

    private static func diagnostic(
        _ result: Swift.Result<(behind: Swift.Int, pinnedAt: Swift.String), Workspace.Error>?
    ) -> Swift.String {
        switch result {
        case .failure(let error): "\(error)"
        case .success, nil: "its comparison was never requested — the gather missed its own population"
        }
    }

    /// One dependency's commit distance and pinned-commit date, read
    /// through GitHub's compare API (`base...head`, `base` being the
    /// pinned revision and `head` the branch tip): `ahead_by` is exactly
    /// the commit count the pin is behind, and `base_commit`'s own
    /// committer date is unaffected by the response's commit-list
    /// pagination, unlike a date read from the `commits` array would be.
    private func compare(
        _ request: (location: Swift.String, pinned: Swift.String, tip: Swift.String)
    ) throws(Workspace.Error) -> (behind: Swift.Int, pinnedAt: Swift.String) {
        guard let key = Workspace.Repository.Key(url: request.location) else {
            throw .configuration("cannot read an owner/repository from \(request.location)")
        }
        let output = try tool(
            "gh",
            [
                "api",
                "repos/\(key.owner.underlying)/\(key.name.underlying)/compare/"
                    + "\(request.pinned)...\(request.tip)",
            ]
        )
        let response: JSON
        do throws(JSON.Error) {
            response = try JSON.parse(output)
        } catch {
            throw .configuration("compare response for \(key.identity) is not JSON: \(error)")
        }
        let behind: Swift.Int
        do throws(JSON.Error) {
            behind = try Swift.Int(json: response.ahead_by)
        } catch {
            throw .configuration("compare response for \(key.identity) carries no ahead_by: \(error)")
        }
        let pinnedAt: Swift.String
        do throws(JSON.Error) {
            pinnedAt = try Swift.String(json: response.base_commit.commit.committer.date)
        } catch {
            throw .configuration(
                "compare response for \(key.identity) carries no base_commit committer date: \(error)"
            )
        }
        return (behind, pinnedAt)
    }
}
