extension Workspace.Peer {
    /// One peer's printable inventory report — the peer counterpart of
    /// ``Workspace/Inventory/Register``, rendered by `institute inventory`.
    ///
    /// A view of an already resolved ``Workspace/Peer/Presence``; it
    /// performs no discovery and has no write capability. Paths are
    /// entry-relative — the peer's name followed by the record's
    /// ``Workspace/Peer/Layout`` reference — never absolute.
    public struct Report: Equatable, Sendable {
        public let peer: Workspace.Peer
        public let presence: Presence

        public init(peer: Workspace.Peer, presence: Presence) {
            self.peer = peer
            self.presence = presence
        }
    }
}

extension Workspace.Peer.Report: CustomStringConvertible {
    public var description: Swift.String {
        switch presence {
        case .absent:
            return "peer \(peer.name): not materialized (opt-in)"
        case .missing(let path):
            return "peer \(peer.name): materialized without an inventory at \(path)"
        case .invalid(let reason):
            return "peer \(peer.name): inventory unusable — \(reason)"
        case .declared(let configuration):
            return (
                [
                    "peer \(peer.name): \(configuration.repositories.count) repositories "
                        + "(name → organization → path)"
                ]
                + configuration.repositories.map { repository in
                    "  \(repository.name) → \(repository.organization) → "
                        + "\(peer.name)/"
                        + Workspace.Peer.Layout.reference(for: repository, in: peer.name)
                }
            )
            .joined(separator: "\n")
        }
    }
}
