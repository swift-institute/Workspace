public import File_System

extension Workspace.Peer {
    /// The single name → organization → path derivation for peer-institute
    /// checkouts — ``Workspace/Layout``'s counterpart for a peer root.
    ///
    /// A peer inventory is the sole authority for where a peer repository
    /// materializes: the location is a pure function of the record's
    /// `organization` and `name` under the peer's root, resolved here and
    /// nowhere else. No tool may walk a peer tree or infer a location from
    /// a repository's name.
    ///
    /// The rule: a repository owned by the peer's eponymous organization
    /// materializes directly under the peer root; a repository owned by
    /// any other organization nests one level deeper, under its
    /// organization directory. There is no layer level — peer institutes
    /// are organized org-per-domain.
    public enum Layout {}
}

extension Workspace.Peer.Layout {
    /// The relative path components of `repository`'s materialized
    /// checkout under the root of the peer named `ecosystem`.
    public static func components(
        for repository: Workspace.Peer.Repository,
        in ecosystem: Swift.String
    ) -> [Swift.String] {
        repository.organization == ecosystem
            ? [repository.name]
            : [repository.organization, repository.name]
    }

    /// The peer-root-relative reference rendered into reports — the
    /// components joined with `/`, never an absolute path.
    public static func reference(
        for repository: Workspace.Peer.Repository,
        in ecosystem: Swift.String
    ) -> Swift.String {
        components(for: repository, in: ecosystem).joined(separator: "/")
    }

    /// The materialized checkout directory for `repository` under the
    /// peer root `root`.
    public static func directory(
        for repository: Workspace.Peer.Repository,
        in ecosystem: Swift.String,
        at root: File.Directory
    ) throws(Workspace.Error) -> File.Directory {
        var directory = root
        for component in try validated(repository, in: ecosystem) {
            directory = directory[directory: component]
        }
        return directory
    }

    /// Validated path components for `repository`.
    static func validated(
        _ repository: Workspace.Peer.Repository,
        in ecosystem: Swift.String
    ) throws(Workspace.Error) -> [File.Path.Component] {
        var validated = [File.Path.Component]()
        for component in components(for: repository, in: ecosystem) {
            guard component != ".", component != ".." else {
                throw .configuration(
                    "invalid peer layout component \(component) for \(repository.name): traversal is forbidden"
                )
            }
            do throws(File.Path.Component.Error) {
                validated.append(try File.Path.Component(component))
            } catch {
                throw .configuration(
                    "invalid peer layout component \(component) for \(repository.name): \(error)"
                )
            }
        }
        return validated
    }
}
