private import File_System
public import Git_Foundation

extension Workspace.Doctor {
    /// One inventory repository's migration state from the superseded
    /// flat `Packages/` layout.
    public struct Migration: Equatable, Sendable {
        public let name: Swift.String
        /// The org-layout location the repository belongs at.
        public let expected: Swift.String
        public let state: State

        public init(name: Swift.String, expected: Swift.String, state: State) {
            self.name = name
            self.expected = expected
            self.state = state
        }
    }
}

extension Workspace.Doctor {
    /// No checkout lingers at the superseded flat `Packages/<name>`
    /// location. A flat checkout is a warning, not an error: it may hold
    /// unpushed work, so tooling reports it and never deletes it —
    /// re-running `sync` materializes the org layout alongside, and
    /// removal is a manual act after any local work is salvaged.
    public static let migration = Check<Migration>(
        name: "layout-migration",
        scope: .contributor,
        controls: .init(
            positive: .init(name: "control", expected: "control", state: .flat),
            negative: .init(name: "control", expected: "control", state: .clean)
        )
    ) { repository in
        switch repository.state {
        case .clean:
            []
        case .flat:
            [
                .init(
                    severity: .warning,
                    message: """
                        \(repository.name): a flat checkout remains at Packages/\(repository.name), \
                        superseded by the org layout at \(repository.expected) — re-run \
                        `workspace sync` to materialize it there, then remove the flat checkout \
                        manually once any local work in it is salvaged (tooling never deletes it)
                        """
                )
            ]
        }
    }

    func migration() -> Outcome {
        Self.migration.run(
            population: configuration.repositories.map { repository in
                .init(
                    name: repository.name,
                    expected: Workspace.Layout.reference(for: repository),
                    state: flat(repository) ? .flat : .clean
                )
            },
            inventory: configuration.repositories.count
        )
    }

    /// Whether a Git repository sits at the superseded flat location.
    private func flat(_ repository: Workspace.Repository) -> Bool {
        do throws(Workspace.Error) {
            let path = try Workspace.Layout.legacy(for: repository, at: root)
            return try execute { () throws(Git.Client.Error) -> Bool in
                try git.repository(at: path.description)
            }
        } catch {
            return false
        }
    }
}
