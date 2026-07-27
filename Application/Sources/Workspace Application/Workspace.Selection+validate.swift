extension Workspace.Selection {
    public func validated() throws(Workspace.Error) -> Self {
        guard version == 1 else {
            throw .configuration("unsupported Selection.json version \(version)")
        }
        guard !repositories.isEmpty else {
            throw .configuration("Selection.json selects no repositories")
        }

        var keys = Set<Workspace.Repository.Key>()
        for repository in repositories {
            guard keys.insert(repository).inserted else {
                throw .configuration(
                    "Selection.json contains duplicate repository \(repository.identity)"
                )
            }
        }
        return self
    }

    public func resolved(
        in configuration: Workspace.Configuration
    ) throws(Workspace.Error) -> Resolved {
        let selection = try validated()
        let inventory = try configuration.validated()
        let selected = Set(selection.repositories)
        var found = Set<Workspace.Repository.Key>()
        var repositories = [Workspace.Repository]()

        for repository in inventory.repositories {
            guard let key = Workspace.Repository.Key(repository: repository) else {
                preconditionFailure("A validated inventory contains a noncanonical repository")
            }
            guard selected.contains(key) else { continue }
            found.insert(key)
            repositories.append(repository)
        }

        let missing = selected.subtracting(found).sorted(by: Workspace.Repository.Key.precedes)
        guard missing.isEmpty else {
            throw .configuration(
                "Selection.json contains repository not present in Workspace.json: "
                    + missing.map(\.identity).joined(separator: ", ")
            )
        }
        return .init(repositories: repositories)
    }
}
