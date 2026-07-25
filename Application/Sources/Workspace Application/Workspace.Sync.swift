public import File_System
public import Git_Foundation

extension Workspace {
    public struct Sync: Sendable {
        public let root: File.Directory
        public let configuration: Configuration
        public let client: Git.Client

        public init(
            root: File.Directory,
            configuration: Configuration,
            client: Git.Client = .init()
        ) {
            self.root = root
            self.configuration = configuration
            self.client = client
        }
    }
}

extension Workspace.Sync {
    public func run(dry: Bool) throws(Workspace.Error) {
        let packages = root[directory: "Packages"]
        var inspections = [Workspace.Inspection]()
        for repository in configuration.repositories {
            inspections.append(try inspect(repository, in: packages, dry: dry))
        }
        let workspace = Workspace.Xcode.current(configuration.repositories, at: root)

        print("Workspace sync plan")
        for inspection in inspections {
            print("  \(inspection.repository.name): \(inspection.action.text)")
        }
        print("  institute.xcworkspace: \(workspace ? "current" : "generate")")

        guard !inspections.contains(where: { $0.action.fatal }) else {
            throw .repository("sync stopped before mutation because the plan contains conflicts")
        }
        guard !dry else {
            print("Dry run complete; no files or repositories were changed.")
            return
        }

        do throws(File.System.Create.Directory.Error) {
            try packages.create.recursive()
        } catch {
            throw .filesystem("cannot create \(packages): \(error)")
        }

        for inspection in inspections {
            let path = try path(for: inspection.repository, in: packages)
            switch inspection.action {
            case .clone:
                try clone(inspection.repository, to: path)
            case .update(let remote):
                try update(inspection.repository, to: remote, at: path)
            case .current, .skip:
                break
            case .fail:
                throw .repository("unreachable conflicting plan")
            }
        }

        if !workspace {
            try Workspace.Xcode.write(configuration.repositories, at: root)
        }
        print("Sync complete.")
    }

    private func inspect(
        _ repository: Workspace.Repository,
        in packages: File.Directory,
        dry: Bool
    ) throws(Workspace.Error) -> Workspace.Inspection {
        let path = try path(for: repository, in: packages)
        let file = File(path.path)
        let main = try reference("refs/heads/main")

        guard file.stat.exists else {
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

        try execute { () throws(Git.Client.Error) -> Void in
            try client.switch("main", at: path.description)
        }
        try execute { () throws(Git.Client.Error) -> Void in
            try client.track("main", upstream: "origin/main", at: path.description)
        }
    }

    private func path(
        for repository: Workspace.Repository,
        in packages: File.Directory
    ) throws(Workspace.Error) -> File.Directory {
        do throws(File.Path.Component.Error) {
            return packages[directory: try File.Path.Component(repository.name)]
        } catch {
            throw .configuration("invalid repository name \(repository.name): \(error)")
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
