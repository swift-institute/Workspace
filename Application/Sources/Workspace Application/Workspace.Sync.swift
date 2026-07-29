private import File_System
public import Git_Foundation

extension Workspace {
    public struct Sync: Sendable {
        public let root: Workspace.Root
        public let selection: Workspace.Selection.Resolved
        public let client: Git.Client

        public init(
            root: Workspace.Root,
            selection: Workspace.Selection.Resolved,
            client: Git.Client = .init()
        ) {
            self.root = root
            self.selection = selection
            self.client = client
        }
    }
}

extension Workspace.Sync {
    public func run(dry: Bool) throws(Workspace.Error) {
        var inspections = [Workspace.Inspection]()
        for repository in selection.repositories {
            inspections.append(try inspect(repository, dry: dry))
        }
        let workspace = Workspace.Xcode.current(selection.repositories, at: root.checkout)

        print(selection.origin)
        print("Workspace sync plan")
        for inspection in inspections {
            print(
                "  \(Workspace.Layout.reference(for: inspection.repository)): \(inspection.action.text)"
            )
        }
        print("  institute.xcworkspace: \(workspace ? "current" : "generate")")
        // The scheme's contents are the selected packages' target names, so
        // it cannot be planned here: a repository this run is about to clone
        // has no manifest to read yet. It is rendered and compared after
        // materialization instead, and reported there.
        print("  \(Workspace.Xcode.Scheme.name).xcscheme: after materialization")

        guard !inspections.contains(where: { $0.action.fatal }) else {
            throw .repository("sync stopped before mutation because the plan contains conflicts")
        }
        guard !dry else {
            print("Dry run complete; no files or repositories were changed.")
            return
        }

        for inspection in inspections {
            let path = try root.materialization(for: inspection.repository)
            switch inspection.action {
            case .clone:
                let parent = try Workspace.Layout.parent(
                    for: inspection.repository,
                    at: root.hierarchy
                )
                try root.preflight(parent, under: root.hierarchy)
                do throws(File.System.Create.Directory.Error) {
                    try parent.create.recursive()
                } catch {
                    throw .filesystem("cannot create \(parent): \(error)")
                }
                try root.preflight(parent, under: root.hierarchy)
                try clone(inspection.repository, to: path)
            case .update(let remote):
                try root.preflight(path, under: root.hierarchy)
                try update(inspection.repository, to: remote, at: path)
            case .current, .skip:
                break
            case .fail:
                throw .repository("unreachable conflicting plan")
            }
        }

        if !workspace {
            try Workspace.Xcode.write(selection.repositories, at: root.checkout)
        }

        let buildables = try Workspace.Xcode.Scheme.buildables(
            for: selection.repositories,
            at: root
        )
        let scheme = Workspace.Xcode.Scheme.current(buildables, at: root.checkout)
        if !scheme {
            try Workspace.Xcode.Scheme.write(buildables, at: root.checkout)
        }
        print(
            "  \(Workspace.Xcode.Scheme.name).xcscheme: \(scheme ? "current" : "generated")"
                + " — \(buildables.count) targets across \(selection.repositories.count) packages"
        )
        print("Sync complete.")
    }

    /// A checkout of `repository` sitting somewhere in the hierarchy other
    /// than its layout path, or `nil`.
    ///
    /// ## Why this exists
    ///
    /// `inspect` used to consult only the layout path. When the layout changed
    /// — the inventory growing organization nesting, or a repository
    /// transferring between organizations — a checkout made under the previous
    /// layout stayed where it was, the layout path was empty, and `sync`
    /// cloned a **second working copy of the same repository into the same
    /// tree**. Nothing surfaced it: no conflict, no error, two trees free to
    /// drift apart.
    ///
    /// Measured 2026-07-28, that is exactly what happened to
    /// `swift-file-system`, `swift-json` and `swift-package-manager`, cloned
    /// flat at the hierarchy root before organization nesting existed. It cost
    /// nothing only because all three happened to be clean. **A displaced
    /// checkout carrying uncommitted work would have been silently orphaned**
    /// — still on disk, absent from the roster, and its work invisible to
    /// whoever next opened the canonical path.
    ///
    /// This reports rather than relocates. Moving a directory out from under
    /// whoever is working in it is the hazard, not the remedy; `sync`'s
    /// standing guarantee is that it never rewrites existing work.
    ///
    /// Identity is established by **remote URL, not by name** — a directory of
    /// the right name is not evidence that it is the same repository.
    private func displaced(
        _ repository: Workspace.Repository
    ) throws(Workspace.Error) -> File.Directory? {
        let canonical = Workspace.Layout.components(for: repository)
        let layer = repository.layer.organization

        // Bounded and enumerated: the layouts a checkout may predate. Not a
        // tree walk — a walker with its own layout assumptions is the failure
        // this whole module is written against.
        var candidates: [[Swift.String]] = [
            [repository.name],  // flat at the hierarchy root, pre-nesting
            [layer, repository.name],  // in the layer root, un-nested
            [layer, repository.organization, repository.name],  // nested
        ]
        candidates.removeAll { $0 == canonical }

        for components in candidates {
            var directory = root.hierarchy
            var valid = true
            for component in components {
                do throws(File.Path.Component.Error) {
                    directory = directory[directory: try File.Path.Component(component)]
                } catch {
                    valid = false
                    break
                }
            }
            guard valid else { continue }

            let candidate = File(directory.path)
            guard candidate.stat.exists, candidate.stat.isDirectory else { continue }
            guard
                try execute({ () throws(Git.Client.Error) -> Bool in
                    try client.repository(at: directory.description)
                })
            else { continue }

            let remote = try execute { () throws(Git.Client.Error) -> Swift.String in
                try client.remote("origin", at: directory.description)
            }
            guard Self.sameRepository(remote, repository.url) else { continue }
            return directory
        }
        return nil
    }

    /// Whether two remote URLs name the same repository.
    ///
    /// Deliberately not `==`. A displaced checkout is frequently one a human
    /// made by hand, over SSH, while the inventory carries the canonical HTTPS
    /// URL — `git@github.com:owner/name.git` and
    /// `https://github.com/owner/name.git` are the same repository and compare
    /// unequal as strings. The first version of this check used `==`, and a
    /// live control proved it never fired: it planned a duplicate clone over a
    /// displaced checkout it had just been written to catch.
    ///
    /// This normalizes only enough to answer "same host and path" and is used
    /// solely to *refuse* an action. It is not an authorization check and must
    /// not become one.
    static func sameRepository(_ lhs: Swift.String, _ rhs: Swift.String) -> Bool {
        normalized(lhs) == normalized(rhs)
    }

    static func normalized(_ url: Swift.String) -> Swift.String {
        var value = url
        for prefix in ["https://", "http://", "ssh://", "git://"] where value.hasPrefix(prefix) {
            value = Swift.String(value.dropFirst(prefix.count))
            break
        }
        if value.hasPrefix("git@") {
            value = Swift.String(value.dropFirst("git@".count))
            // scp-style `host:owner/name` — the colon is the path separator.
            if let colon = value.firstIndex(of: ":") {
                value =
                    Swift.String(value[value.startIndex..<colon]) + "/"
                    + Swift.String(value[value.index(after: colon)...])
            }
        }
        if value.hasSuffix(".git") { value = Swift.String(value.dropLast(4)) }
        while value.hasSuffix("/") { value = Swift.String(value.dropLast()) }
        return value.lowercased()
    }

    private func inspect(
        _ repository: Workspace.Repository,
        dry: Bool
    ) throws(Workspace.Error) -> Workspace.Inspection {
        let path = try root.materialization(for: repository)
        let file = File(path.path)
        let main = try reference("refs/heads/main")

        guard file.stat.exists else {
            // Nothing at the canonical path does NOT mean nothing on disk.
            // Refuse rather than clone a second working copy — see `displaced`.
            if let existing = try displaced(repository) {
                return .init(
                    repository: repository,
                    action: .fail(
                        "already checked out at \(existing), which is not its layout path; "
                            + "move or remove that checkout, then sync"
                    )
                )
            }
            guard (try? client.probe(repository.url, ref: main)) != nil else {
                return .init(
                    repository: repository,
                    action: .fail("canonical origin/main is unavailable")
                )
            }
            return .init(repository: repository, action: .clone)
        }
        guard file.stat.isDirectory else {
            return .init(
                repository: repository,
                action: .fail("path exists and is not a directory")
            )
        }
        guard
            try execute({ () throws(Git.Client.Error) -> Bool in
                try client.repository(at: path.description)
            })
        else {
            return .init(
                repository: repository,
                action: .fail("path exists and is not a Git repository")
            )
        }

        let top = try execute { () throws(Git.Client.Error) -> Swift.String in
            try client.top(at: path.description)
        }
        let topPath: File.Path
        do throws(File.Path.Error) {
            topPath = try File.Path(top)
        } catch {
            throw .repository("Git returned an invalid repository root for \(path): \(error)")
        }
        let isTop: Bool
        do {
            isTop = try File.System.same(topPath, path.path)
        } catch {
            throw .filesystem("cannot compare repository roots for \(path): \(error)")
        }
        guard isTop else {
            return .init(
                repository: repository,
                action: .fail("path is nested inside another Git repository")
            )
        }

        let remote = try execute { () throws(Git.Client.Error) -> Swift.String in
            try client.remote("origin", at: path.description)
        }
        guard remote == repository.url else {
            return .init(
                repository: repository,
                action: .fail("origin is \(remote), expected \(repository.url)")
            )
        }

        let branch = try execute { () throws(Git.Client.Error) -> Swift.String in
            try client.branch(at: path.description)
        }
        guard branch == "main" else {
            return .init(
                repository: repository,
                action: .skip("current branch is \(branch.isEmpty ? "detached" : branch)")
            )
        }
        guard
            try execute({ () throws(Git.Client.Error) -> [Git.Status.Entry] in
                try client.status(at: path.description)
            }).isEmpty
        else {
            return .init(repository: repository, action: .skip("worktree is dirty"))
        }
        guard
            try execute({ () throws(Git.Client.Error) -> Swift.String in
                try client.upstream("main", at: path.description)
            }) == "origin/main"
        else {
            return .init(
                repository: repository,
                action: .fail("local main does not track origin/main")
            )
        }

        let knownAhead = try execute { () throws(Git.Client.Error) -> Int in
            try client.count("origin/main..main", at: path.description)
        }
        guard knownAhead == 0 else {
            return .init(
                repository: repository,
                action: .skip("local main has \(knownAhead) unpushed commit(s)")
            )
        }

        let advertisement: Git.Ref.Advertisement
        do throws(Git.Client.Error) {
            advertisement = try client.probe(repository.url, ref: main)
        } catch {
            return .init(
                repository: repository,
                action: .fail("cannot inspect canonical origin/main")
            )
        }
        let head = try execute { () throws(Git.Client.Error) -> Git.Object.ID in
            try client.head("main", at: path.description)
        }
        guard head != advertisement.object else {
            return .init(repository: repository, action: .current)
        }
        guard !dry else {
            return .init(
                repository: repository,
                action: .skip("remote update requires a non-dry sync to validate")
            )
        }
        guard
            try remoteContains(
                head,
                remote: advertisement.object,
                repository: repository,
                beside: path
            )
        else {
            return .init(
                repository: repository,
                action: .skip("local main is ahead of or diverged from canonical origin/main")
            )
        }
        return .init(repository: repository, action: .update(advertisement.object))
    }

    private func remoteContains(
        _ local: Git.Object.ID,
        remote: Git.Object.ID,
        repository: Workspace.Repository,
        beside path: File.Directory
    ) throws(Workspace.Error) -> Bool {
        let temporaryPath: File.Path
        do throws(File.Path.Temporary.Error) {
            temporaryPath = try File.Path.Temporary.sibling(
                of: path.path,
                prefix: ".workspace-\(repository.name)-",
                suffix: ".inspection.git"
            )
        } catch {
            throw .filesystem("cannot create an inspection path for \(repository.name): \(error)")
        }
        let temporary = File.Directory(temporaryPath)
        try root.preflight(temporary, under: root.hierarchy)
        // Best-effort cleanup of an inspection clone; a failure to remove
        // it must not mask the inspection's own result. `do/catch` so the
        // discard is local and visible, with the error type named.
        defer {
            do throws(File.System.Delete.Error) {
                try temporary.delete.recursive()
            } catch {}
        }

        do throws(Git.Client.Error) {
            try client.clone(
                repository.url,
                branch: "main",
                bare: true,
                to: temporary.description
            )
            return try client.ancestor(
                local,
                of: remote,
                at: temporary.description
            )
        } catch {
            return false
        }
    }

    private func update(
        _ repository: Workspace.Repository,
        to remote: Git.Object.ID,
        at path: File.Directory
    ) throws(Workspace.Error) {
        try root.preflight(path, under: root.hierarchy)
        let main = try reference("refs/heads/main")
        let advertisement = try execute { () throws(Git.Client.Error) -> Git.Ref.Advertisement in
            try client.probe(repository.url, ref: main)
        }
        guard advertisement.object == remote else {
            throw .repository(
                "\(repository.name): canonical origin/main changed after validation; run sync again"
            )
        }

        let originMain = try reference("refs/remotes/origin/main")
        try execute { () throws(Git.Client.Error) -> Void in
            try client.fetch(
                "origin",
                object: remote,
                into: originMain,
                at: path.description
            )
            try client.merge(originMain.rawValue, mode: .fast, at: path.description)
        }
    }

    private func clone(
        _ repository: Workspace.Repository,
        to path: File.Directory
    ) throws(Workspace.Error) {
        try root.preflight(path, under: root.hierarchy)
        let temporaryPath: File.Path
        do throws(File.Path.Temporary.Error) {
            temporaryPath = try File.Path.Temporary.sibling(
                of: path.path,
                prefix: ".workspace-\(repository.name)-",
                suffix: ".clone"
            )
        } catch {
            throw .filesystem("cannot create a staging path for \(repository.name): \(error)")
        }
        let temporary = File.Directory(temporaryPath)
        try root.preflight(temporary, under: root.hierarchy)

        do throws(Workspace.Error) {
            try execute { () throws(Git.Client.Error) -> Void in
                try client.clone(repository.url, to: temporary.description)
            }
        } catch {
            // Cleanup discard is deliberate — the clone error below is the
            // one worth reporting, not a failure to remove the staging dir.
            do throws(File.System.Delete.Error) {
                try temporary.delete.recursive()
            } catch {}
            throw error
        }

        try root.preflight(temporary, under: root.hierarchy)
        try root.preflight(path, under: root.hierarchy)
        do throws(File.System.Move.Error) {
            try temporary.move.to(path)
        } catch {
            // Cleanup discard is deliberate — the move error below is the
            // one worth reporting, not a failure to remove the staging dir.
            do throws(File.System.Delete.Error) {
                try temporary.delete.recursive()
            } catch {}
            throw .filesystem("cannot install \(repository.name): \(error)")
        }

        try root.preflight(path, under: root.hierarchy)
        try execute { () throws(Git.Client.Error) -> Void in
            try client.switch("main", at: path.description)
        }
        try execute { () throws(Git.Client.Error) -> Void in
            try client.track("main", upstream: "origin/main", at: path.description)
        }
    }

    private func reference(_ value: Swift.String) throws(Workspace.Error) -> Git.Ref.Name {
        do throws(Git.Ref.Name.Error) {
            return try Git.Ref.Name(value)
        } catch {
            throw .repository("invalid Git reference \(value): \(error)")
        }
    }

    private func execute<Result>(
        _ operation: () throws(Git.Client.Error) -> Result
    ) throws(Workspace.Error) -> Result {
        do throws(Git.Client.Error) {
            return try operation()
        } catch {
            throw .process("Git operation failed: \(error)")
        }
    }
}
