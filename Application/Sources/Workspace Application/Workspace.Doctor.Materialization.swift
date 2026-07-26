extension Workspace.Doctor {
    /// One inventory repository's presence on disk at its org-layout
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
    /// Every inventory repository is materialized as a Git repository at
    /// its org-layout location.
    public static let materialization = Check<Materialization>(
        name: "materialization",
        scope: .contributor,
        controls: .init(
            positive: .init(name: "control", location: "control", state: .absent),
            negative: .init(name: "control", location: "control", state: .materialized)
        )
    ) { repository in
        switch repository.state {
        case .materialized:
            []
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
            population: configuration.repositories.map { repository in
                let location = Workspace.Layout.reference(for: repository)
                return switch materialized(repository) {
                case .some: .init(name: repository.name, location: location, state: .materialized)
                case .none: .init(name: repository.name, location: location, state: state(of: repository))
                }
            },
            inventory: configuration.repositories.count
        )
    }

    private func state(of repository: Workspace.Repository) -> Materialization.State {
        do throws(Workspace.Error) {
            _ = try path(for: repository)
            return .absent
        } catch {
            return .invalid("\(error)")
        }
    }
}
