extension Workspace.Selection {
    public func validated() throws(Workspace.Error) -> Self {
        guard version == 1 else {
            throw .configuration("unsupported \(Self.filename) version \(version)")
        }
        guard !repositories.isEmpty else {
            throw .configuration("\(Self.filename) selects no repositories")
        }

        var keys = Set<Workspace.Repository.Key>()
        for repository in repositories {
            guard keys.insert(repository).inserted else {
                throw .configuration(
                    "\(Self.filename) contains duplicate repository \(repository.identity)"
                )
            }
        }
        return self
    }

    /// Resolves the selection against the inventory, carrying `origin`
    /// through to the result.
    ///
    /// `origin` is not decoration. It decides which document a missing
    /// identity is attributed to, so a typo in a developer's local override
    /// is never reported as a defect in committed policy.
    public func resolved(
        in configuration: Workspace.Configuration,
        origin: Origin
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
            let added = Set(origin.added)
            var diagnostics = [Swift.String]()
            let committed = missing.filter { !added.contains($0) }
            if !committed.isEmpty {
                diagnostics.append(
                    "\(Self.filename) contains repository not present in Institute.json: "
                        + committed.map(\.identity).joined(separator: ", ")
                )
            }
            let local = missing.filter(added.contains)
            if !local.isEmpty {
                diagnostics.append(
                    "\(Override.filename) adds repository not present in Institute.json: "
                        + local.map(\.identity).joined(separator: ", ")
                )
            }
            throw .configuration(diagnostics.joined(separator: "; "))
        }
        return .init(repositories: repositories, origin: origin)
    }
}
