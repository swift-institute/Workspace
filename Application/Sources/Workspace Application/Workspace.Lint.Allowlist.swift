public import File_System
public import JSON

extension Workspace.Lint {
    /// The packages recorded as deliberately carrying no lint
    /// configuration.
    ///
    /// ## Why this exists
    ///
    /// A package with no `Lint.swift` has measured nothing, and the
    /// capability refuses to call that clean. Left alone, that makes the
    /// sweep exit non-zero on day one and every day after — and a gate
    /// that is always red cannot gate anything. That is the inert-gate
    /// family this fleet spent a day removing: the signal survives, but
    /// nobody reads it.
    ///
    /// The allowlist converts *permanently red* into *tracked, and a new
    /// one is an alarm*. A listed package is reported and counted but
    /// does not fail the sweep; an unlisted one fails loudly. Adding an
    /// entry is a deliberate act taken in the change that creates the
    /// need, which is the whole reason the pattern works.
    ///
    /// ## Why it cannot drift
    ///
    /// The obvious objection is that this becomes a second place a
    /// package's lint status is declared, alongside the `Lint.swift`
    /// whose presence is CI's own activation signal — and two sources
    /// for one fact is how they diverge.
    ///
    /// The answer is mechanical: **an entry for a package that does have
    /// a `Lint.swift` is an error**, as is an entry naming a package
    /// absent from the inventory. `Lint.swift` stays the single
    /// authority; this file only ever records its deliberate absence,
    /// and a stale record fails loudly rather than quietly excusing a
    /// package that no longer needs excusing.
    ///
    /// ## Not read by the single-package path
    ///
    /// `workspace package lint` never loads this file. Standing in a
    /// package and asking for a lint, the answer "nothing here is
    /// configured to lint" is a failure to deliver what was asked,
    /// whatever the ecosystem-level policy is. Keeping the allowlist
    /// sweep-only is also what keeps the fast path free of inventory
    /// reads.
    public struct Allowlist: Equatable, Sendable, JSON.Serializable {
        public let version: Swift.Int

        /// Canonical `organization/repository` identities, matching the
        /// spelling `Selection.json` uses.
        public let unconfigured: [Swift.String]

        public init(version: Swift.Int = 1, unconfigured: [Swift.String] = []) {
            self.version = version
            self.unconfigured = unconfigured
        }
    }
}

extension Workspace.Lint.Allowlist {
    static let fileName: File.Path.Component = "Lint.json"

    /// Loads the allowlist from a Workspace checkout.
    ///
    /// An absent file is an empty allowlist, not an error — and that
    /// fails safe: with no file, every unconfigured package fails the
    /// sweep. A missing allowlist can only ever make the gate stricter.
    public static func load(at checkout: File.Directory) throws(Workspace.Error) -> Self {
        let file = checkout[file: Self.fileName]
        guard file.stat.isFile else { return .init() }

        let text = try Workspace.Lint.read(file)
        do throws(JSON.Error) {
            return try Self(json: JSON.parse(text))
        } catch {
            throw .configuration("cannot read \(file): \(error)")
        }
    }

    /// Whether `repository` is recorded as deliberately unconfigured.
    public func records(_ repository: Workspace.Repository) -> Swift.Bool {
        unconfigured.contains(Self.identity(of: repository))
    }

    static func identity(of repository: Workspace.Repository) -> Swift.String {
        "\(repository.organization)/\(repository.name)"
    }
}

extension Workspace.Lint.Allowlist {
    /// Faults in the allowlist itself, as findings.
    ///
    /// Returned rather than thrown so the sweep can report every stale
    /// entry at once instead of stopping at the first — a list corrected
    /// one error per run is a list nobody finishes correcting.
    ///
    /// Two faults, both of which mean the record no longer describes
    /// reality:
    ///
    /// - An entry whose package **does** carry a `Lint.swift`. The
    ///   package was fixed and the excuse outlived it. This is the check
    ///   that keeps `Lint.swift` the single authority.
    /// - An entry naming a package **not in the inventory**. A typo, or
    ///   a package that has been renamed or removed, silently excusing
    ///   nothing.
    public func diagnostics(
        against inventory: [Workspace.Repository],
        configured: (Workspace.Repository) -> Swift.Bool
    ) -> [Swift.String] {
        var findings = [Swift.String]()
        var known = [Swift.String: Workspace.Repository]()
        for repository in inventory {
            known[Self.identity(of: repository)] = repository
        }

        var seen = Swift.Set<Swift.String>()
        for entry in unconfigured {
            if !seen.insert(entry).inserted {
                findings.append(
                    "\(Self.fileName): \(entry) is listed more than once"
                )
                continue
            }
            guard let repository = known[entry] else {
                findings.append(
                    "\(Self.fileName): \(entry) is not in the inventory; "
                        + "remove the entry or correct its spelling"
                )
                continue
            }
            if configured(repository) {
                findings.append(
                    "\(Self.fileName): \(entry) carries a Lint.swift and no longer needs "
                        + "an entry; remove it. Lint.swift is the authority, and this file "
                        + "records only its deliberate absence."
                )
            }
        }
        return findings
    }
}

extension Workspace.Lint.Allowlist {
    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "unconfigured": value.unconfigured.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Swift.Set<Swift.String> = ["version", "unconfigured"]
        let actual = Swift.Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "Lint keys version and unconfigured",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let unconfigured = object["unconfigured"] else {
            throw .missingKey("unconfigured")
        }
        return try Self(
            version: Swift.Int(json: version),
            unconfigured: [Swift.String](json: unconfigured)
        )
    }
}
