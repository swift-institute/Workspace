import File_System

extension Workspace.Doctor {
    /// One branch-pinned dependency recorded in a repository's resolved
    /// state, against the current tip of the branch it pins.
    ///
    /// Every dependency in this ecosystem is a branch dependency, so a
    /// pin recorded behind its branch tip means any green gate over the
    /// package was measured against stale sources.
    public struct Pin: Equatable, Sendable {
        public let package: Swift.String
        public let dependency: Swift.String
        public let branch: Swift.String
        public let pinned: Swift.String
        public let tip: Swift.String

        public init(
            package: Swift.String,
            dependency: Swift.String,
            branch: Swift.String,
            pinned: Swift.String,
            tip: Swift.String
        ) {
            self.package = package
            self.dependency = dependency
            self.branch = branch
            self.pinned = pinned
            self.tip = tip
        }
    }
}

extension Workspace.Doctor {
    /// The stale-pin sub-check: every branch pin recorded in a resolved
    /// state matches the current tip of the branch it pins. A stale pin
    /// is a warning whose remedy is re-resolution — resolved state is
    /// generated and is never hand-edited to force advancement.
    public static let pins = Check<Pin>(
        name: "resolved-pins",
        scope: .contributor,
        controls: .init(
            positive: .init(
                package: "control",
                dependency: "control-dependency",
                branch: "main",
                pinned: "0000000000000000000000000000000000000000",
                tip: "1111111111111111111111111111111111111111"
            ),
            negative: .init(
                package: "control",
                dependency: "control-dependency",
                branch: "main",
                pinned: "0000000000000000000000000000000000000000",
                tip: "0000000000000000000000000000000000000000"
            )
        )
    ) { pin in
        guard pin.pinned != pin.tip else { return [] }
        return [
            .init(
                severity: .warning,
                message: "\(pin.package): \(pin.dependency) is pinned at \(pin.pinned.prefix(12)) "
                    + "behind the \(pin.branch) tip \(pin.tip.prefix(12)) — a green gate over "
                    + "these pins measured stale sources; re-resolve to advance (resolved state "
                    + "is generated; never hand-edit it)"
            )
        ]
    }

    /// Measures the stale-pin sub-check separately from the state
    /// census: it needs the network, and without the network pins are
    /// unmeasured — never fresh — while the census can still be `ok`.
    /// Measures the stale-pin sub-check in two passes: the resolved-state
    /// documents are read locally and in order, then every distinct
    /// `(remote, branch)` they name has its tip read concurrently.
    ///
    /// This is the only check that touches the network, and it is the whole
    /// reason a run spends most of its wall clock waiting: a full-roster
    /// checkout names a few hundred distinct pairs, and each is one
    /// round trip to a remote. The round trips are independent — each reads
    /// one remote's advertised refs and touches no local repository and no
    /// shared state — so they are gathered concurrently. The existing
    /// per-pair de-duplication is unchanged and now happens once, up front,
    /// rather than incidentally as the walk proceeds.
    ///
    /// The short-circuit's *order* is preserved exactly. A serial walk
    /// reported the first failure in document order, interleaving reads and
    /// tips per repository; so does this. A repository whose resolved state
    /// cannot be read stops the document pass there, and only the
    /// repositories *before* it can name a tip failure that a serial walk
    /// would have hit first — so only their tips are fetched.
    func pins(_ materialized: [(Workspace.Repository, File.Directory)]) async -> Outcome {
        var documents = 0
        var read = [(package: Swift.String, records: [Pin.Record])]()
        var failure: Swift.String?
        for (repository, path) in materialized {
            let file = path[file: "Package.resolved"]
            guard file.stat.exists else { continue }
            documents += 1
            do throws(Workspace.Error) {
                read.append((repository.name, try Pin.Record.parse(contents(of: file))))
            } catch {
                failure = "\(repository.name): cannot read its resolved state: \(error)"
                break
            }
        }

        var distinct = [Pin.Record]()
        var seen = Set<Swift.String>()
        for document in read {
            for record in document.records where seen.insert(Self.key(record)).inserted {
                distinct.append(record)
            }
        }

        let measured = await fanout.map(
            distinct,
            completed: progress.steps("resolved-pins: read remote tips", of: distinct.count)
        ) { record in
            do throws(Workspace.Error) {
                return Swift.Result<Swift.String, Workspace.Error>.success(
                    try self.tip(of: record.branch, at: record.location)
                )
            } catch {
                return .failure(error)
            }
        }
        var tips = [Swift.String: Swift.Result<Swift.String, Workspace.Error>]()
        for (record, tip) in zip(distinct, measured) { tips[Self.key(record)] = tip }

        var population = [Pin]()
        for document in read {
            for record in document.records {
                guard case .success(let tip) = tips[Self.key(record)] else {
                    return Self.pins.unmeasured(
                        reason: "cannot read the \(record.branch) tip of "
                            + "\(record.dependency) — pins are unmeasured without the "
                            + "network, never fresh: "
                            + Self.diagnostic(tips[Self.key(record)])
                    )
                }
                population.append(
                    .init(
                        package: document.package,
                        dependency: record.dependency,
                        branch: record.branch,
                        pinned: record.revision,
                        tip: tip
                    )
                )
            }
        }

        if let failure { return Self.pins.unmeasured(reason: failure) }
        return Self.pins.run(population: population, inventory: documents)
    }

    /// The de-duplication key for a pin record: one remote tip is read once
    /// however many pins name it.
    private static func key(_ record: Pin.Record) -> Swift.String {
        "\(record.location) \(record.branch)"
    }

    /// Why a tip is absent from the gather. A missing entry is not a
    /// network failure but a gather that did not cover its own population,
    /// and it is reported as itself rather than folded into one.
    private static func diagnostic(
        _ tip: Swift.Result<Swift.String, Workspace.Error>?
    ) -> Swift.String {
        switch tip {
        case .failure(let error): "\(error)"
        case .success, nil: "its tip was never requested — the gather missed its own population"
        }
    }

    /// The current tip of a remote branch, read without touching any
    /// local repository metadata.
    private func tip(
        of branch: Swift.String,
        at location: Swift.String
    ) throws(Workspace.Error) -> Swift.String {
        let output = try tool(
            "git",
            ["ls-remote", "--refs", "--exit-code", location, "refs/heads/\(branch)"]
        )
        guard
            let tip = output.split(separator: "\n").first?
                .split(whereSeparator: { $0 == "\t" || $0 == " " }).first,
            !tip.isEmpty
        else {
            throw .process("ls-remote advertised no tip for refs/heads/\(branch)")
        }
        return Swift.String(tip)
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
