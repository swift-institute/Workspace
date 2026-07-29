extension Workspace.Selection.Override {
    /// Fails closed on an override that cannot mean one thing.
    ///
    /// The empty case is rejected rather than treated as a no-op: a file
    /// that overrides nothing still makes `doctor` report an override in
    /// effect, and a state that reads as a departure but is not one is the
    /// same class of defect as a check that reports "not run".
    public func validated() throws(Workspace.Error) -> Self {
        guard version == 1 else {
            throw .configuration("unsupported \(Self.filename) version \(version)")
        }
        guard !add.isEmpty || !remove.isEmpty else {
            throw .configuration(
                "\(Self.filename) adds and removes nothing; delete it rather than "
                    + "leaving an override that does not override"
            )
        }

        var added = Set<Workspace.Repository.Key>()
        for repository in add {
            guard added.insert(repository).inserted else {
                throw .configuration(
                    "\(Self.filename) adds duplicate repository \(repository.identity)"
                )
            }
        }
        var removed = Set<Workspace.Repository.Key>()
        for repository in remove {
            guard removed.insert(repository).inserted else {
                throw .configuration(
                    "\(Self.filename) removes duplicate repository \(repository.identity)"
                )
            }
        }

        let contradictions = added.intersection(removed)
            .sorted(by: Workspace.Repository.Key.precedes)
        guard contradictions.isEmpty else {
            throw .configuration(
                "\(Self.filename) both adds and removes: "
                    + contradictions.map(\.identity).joined(separator: ", ")
            )
        }
        return self
    }

    /// Applies the delta to the committed selection and returns the merged
    /// document.
    ///
    /// A stale delta fails rather than degrading quietly: adding something
    /// the committed selection already names, or removing something it does
    /// not, means the local file no longer describes a real departure from
    /// policy, and continuing would hide that from the developer holding it.
    /// The merged document keeps the committed order with additions
    /// appended; ordering has no effect on the checkout, which
    /// ``Workspace/Selection/resolved(in:origin:)`` derives from the
    /// inventory alone.
    public func applied(
        to selection: Workspace.Selection
    ) throws(Workspace.Error) -> Workspace.Selection {
        let committed = Set(selection.repositories)

        let redundant = add.filter(committed.contains)
            .sorted(by: Workspace.Repository.Key.precedes)
        guard redundant.isEmpty else {
            throw .configuration(
                "\(Self.filename) adds repositories \(Workspace.Selection.filename) "
                    + "already selects: "
                    + redundant.map(\.identity).joined(separator: ", ")
            )
        }

        let absent = remove.filter { !committed.contains($0) }
            .sorted(by: Workspace.Repository.Key.precedes)
        guard absent.isEmpty else {
            throw .configuration(
                "\(Self.filename) removes repositories \(Workspace.Selection.filename) "
                    + "does not select: "
                    + absent.map(\.identity).joined(separator: ", ")
            )
        }

        let withheld = Set(remove)
        let repositories =
            selection.repositories.filter { !withheld.contains($0) } + add
        guard !repositories.isEmpty else {
            throw .configuration(
                "\(Self.filename) removes every repository \(Workspace.Selection.filename) "
                    + "selects; the merged selection is empty"
            )
        }
        return .init(version: selection.version, repositories: repositories)
    }
}
