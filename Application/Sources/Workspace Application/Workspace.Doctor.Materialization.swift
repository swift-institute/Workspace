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

    func materialization() -> Outcome {
        Self.materialization.run(
            population: selection.repositories.map { repository in
                let location = "../\(Workspace.Layout.reference(for: repository))"
                do throws(Workspace.Error) {
                    let canonical = try root.materialization(for: repository)
                    let legacy = try root.legacy(for: repository)
                    let current = try exists(at: canonical)
                    let superseded = try exists(at: legacy)
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
        try execute { () throws(Git.Client.Error) -> Bool in
            try git.repository(at: path.description)
        }
    }
}
