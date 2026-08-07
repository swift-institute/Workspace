public import File_System

extension Workspace {
    /// The single name → organization → path derivation for materialized
    /// checkouts (the org-hierarchy layout, ruling 139).
    ///
    /// `Institute.json` is the sole authority for where a repository
    /// materializes: the location is a pure function of the inventory
    /// entry's `organization`, `layer`, and `name` fields, resolved here
    /// and nowhere else. No tool may walk the tree or infer a location
    /// from a repository's name — packages sit at varying depths, and a
    /// walker with its own layout assumptions fails toward clean-looking
    /// empties.
    ///
    /// The rule: a layer's root directory is its root organization
    /// (``Workspace/Layer/organization``). A repository owned by that
    /// organization materializes directly under the root; a repository
    /// owned by any other organization — specification authorities,
    /// vendors, jurisdictions — nests one level deeper, under its
    /// organization inside the layer root. Materialized paths are
    /// regenerable state: when a repository transfers between
    /// organizations, the inventory changes and `sync` materializes the
    /// new location; nothing durable may treat a materialized path as
    /// stable.
    public enum Layout {}
}

extension Workspace.Layout {
    /// The relative path components of `repository`'s materialized
    /// checkout under a workspace root.
    public static func components(for repository: Workspace.Repository) -> [Swift.String] {
        let root = repository.layer.organization
        return repository.organization == root
            ? [root, repository.name]
            : [root, repository.organization, repository.name]
    }

    /// The relative reference rendered into generated documents — the
    /// components joined with `/`, never an absolute path.
    public static func reference(for repository: Workspace.Repository) -> Swift.String {
        components(for: repository).joined(separator: "/")
    }

    /// The materialized checkout directory for `repository` under `root`.
    public static func directory(
        for repository: Workspace.Repository,
        at root: File.Directory
    ) throws(Workspace.Error) -> File.Directory {
        try descend(root, through: validated(repository))
    }

    /// The directory the materialized checkout is cloned into — the
    /// layout path minus the repository's own component.
    public static func parent(
        for repository: Workspace.Repository,
        at root: File.Directory
    ) throws(Workspace.Error) -> File.Directory {
        try descend(root, through: validated(repository).dropLast())
    }

    /// Validated path components for `repository`.
    static func validated(
        _ repository: Workspace.Repository
    ) throws(Workspace.Error) -> [File.Path.Component] {
        var validated = [File.Path.Component]()
        for component in components(for: repository) {
            guard component != ".", component != ".." else {
                throw .configuration(
                    "invalid layout component \(component) for \(repository.name): traversal is forbidden"
                )
            }
            do throws(File.Path.Component.Error) {
                validated.append(try File.Path.Component(component))
            } catch {
                throw .configuration(
                    "invalid layout component \(component) for \(repository.name): \(error)"
                )
            }
        }
        return validated
    }

    private static func descend(
        _ root: File.Directory,
        through components: some Swift.Sequence<File.Path.Component>
    ) -> File.Directory {
        var directory = root
        for component in components {
            directory = directory[directory: component]
        }
        return directory
    }
}
