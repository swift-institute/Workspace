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
    func pins(_ materialized: [(Workspace.Repository, File.Directory)]) -> Outcome {
        var population = [Pin]()
        var documents = 0
        var tips = [Swift.String: Swift.String]()
        for (repository, path) in materialized {
            let file = path[file: "Package.resolved"]
            guard file.stat.exists else { continue }
            documents += 1
            let records: [Pin.Record]
            do throws(Workspace.Error) {
                records = try Pin.Record.parse(contents(of: file))
            } catch {
                return Self.pins.unmeasured(
                    reason: "\(repository.name): cannot read its resolved state: \(error)"
                )
            }
            for record in records {
                let key = "\(record.location) \(record.branch)"
                if tips[key] == nil {
                    do throws(Workspace.Error) {
                        tips[key] = try tip(of: record.branch, at: record.location)
                    } catch {
                        return Self.pins.unmeasured(
                            reason: "cannot read the \(record.branch) tip of "
                                + "\(record.dependency) — pins are unmeasured without the "
                                + "network, never fresh: \(error)"
                        )
                    }
                }
                population.append(
                    .init(
                        package: repository.name,
                        dependency: record.dependency,
                        branch: record.branch,
                        pinned: record.revision,
                        tip: tips[key] ?? ""
                    )
                )
            }
        }
        return Self.pins.run(population: population, inventory: documents)
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
