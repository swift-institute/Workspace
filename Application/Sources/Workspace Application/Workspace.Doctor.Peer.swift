internal import Async_Fanout
private import File_System
private import Git_Foundation

extension Workspace.Doctor {
    /// One peer-checkout subject: a peer institute registered in
    /// `Peers.json`, or one repository a materialized peer's inventory
    /// declares.
    public struct Peer: Equatable, Sendable {
        /// The peer institute the subject belongs to.
        public let ecosystem: Swift.String
        public let name: Swift.String
        /// The checkout-relative location the subject resolves at.
        public let location: Swift.String
        public let state: State

        public init(
            ecosystem: Swift.String,
            name: Swift.String,
            location: Swift.String,
            state: State
        ) {
            self.ecosystem = ecosystem
            self.name = name
            self.location = location
            self.state = state
        }
    }
}

extension Workspace.Doctor {
    /// Every registered peer resolves against its declared inventory —
    /// never against a tree walk — and every repository a materialized
    /// peer declares has a sound peer-layout location.
    ///
    /// Adoption is opt-in per checkout, so an unmaterialized peer and an
    /// undeclared-but-absent repository are facts, not findings. What
    /// fires is the state the peer mechanism exists to end — a
    /// materialized peer whose packages have no usable declaration
    /// (warning), and a declaration or location that is broken (error).
    public static let peerCheckout = Check<Peer>(
        name: "peer-checkout",
        scope: .contributor,
        controls: .init(
            positive: .init(
                ecosystem: "control",
                name: "control",
                location: "control",
                state: .invalid("control")
            ),
            negative: .init(
                ecosystem: "control",
                name: "control",
                location: "control",
                state: .canonical
            )
        )
    ) { subject in
        switch subject.state {
        case .optedOut, .declared, .canonical, .absent:
            []
        case .unindexed(let path):
            [
                .init(
                    severity: .warning,
                    message: "\(subject.name): materialized at \(subject.location) without an "
                        + "inventory at \(path); its packages cannot be resolved from a "
                        + "declaration — fast-forward the peer's control-plane checkout"
                )
            ]
        case .invalid(let reason):
            [
                .init(
                    severity: .error,
                    message: "\(subject.name): \(reason)"
                )
            ]
        }
    }

    /// One presence resolution per registered peer, plus two
    /// interrogations per repository a materialized peer declares — the
    /// layout preflight and the Git check — gathered concurrently per
    /// peer. The registry is the inventory: an empty registry measures an
    /// empty population as `ok`, never as `unmeasured`.
    func peerCheckout() async -> Outcome {
        var subjects = [Peer]()
        for peer in peers {
            let location = "../../\(peer.name)"
            let root: File.Directory
            do throws(Workspace.Error) {
                root = try self.root.peer(peer)
            } catch {
                subjects.append(
                    .init(
                        ecosystem: peer.name,
                        name: peer.name,
                        location: location,
                        state: .invalid("\(error)")
                    )
                )
                continue
            }
            switch Workspace.Peer.Presence.resolve(peer, at: root) {
            case .absent:
                subjects.append(
                    .init(
                        ecosystem: peer.name,
                        name: peer.name,
                        location: location,
                        state: .optedOut
                    )
                )
            case .missing(let path):
                subjects.append(
                    .init(
                        ecosystem: peer.name,
                        name: peer.name,
                        location: location,
                        state: .unindexed(path)
                    )
                )
            case .invalid(let reason):
                subjects.append(
                    .init(
                        ecosystem: peer.name,
                        name: peer.name,
                        location: location,
                        state: .invalid(reason)
                    )
                )
            case .declared(let configuration):
                subjects.append(
                    .init(
                        ecosystem: peer.name,
                        name: peer.name,
                        location: location,
                        state: .declared(repositories: configuration.repositories.count)
                    )
                )
                subjects += await fanout.map(
                    configuration.repositories,
                    completed: progress.steps(
                        "peer-checkout: gathered",
                        of: configuration.repositories.count
                    )
                ) { repository in
                    let reference = Workspace.Peer.Layout.reference(
                        for: repository,
                        in: peer.name
                    )
                    let repositoryLocation = "\(location)/\(reference)"
                    do throws(Workspace.Error) {
                        let directory = try Workspace.Peer.Layout.directory(
                            for: repository,
                            in: peer.name,
                            at: root
                        )
                        try Workspace.Root.preflight(directory, under: root)
                        let materialized = try self.checkout(at: directory)
                        return .init(
                            ecosystem: peer.name,
                            name: repository.name,
                            location: repositoryLocation,
                            state: materialized ? .canonical : .absent
                        )
                    } catch {
                        return .init(
                            ecosystem: peer.name,
                            name: repository.name,
                            location: repositoryLocation,
                            state: .invalid("\(error)")
                        )
                    }
                }
            }
        }
        return Self.peerCheckout.run(population: subjects, inventory: peers.count)
    }

    /// Whether `path` holds a Git repository.
    private func checkout(
        at path: File.Directory
    ) throws(Workspace.Error) -> Bool {
        guard path.stat.exists else {
            return false
        }
        return try execute { () throws(Git.Client.Error) -> Bool in
            try git.repository(at: path.description)
        }
    }
}
