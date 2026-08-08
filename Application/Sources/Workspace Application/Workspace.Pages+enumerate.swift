public import Async_Fanout
internal import File_System
public import Git_Foundation

extension Workspace.Pages {
    /// Derives the canonical page inventory for `selection` — population
    /// comes solely from `Workspace.Selection.Resolved.repositories`
    /// (itself derived from `Institute.json`), never from a directory walk
    /// of the checkout root (issue #82's derivation rule 1).
    ///
    /// One Git interrogation pair per selected repository (canonical and
    /// legacy location), gathered concurrently through ``Workspace/Fanout``
    /// — the population is rebuilt in selection order regardless of
    /// completion order, exactly as ``Workspace/Doctor/materialization()``
    /// already does.
    public static func enumerate(
        root: Workspace.Root,
        selection: Workspace.Selection.Resolved,
        git: Git.Client = .init(),
        fanout: Workspace.Fanout = .init()
    ) async -> Inventory {
        let canonicalSelection: Swift.Bool
        if case .committed = selection.origin { canonicalSelection = true } else { canonicalSelection = false }
        let selectionField = canonicalSelection ? "policy" : Self.narrowingDescription(selection.origin)

        // Derivation rule 6: total, byte-lexicographic ordering by
        // (organization, name) — never filesystem or completion order.
        let sortedRepositories = selection.repositories.sorted {
            ($0.organization, $0.name) < ($1.organization, $1.name)
        }

        let repositories = await fanout.map(sortedRepositories) { repository in
            Self.enumerate(repository, root: root, git: git)
        }

        // Derivation rule 3: the organization set is a projection of
        // `Workspace.Repository.organization` over the selected roster,
        // not a hand-written list and not `Workspace.Layer.organization`.
        let organizations = Swift.Set(sortedRepositories.map(\.organization)).sorted()
        let organizationProfilePages = organizations.map { organization in
            Page(
                organization: organization,
                name: "",
                layer: nil,
                kind: .organizationProfile,
                path: "profile/README.md",
                // `<organization>/.github` is never itself a selected
                // inventory repository (Institute.json enumerates no
                // `.github` repositories), so this instrument has no
                // checkout to test existence against — `present` is
                // recorded `false` rather than guessed.
                present: false
            )
        }

        return Inventory(
            instrument: .init(
                workspaceCommit: Self.line(
                    try? Workspace.Doctor.spawn(
                        "git",
                        arguments: ["-C", root.checkout.description, "rev-parse", "HEAD"]
                    )
                ),
                workspaceJsonBlob: Self.line(
                    try? Workspace.Doctor.spawn(
                        "git",
                        arguments: ["-C", root.checkout.description, "rev-parse", "HEAD:Institute.json"]
                    )
                ),
                selection: selectionField
            ),
            repositories: repositories,
            organizationProfilePages: organizationProfilePages
        )
    }

    private static func enumerate(
        _ repository: Workspace.Repository,
        root: Workspace.Root,
        git: Git.Client
    ) -> Repository {
        let state = Self.materializationState(for: repository, root: root, git: git)

        // Derivation rule 5: a repository whose materialization is not
        // `.canonical` carries its state and no pages — recorded, never
        // papered over with a directory walk this instrument is not
        // entitled to make.
        guard state == .canonical, let directory = try? root.materialization(for: repository) else {
            return .init(
                organization: repository.organization,
                name: repository.name,
                layer: repository.layer,
                materialization: state.rendered,
                pages: []
            )
        }

        let readme = Page(
            organization: repository.organization,
            name: repository.name,
            layer: repository.layer,
            kind: .readme,
            path: "README.md",
            present: directory[file: "README.md"].stat.exists
        )
        let docc = Self.doccPaths(at: directory).map { path in
            Page(
                organization: repository.organization,
                name: repository.name,
                layer: repository.layer,
                kind: .docc,
                path: path,
                present: true
            )
        }

        // Derivation rule 6: pages within a repository sorted by (kind raw
        // value, path).
        let pages = ([readme] + docc).sorted {
            ($0.kind.rawValue, $0.path) < ($1.kind.rawValue, $1.path)
        }

        return .init(
            organization: repository.organization,
            name: repository.name,
            layer: repository.layer,
            materialization: state.rendered,
            pages: pages
        )
    }

    /// The same canonical-vs-legacy-vs-both-vs-absent-vs-invalid
    /// determination ``Workspace/Doctor/materialization()`` makes, applied
    /// standalone here so this instrument depends only on `Workspace.Root`
    /// and `Git.Client`, never on a `Workspace.Doctor` instance.
    private static func materializationState(
        for repository: Workspace.Repository,
        root: Workspace.Root,
        git: Git.Client
    ) -> Workspace.Doctor.Materialization.State {
        do throws(Workspace.Error) {
            let canonicalLocation = try root.materialization(for: repository)
            let legacyLocation = try root.legacy(for: repository)
            let current = try Self.exists(at: canonicalLocation, git: git)
            let superseded = try Self.exists(at: legacyLocation, git: git)
            switch (current, superseded) {
            case (true, false): return .canonical
            case (false, true): return .legacy
            case (true, true): return .both
            case (false, false): return .absent
            }
        } catch {
            return .invalid("\(error)")
        }
    }

    private static func exists(
        at path: File.Directory,
        git: Git.Client
    ) throws(Workspace.Error) -> Swift.Bool {
        guard path.stat.exists else { return false }
        do throws(Git.Client.Error) {
            return try git.repository(at: path.description)
        } catch {
            throw .process("Git operation failed: \(error)")
        }
    }

    private static func narrowingDescription(_ origin: Workspace.Selection.Origin) -> Swift.String {
        "narrowed(+\(origin.added.count)/-\(origin.removed.count))"
    }

    private static func line(_ value: Swift.String?) -> Swift.String {
        guard let value else { return "unknown" }
        return value.split(separator: "\n").first.map(Swift.String.init) ?? "unknown"
    }
}
