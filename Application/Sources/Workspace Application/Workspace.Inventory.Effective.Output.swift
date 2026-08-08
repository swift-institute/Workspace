public import File_System
public import GitHub
public import JSON

#if canImport(Darwin)
    private import Darwin
#elseif canImport(Glibc)
    private import Glibc
#elseif canImport(Musl)
    private import Musl
#endif

extension Workspace.Inventory.Effective {
    /// The version-1 effective-inventory report `institute inventory
    /// effective` writes: the three ``Effective`` populations, each with the
    /// SHA-256 digest of its own canonical bytes, plus the typed unmeasured
    /// residue of the private pass.
    ///
    /// **Why a separate report type.** ``Effective`` is the in-memory
    /// combination; it deliberately writes nothing to disk. This type is the
    /// one serialized projection of it — the adapter a downstream verifier
    /// reads — so the report schema can hold exactly the members the
    /// contract names (`schemaVersion`, `scope`, `public`, `private`,
    /// `combined`, `unmeasured`) without widening `Effective` itself.
    ///
    /// **The private limb is typed, never invented.** Under
    /// ``Scope-swift.enum/public`` no private discovery ran, so the limb is
    /// serialized as `not-requested` — a recorded refusal, not an empty
    /// population masquerading as a measurement. Under
    /// ``Scope-swift.enum/effective`` the limb carries the discovered
    /// population and digest, and anything the pass could not read arrives
    /// as an ``Unmeasured`` row rather than a silent absence.
    public struct Output: Equatable, Sendable, Workspace.Receipt.Sealed {
        public let scope: Scope
        public let `public`: Limb
        /// `nil` exactly when ``scope-swift.property`` is
        /// ``Scope-swift.enum/public``: the private pass was not requested,
        /// so no private coordinate exists to publish.
        public let `private`: Limb?
        public let combined: Limb
        public let unmeasured: [Unmeasured]

        /// One report over one effective inventory, from a live private
        /// pass: the pass's `Private.Unmeasured` residue is projected into
        /// ``Unmeasured`` rows and the rest is
        /// ``init(scope:effective:residue:)``.
        public init(
            scope: Scope,
            effective: Workspace.Inventory.Effective,
            unmeasured: [Workspace.Inventory.Private.Unmeasured]
        ) {
            self.init(
                scope: scope,
                effective: effective,
                residue: unmeasured.map(Unmeasured.init)
            )
        }

        /// The same report from residue the caller already projected — the
        /// supplied-roster path (``Effective/Roster``) carries rows in this
        /// shape already, having never held a `Private.Unmeasured` to map.
        /// Distinctly labelled rather than overloaded on element type: an
        /// empty literal must not silently pick a path.
        public init(
            scope: Scope,
            effective: Workspace.Inventory.Effective,
            residue unmeasured: [Unmeasured]
        ) {
            self.scope = scope
            self.public = Limb(
                population: effective.public.repositories,
                digest: effective.public.digest
            )
            self.private =
                switch scope {
                case .public: nil
                case .effective:
                    Limb(
                        population: effective.private.repositories,
                        digest: effective.private.digest
                    )
                }
            self.combined = Limb(
                population: effective.combined.repositories,
                digest: effective.combined.digest
            )
            self.unmeasured = unmeasured
        }

        internal init(
            scope: Scope,
            public: Limb,
            private: Limb?,
            combined: Limb,
            unmeasured: [Unmeasured]
        ) {
            self.scope = scope
            self.public = `public`
            self.private = `private`
            self.combined = combined
            self.unmeasured = unmeasured
        }
    }
}

extension Workspace.Inventory.Effective.Output {
    /// The population breadth the caller requested — not the visibility of
    /// any one repository.
    public enum Scope: Swift.String, Equatable, Sendable {
        /// The committed public roster only; the private pass is not run.
        case `public`
        /// The public roster combined with one authorized private pass.
        case effective
    }
}

extension Workspace.Inventory.Effective.Output {
    /// One digested population limb: the canonically sorted coordinates and
    /// the SHA-256 (lowercase hexadecimal) of that population's canonical
    /// bytes, exactly as ``Workspace/Inventory/Effective/Population``
    /// digests them.
    public struct Limb: Equatable, Sendable {
        public let population: [Workspace.Repository]
        public let digest: Swift.String

        public init(population: [Workspace.Repository], digest: Swift.String) {
            self.population = population
            self.digest = digest
        }
    }
}

extension Workspace.Inventory.Effective.Output {
    /// One serialized unmeasured row — the report projection of
    /// ``Workspace/Inventory/Private/Unmeasured``, carrying the same typed
    /// scope and captured reason.
    public struct Unmeasured: Equatable, Sendable {
        public let kind: Kind
        public let coordinate: Swift.String
        public let reason: Swift.String

        public init(kind: Kind, coordinate: Swift.String, reason: Swift.String) {
            self.kind = kind
            self.coordinate = coordinate
            self.reason = reason
        }

        public init(_ unmeasured: Workspace.Inventory.Private.Unmeasured) {
            switch unmeasured.scope {
            case .organization(let name):
                self.init(
                    kind: .organization,
                    coordinate: name.underlying,
                    reason: unmeasured.reason
                )
            case .repository(let key):
                self.init(
                    kind: .repository,
                    coordinate: "\(key.owner.underlying)/\(key.name.underlying)",
                    reason: unmeasured.reason
                )
            }
        }

        public enum Kind: Swift.String, Equatable, Sendable {
            case organization
            case repository
        }
    }
}

extension Workspace.Inventory.Effective.Output {
    /// The process exit code the report's completeness dictates: `0` when
    /// every population the requested scope needs was measured, `2` when any
    /// residue is UNMEASURED. Invalid input never reaches this — it throws
    /// before a report exists, and the runner maps that to `1`.
    public var exitCode: Swift.Int32 {
        unmeasured.isEmpty ? 0 : 2
    }
}

extension Workspace.Inventory.Effective.Output {
    public static func serialize(_ value: Self) -> JSON {
        [
            "schemaVersion": Swift.Int(1).json,
            "scope": value.scope.rawValue.json,
            "public": value.public.json,
            "private": value.private.map(\.json) ?? ["status": "not-requested".json],
            "combined": value.combined.json,
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
        guard let scopeValue = object["scope"] else { throw .missingKey("scope") }
        guard let scope = try Scope(rawValue: Swift.String(json: scopeValue)) else {
            throw .typeMismatch(expected: "public|effective", got: "unrecognised scope")
        }
        guard let publicValue = object["public"] else { throw .missingKey("public") }
        guard let privateValue = object["private"] else { throw .missingKey("private") }
        guard let combined = object["combined"] else { throw .missingKey("combined") }
        guard let unmeasured = object["unmeasured"] else { throw .missingKey("unmeasured") }

        let privateLimb: Limb?
        if let status = privateValue.dictionary?["status"],
            try Swift.String(json: status) == "not-requested"
        {
            privateLimb = nil
        } else {
            privateLimb = try Limb(json: privateValue)
        }

        return Self(
            scope: scope,
            public: try Limb(json: publicValue),
            private: privateLimb,
            combined: try Limb(json: combined),
            unmeasured: try [Unmeasured](json: unmeasured)
        )
    }
}

extension Workspace.Inventory.Effective.Output.Limb: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "population": value.population.json,
            "digest": value.digest.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let population = object["population"] else { throw .missingKey("population") }
        guard let digest = object["digest"] else { throw .missingKey("digest") }
        return Self(
            population: try [Workspace.Repository](json: population),
            digest: try Swift.String(json: digest)
        )
    }
}

extension Workspace.Inventory.Effective.Output.Unmeasured: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "kind": value.kind.rawValue.json,
            "coordinate": value.coordinate.json,
            "reason": value.reason.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let kindValue = object["kind"] else { throw .missingKey("kind") }
        guard let kind = try Kind(rawValue: Swift.String(json: kindValue)) else {
            throw .typeMismatch(expected: "organization|repository", got: "unrecognised kind")
        }
        guard let coordinate = object["coordinate"] else { throw .missingKey("coordinate") }
        guard let reason = object["reason"] else { throw .missingKey("reason") }
        return Self(
            kind: kind,
            coordinate: try Swift.String(json: coordinate),
            reason: try Swift.String(json: reason)
        )
    }
}

extension Workspace.Inventory.Effective.Output {
    /// Writes the report to `path` atomically: the canonical bytes (sorted
    /// keys, no insignificant whitespace) terminated by one LF, staged in a
    /// temporary sibling and renamed into place, left at owner-read/write
    /// only (`0600`).
    ///
    /// The write refuses a target that already exists as anything but a
    /// regular file. A symlink target would let the rename follow — or
    /// replace — a redirection the caller never inspected, and a directory
    /// or device target is a caller error either way; both are refused
    /// before any byte is staged, inspecting the link itself rather than
    /// what it points at.
    public func write(to path: File.Path) throws(Workspace.Error) {
        if File.System.Stat.exists(at: path) || Self.isDanglingLink(at: path) {
            let info: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                info = try File.System.Stat.info(at: path, followSymlinks: false)
            } catch {
                throw .filesystem("cannot inspect the output target \(path): \(error)")
            }
            guard info.type == .regular else {
                throw .configuration(
                    "output target \(path) exists and is not a regular file; refusing to replace it"
                )
            }
        }

        let file = File(path)
        do throws(File.System.Write.Atomic.Error) {
            try file.write.atomic(canonical + "\n")
        } catch {
            throw .filesystem("cannot write the effective-inventory report \(path): \(error)")
        }
        do throws(File.System.Metadata.Permissions.Error) {
            try File.System.Metadata.Permissions.set([.ownerRead, .ownerWrite], at: path)
        } catch {
            throw .filesystem("cannot restrict the effective-inventory report \(path): \(error)")
        }
    }

    /// `Stat.exists` follows symlinks, so a link pointing nowhere reads as
    /// absent; the refusal above must still see it, or the atomic rename
    /// would silently replace the link.
    private static func isDanglingLink(at path: File.Path) -> Swift.Bool {
        do throws(Kernel.File.Stats.Error) {
            return try File.System.Stat.info(at: path, followSymlinks: false).type
                == .symbolicLink
        } catch {
            return false
        }
    }
}
