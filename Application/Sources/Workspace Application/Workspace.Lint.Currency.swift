private import File_System
private import Process

extension Workspace.Lint {
    /// Where a build input's revision comes from.
    ///
    /// The published build manifest records one revision per input under
    /// a fixed key; this pairs each key with the repository whose `main`
    /// that revision is a snapshot of. The pairing is the whole content
    /// of the currency check: without it, a manifest entry is a hex
    /// string nothing can be compared against.
    ///
    /// Kept in step with the release workflow's own digest step, which
    /// resolves exactly these six `main` heads. A key present here and
    /// absent from a manifest is a refusal, not a skip — an input that
    /// stopped being recorded is precisely the case where a stale
    /// binary would pass unnoticed.
    public struct Currency: Sendable, Hashable {
        /// The manifest key carrying this input's revision.
        public let key: Swift.String

        /// The `owner/name` of the repository the revision comes from.
        public let repository: Swift.String
    }
}

extension Workspace.Lint.Currency {
    /// Every input the linter binaries are built from.
    ///
    /// The engine first, then the five rule packs, in the order the
    /// release workflow writes them — so a report reads in the same
    /// order as the manifest it is about.
    public static let inputs: [Self] = [
        .init(key: "engine", repository: Workspace.Lint.repository),
        .init(
            key: "swift-primitives-linter-rules",
            repository: "swift-primitives/swift-primitives-linter-rules"
        ),
        .init(
            key: "swift-standards-linter-rules",
            repository: "swift-standards/swift-standards-linter-rules"
        ),
        .init(
            key: "swift-institute-linter-rules",
            repository: "swift-foundations/swift-institute-linter-rules"
        ),
        .init(
            key: "swift-linter-rules",
            repository: "swift-foundations/swift-linter-rules"
        ),
        .init(
            key: "swift-linter-primitives",
            repository: "swift-primitives/swift-linter-primitives"
        ),
    ]

    /// The branch every input is built from.
    ///
    /// The release is rebuilt from `main`, never from a tag, so `main`
    /// is the only ref a currency comparison can be against.
    public static let branch = "main"
}

extension Workspace.Lint {
    /// Whether the installed binaries were built from today's rule packs
    /// and engine, reported as findings rather than a bool.
    ///
    /// A `--fix` run writes to source files. What it writes is decided
    /// entirely by the rules compiled into the installed binaries, so a
    /// binary that trails the rule-pack heads applies *withdrawn*
    /// rewrites — including ones a landed guard was written to prevent.
    /// That failure is silent by construction: the run reports findings,
    /// exits zero, and leaves the damage behind as an ordinary working
    /// tree change. ``supportsFix(_:)`` cannot see it; the dispatcher's
    /// `--help` attests to the option vocabulary of a build, never to
    /// its vintage.
    ///
    /// The comparison is between the installed manifest's per-input
    /// revisions and the live `main` of each input's repository. It
    /// costs one `git ls-remote` per input — a ref advertisement, no
    /// clone, no checkout — which is why it is affordable on a run that
    /// is about to rewrite the ecosystem's source, and why it stays off
    /// the read-only inner loop.
    ///
    /// - Returns: The empty array when every input matches. Otherwise a
    ///   report naming each input that moved, then the installation the
    ///   verdict is about, ending in the remedy.
    public func currency() throws(Workspace.Error) -> [Swift.String] {
        var heads = [Swift.String: Swift.String]()
        for input in Currency.inputs {
            heads[input.key] = try Self.head(of: input)
        }
        return Self.currency(
            of: try installedManifest(),
            against: heads,
            at: manifestFile.description
        )
    }

    /// The comparison itself, separated from the resolution that feeds
    /// it so the refusal can be driven from a fixture rather than from
    /// whatever the six repositories happen to hold today.
    ///
    /// - Parameter source: The manifest the verdict is about, named in
    ///   the refusal. Passed in rather than read from `installed`,
    ///   because a parsed manifest does not carry where it was read
    ///   from — and where it was read from is the half of the refusal
    ///   that was missing.
    static func currency(
        of installed: Manifest,
        against heads: [Swift.String: Swift.String],
        at source: Swift.String
    ) -> [Swift.String] {
        var stale = [Swift.String]()
        for input in Currency.inputs {
            guard let head = heads[input.key] else { continue }
            guard let local = installed.value(for: input.key) else {
                stale.append(
                    "  \(input.key): absent from the installed manifest, "
                        + "\(Self.abbreviated(head)) on main"
                )
                continue
            }
            guard local != head else { continue }
            stale.append(
                "  \(input.key): installed \(Self.abbreviated(local)), "
                    + "\(Self.abbreviated(head)) on main"
            )
        }
        guard !stale.isEmpty else { return [] }
        return [Self.stale] + stale
            + [Self.provenance(of: installed, at: source), Self.republish]
    }

    /// Which installation the verdict is about.
    ///
    /// `--fix` does not resolve its binaries from a Workspace checkout.
    /// It ascends from the package being linted to the first ancestor
    /// carrying an installed manifest — see ``Workspace/Lint/resolve(from:)``
    /// — so a machine holding more than one installed tree refuses on
    /// whichever tree that ascent reached, which need not be the one a
    /// reader thinks of as "the" installation. A package linted from a
    /// scratch directory reaches an installation beside that scratch
    /// directory, not the one beside the organization roots.
    ///
    /// Naming only a revision made the refusal unfalsifiable from its
    /// own text: inspecting a *different* manifest and finding it
    /// current is fully consistent with the refusal being correct, so
    /// the check that looks like it disproves the refusal actually says
    /// nothing about it. Naming the manifest is what lets a reader
    /// check the claim the guard actually made.
    static func provenance(
        of installed: Manifest,
        at source: Swift.String
    ) -> Swift.String {
        "this verdict is about the installation recorded at \(source), digest "
            + installed.digest
            + (installed.value(for: Manifest.builtAt).map { ", built \($0)" } ?? "")
            + "; that is the build --fix would run, so an installation elsewhere on this "
            + "machine being current is not evidence against this refusal"
    }

    /// The `main` head of `input`, resolved from the remote.
    ///
    /// `git ls-remote` rather than a local mirror: a checkout on this
    /// machine can itself be behind, and a currency check that compared
    /// one stale thing against another would report parity between two
    /// stale things.
    private static func head(
        of input: Currency
    ) throws(Workspace.Error) -> Swift.String {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: [
                        "git", "ls-remote",
                        "https://github.com/\(input.repository).git",
                        Currency.branch,
                    ],
                    stdout: .pipe,
                    stderr: .pipe
                )
            )
        } catch {
            throw .process("cannot resolve \(input.repository) main: \(error)")
        }
        guard output.status == .exited(code: 0) else {
            throw .process(
                "cannot resolve \(input.repository) main: "
                    + Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
            )
        }
        let text = Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
        guard
            let line = text.split(separator: "\n", omittingEmptySubsequences: true).first,
            let field = line.split(
                whereSeparator: { $0 == "\t" || $0 == " " }
            ).first,
            field.count == 40,
            field.allSatisfy(\.isHexDigit)
        else {
            throw .process(
                "\(input.repository) advertises no usable \(Currency.branch) head: \(text)"
            )
        }
        return Swift.String(field)
    }

    /// The first seven hexadecimal digits, the form every other tool in
    /// this ecosystem prints a revision in.
    private static func abbreviated(_ revision: Swift.String) -> Swift.String {
        Swift.String(revision.prefix(7))
    }

    static let stale =
        "the installed swift-linter predates the current rule packs, so --fix would apply "
        + "withdrawn rewrites; these inputs moved since it was built:"

    /// Why the remedy is two steps rather than one.
    ///
    /// `workspace lint install` downloads whatever the `ci-binaries`
    /// release currently publishes. When the release itself is behind —
    /// which is the common case, since a rule-pack push republishes
    /// asynchronously — reinstalling changes nothing. Republishing
    /// first is what makes the second step move.
    static let republish =
        "republish the binaries (`gh workflow run publish-ci-binaries.yml "
        + "--repo \(Workspace.Lint.repository)`, then wait for it), and reinstall with "
        + "`workspace lint install`"
}
