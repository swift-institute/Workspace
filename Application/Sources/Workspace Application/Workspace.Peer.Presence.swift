public import File_System
import JSON

extension Workspace.Peer {
    /// One peer's state on this machine, resolved from its checkout —
    /// never from a remote.
    ///
    /// Adoption is opt-in per checkout: an absent peer root means the
    /// machine has not opted in, which is a fact and never a finding. A
    /// materialized root without a usable inventory is the state the peer
    /// mechanism exists to end — the peer's packages cannot be resolved
    /// without tree inference — so ``missing(_:)`` and ``invalid(_:)``
    /// stay distinct: the first is an un-adopted checkout, the second a
    /// broken declaration.
    public enum Presence: Equatable, Sendable {
        /// The peer root is not materialized; the checkout has not opted in.
        case absent
        /// The peer root exists but carries no inventory file at the
        /// declared path.
        case missing(Swift.String)
        /// The inventory file exists but cannot be decoded or validated.
        case invalid(Swift.String)
        /// The inventory is loaded and validated.
        case declared(Configuration)
    }
}

extension Workspace.Peer.Presence {
    /// Resolves `peer`'s presence from its root directory.
    ///
    /// `root` must already have passed the entry-containment preflight
    /// (``Workspace/Root/peer(_:)``); this reads only inside it.
    public static func resolve(
        _ peer: Workspace.Peer,
        at root: File.Directory
    ) -> Self {
        guard File(root.path).stat.isDirectory else {
            return .absent
        }

        let components: [File.Path.Component]
        do throws(File.Path.Component.Error) {
            components = try peer.inventory
                .split(separator: "/", omittingEmptySubsequences: true)
                .map { component throws(File.Path.Component.Error) in
                    try File.Path.Component(Swift.String(component))
                }
        } catch {
            return .invalid("invalid inventory path \(peer.inventory): \(error)")
        }
        guard let leaf = components.last else {
            return .invalid("peer \(peer.name) declares an empty inventory path")
        }
        var directory = root
        for component in components.dropLast() {
            directory = directory[directory: component]
        }
        let file = directory[file: leaf]
        guard file.stat.exists else {
            return .missing(peer.inventory)
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
            return .invalid("cannot read \(peer.inventory): \(error)")
        }

        let configuration: Workspace.Peer.Configuration
        do throws(JSON.Error) {
            configuration = try .init(
                jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self)
            )
        } catch {
            return .invalid("cannot decode \(peer.inventory): \(error)")
        }

        do throws(Workspace.Error) {
            return .declared(try configuration.validated(for: peer))
        } catch {
            return .invalid("\(error)")
        }
    }
}
