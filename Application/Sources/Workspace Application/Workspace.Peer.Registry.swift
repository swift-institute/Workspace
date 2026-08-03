public import File_System
public import JSON

extension Workspace.Peer {
    /// The committed peer-institute register — `Peers.json` at the
    /// Workspace checkout root.
    ///
    /// The registry names which peer institutes this Workspace knows how
    /// to resolve and where each peer's own inventory file lives relative
    /// to its root. It carries no peer package records: those belong to
    /// the peer's inventory (``Workspace/Peer/Configuration``), inside the
    /// peer's own tree, so peer package ownership stays with the peer.
    /// An absent `Peers.json` is an empty registry, never an error — the
    /// mechanism is additive and a checkout without it behaves exactly as
    /// before peers existed.
    public struct Registry: Equatable, Sendable, JSON.Serializable {
        public let version: Int
        public let peers: [Workspace.Peer]

        public init(version: Int, peers: [Workspace.Peer]) {
            self.version = version
            self.peers = peers
        }
    }
}

extension Workspace.Peer.Registry {
    /// Loads and validates `Peers.json` at `root`, or returns the empty
    /// registry when the file does not exist.
    public static func load(at root: File.Directory) throws(Workspace.Error) -> Self {
        let file = root[file: "Peers.json"]
        guard file.stat.exists else {
            return .init(version: 1, peers: [])
        }
        let bytes: [Byte]
        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try file.read.full { span in
                var storage = [Byte]()
                storage.reserveCapacity(span.count)
                for index in span.indices {
                    storage.append(span[index])
                }
                return storage
            }
        } catch {
            throw .configuration("cannot read \(file): \(error)")
        }

        let registry: Self
        do throws(JSON.Error) {
            registry = try .init(
                jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self)
            )
        } catch {
            throw .configuration("cannot decode \(file): \(error)")
        }

        return try registry.validated()
    }

    /// Validates the registry: a supported version, unique peer names,
    /// every name a single path component, and every inventory path
    /// relative with no traversal.
    public func validated() throws(Workspace.Error) -> Self {
        guard version == 1 else {
            throw .configuration("unsupported Peers.json version \(version)")
        }
        var names = Set<Swift.String>()
        for peer in peers {
            guard names.insert(peer.name).inserted else {
                throw .configuration("Peers.json contains duplicate peer name \(peer.name)")
            }
            guard Self.component(peer.name) else {
                throw .configuration(
                    "Peers.json peer name \(peer.name) is not a single path component"
                )
            }
            let components = peer.inventory.split(separator: "/", omittingEmptySubsequences: false)
            guard
                !components.isEmpty,
                components.allSatisfy({ Self.component(Swift.String($0)) })
            else {
                throw .configuration(
                    """
                    Peers.json peer \(peer.name) declares inventory path \(peer.inventory); \
                    the path must be relative with no traversal components
                    """
                )
            }
        }
        return self
    }

    private static func component(_ candidate: Swift.String) -> Swift.Bool {
        guard !candidate.isEmpty, candidate != ".", candidate != ".." else {
            return false
        }
        do throws(File.Path.Component.Error) {
            _ = try File.Path.Component(candidate)
        } catch {
            return false
        }
        return true
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "peers": value.peers.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Set<Swift.String> = ["version", "peers"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "Peers keys version and peers",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let peers = object["peers"] else { throw .missingKey("peers") }

        return try Self(
            version: Int(json: version),
            peers: [Workspace.Peer](json: peers)
        )
    }
}
