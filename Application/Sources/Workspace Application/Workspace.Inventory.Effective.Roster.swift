public import File_System
public import JSON

extension Workspace.Inventory.Effective {
    /// A private population the caller already discovered, supplied as a
    /// file instead of re-discovered here.
    ///
    /// **Why this exists: credential-holding and digesting are different
    /// jobs.** ``Client/discoverPrivate(_:)`` walks every Institute
    /// organization through *one* `gh` credential. No such credential
    /// exists in the control plane that needs the digest: a GitHub App
    /// mints installation tokens per organization, which is why the
    /// private-verification sweep already mints one token per org inside
    /// its own enumeration and holds the effective private roster in hand
    /// — while having no way to hand that roster to the digest. The result
    /// was a control plane dispatching the literal string `"unmeasured"`
    /// as its effective-inventory digest.
    ///
    /// This type is the seam: the caller supplies the population it is
    /// credentialed to see, and this module supplies the digest.
    ///
    /// **It carries coordinates and nothing else, deliberately.** Every
    /// other fact the digested population needs is derived here, exactly
    /// as ``Client/discoverPrivate(_:)`` derives it: the repository's
    /// fields from its coordinate, and its layer from the *organization's*
    /// layer in ``Workspace/Inventory/Policy`` — never from anything the
    /// caller asserts. A caller therefore cannot spell a URL differently,
    /// or label a repository with a layer its organization does not carry,
    /// and silently change the digest. A digest computed from a roster is
    /// comparable, byte for byte, with one computed from a live pass over
    /// the same population, because the only thing the roster contributes
    /// is *which repositories were seen*.
    ///
    /// The roster also carries the caller's own UNMEASURED residue, in the
    /// same ``Output/Unmeasured`` rows the report publishes: an
    /// organization the caller's tokens could not list is recorded, not
    /// dropped, so an incomplete roster cannot pass itself off as a
    /// complete population.
    public struct Roster: Equatable, Sendable {
        public let repositories: [Workspace.Repository.Key]
        public let unmeasured: [Output.Unmeasured]

        public init(
            repositories: [Workspace.Repository.Key],
            unmeasured: [Output.Unmeasured]
        ) {
            self.repositories = repositories
            self.unmeasured = unmeasured
        }
    }
}

extension Workspace.Inventory.Effective.Roster {
    /// Reads and validates a roster file.
    ///
    /// An absent file, unreadable bytes, a malformed document, and an empty
    /// population are four different failures and stay four different
    /// errors. The last one matters most: an empty roster would otherwise
    /// digest perfectly happily, publishing a real SHA-256 of a population
    /// nobody measured — the exact "wrong but present" value a typed
    /// UNMEASURED exists to avoid.
    public static func read(_ path: File.Path) throws(Error) -> Self {
        let file = File(path)
        let text: Swift.String
        do throws(Either<File.System.Read.Full.Error, Never>) {
            text = try file.read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            throw .unreadable(path.description)
        }

        let document: JSON
        do throws(JSON.Error) {
            document = try JSON.parse(text)
        } catch {
            throw .malformed("\(error)")
        }

        let roster: Self
        do throws(JSON.Error) {
            roster = try Self(json: document)
        } catch {
            throw .malformed("\(error)")
        }

        guard !roster.repositories.isEmpty else { throw .emptyPopulation }
        return roster
    }
}

extension Workspace.Inventory.Effective.Roster: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "schemaVersion": Swift.Int(1).json,
            "repositories": value.repositories.json,
            "unmeasured": value.unmeasured.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let version = object["schemaVersion"] else { throw .missingKey("schemaVersion") }
        guard try Swift.Int(json: version) == 1 else {
            throw .typeMismatch(expected: "schemaVersion 1", got: "unsupported version")
        }
        guard let repositories = object["repositories"] else { throw .missingKey("repositories") }
        // A roster with no `unmeasured` key is a caller claiming a complete
        // pass, which is a legitimate claim; a roster with the key and an
        // empty array says the same thing explicitly. Both are accepted.
        var residue = [Workspace.Inventory.Effective.Output.Unmeasured]()
        if let unmeasured = object["unmeasured"] {
            residue = try [Workspace.Inventory.Effective.Output.Unmeasured](json: unmeasured)
        }
        return Self(
            repositories: try [Workspace.Repository.Key](json: repositories),
            unmeasured: residue
        )
    }
}
