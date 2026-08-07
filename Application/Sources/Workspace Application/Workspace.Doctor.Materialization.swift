internal import Async_Fanout
private import File_System
private import Git_Foundation

extension Workspace.Doctor {
    /// One selected repository's presence on disk at its org-layout
    /// location.
    public struct Materialization: Equatable, Sendable {
        public let name: Swift.String
        /// The layout-relative location the repository materializes at.
        public let location: Swift.String
        public let state: State

        public init(name: Swift.String, location: Swift.String, state: State) {
            self.name = name
            self.location = location
            self.state = state
        }
    }
}

extension Workspace.Doctor {
    /// Every selected repository is materialized as a Git repository at
    /// its org-layout location.
    public static let materialization = Check<Materialization>(
        name: "materialization",
        scope: .contributor,
        controls: .init(
            positive: .init(name: "control", location: "control", state: .absent),
            negative: .init(name: "control", location: "control", state: .canonical)
        )
    ) { repository in
        switch repository.state {
        case .canonical:
            []
        case .legacy:
            [
                .init(
                    severity: .error,
                    message: "\(repository.name): present only at the superseded in-checkout "
                        + "location; expected \(repository.location) — legacy contents were not touched"
                )
            ]
        case .both:
            [
                .init(
                    severity: .error,
                    message: "\(repository.name): active at \(repository.location), but a superseded "
                        + "in-checkout materialization also remains and was not touched"
                )
            ]
        case .absent:
            [
                .init(
                    severity: .error,
                    message: "\(repository.name): missing or not a Git repository at \(repository.location)"
                )
            ]
        case .invalid(let diagnostic):
            [
                .init(
                    severity: .error,
                    message: "\(repository.name): invalid repository name: \(diagnostic)"
                )
            ]
        }
    }

    /// Two `git` interrogations per selected repository — the canonical
    /// location and the superseded in-checkout one — gathered concurrently.
    /// Each subject already resolves to a state of its own, so the gather
    /// has no order dependency and the population is rebuilt in selection
    /// order regardless of completion order.
    func materialization() async -> Outcome {
        Self.materialization.run(
            population: await fanout.map(
                selection.repositories,
                completed: progress.steps(
                    "materialization: gathered",
                    of: selection.repositories.count
                )
            ) { repository in
                let location = "../\(Workspace.Layout.reference(for: repository))"
                do throws(Workspace.Error) {
                    let canonical = try self.root.materialization(for: repository)
                    let legacy = try self.root.legacy(for: repository)
                    let current = try self.exists(at: canonical)
                    let superseded = try self.exists(at: legacy)
                    let state: Materialization.State
                    switch (current, superseded) {
                    case (true, false): state = .canonical
                    case (false, true): state = .legacy
                    case (true, true): state = .both
                    case (false, false): state = .absent
                    }
                    return .init(name: repository.name, location: location, state: state)
                } catch {
                    return .init(name: repository.name, location: location, state: .invalid("\(error)"))
                }
            },
            inventory: selection.repositories.count
        )
    }

    private func exists(
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
