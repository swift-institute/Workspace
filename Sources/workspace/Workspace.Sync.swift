public import Foundation

extension Workspace {
    public struct Sync {
        public let root: URL
        public let configuration: Configuration

        public init(root: URL, configuration: Configuration) {
            self.root = root
            self.configuration = configuration
        }

        public func run(dry: Bool) throws(Workspace.Error) {
            let packages = root.appending(path: "Packages")
            var inspections = [Inspection]()
            for repository in configuration.repositories {
                inspections.append(try inspect(repository, in: packages, dry: dry))
            }
            let workspace = Xcode.current(configuration.repositories, at: root)

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

            do {
                try FileManager.default.createDirectory(at: packages, withIntermediateDirectories: true)
            } catch {
                throw .filesystem("cannot create \(packages.path): \(error)")
            }

            for inspection in inspections {
                let path = packages.appending(path: inspection.repository.name)
                switch inspection.action {
                case .clone:
                    try clone(inspection.repository, to: path, in: packages)
                case .update:
                    _ = try Git.value(["merge", "--ff-only", "origin/main"], at: path)
                case .current, .skip:
                    break
                case .fail:
                    throw .repository("unreachable conflicting plan")
                }
            }

            if !workspace {
                try Xcode.write(configuration.repositories, at: root)
            }
            print("Sync complete.")
        }

        private func inspect(_ repository: Repository, in packages: URL, dry: Bool) throws(Workspace.Error) -> Inspection {
            let path = packages.appending(path: repository.name)
            guard FileManager.default.fileExists(atPath: path.path) else {
                let remote = try Git.run(["ls-remote", "--exit-code", repository.url, "refs/heads/main"])
                guard remote.code == 0 else {
                    return .init(repository: repository, action: .fail("canonical origin/main is unavailable"))
                }
                return .init(repository: repository, action: .clone)
            }
            let directory: Bool
            do {
                directory = try path.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            } catch {
                throw .filesystem("cannot inspect \(path.path): \(error)")
            }
            guard directory else {
                return .init(repository: repository, action: .fail("path exists and is not a directory"))
            }
            guard Git.exists(at: path) else {
                return .init(repository: repository, action: .fail("path exists and is not a Git repository"))
            }

            let top = try Git.value(["rev-parse", "--show-toplevel"], at: path)
            guard URL(fileURLWithPath: top).standardizedFileURL.path == path.standardizedFileURL.path else {
                return .init(repository: repository, action: .fail("path is nested inside another Git repository"))
            }
            let remote = try Git.value(["remote", "get-url", "origin"], at: path)
            guard remote == repository.url else {
                return .init(repository: repository, action: .fail("origin is \(remote), expected \(repository.url)"))
            }

            if dry {
                let remote = try Git.run(["ls-remote", "--exit-code", repository.url, "refs/heads/main"])
                guard remote.code == 0 else {
                    return .init(repository: repository, action: .fail("cannot inspect canonical origin/main"))
                }
                let head = try Git.value(["rev-parse", "main"], at: path)
                let revision = remote.text.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
                return .init(
                    repository: repository,
                    action: head == revision ? .current : .skip("remote update requires a non-dry sync to validate")
                )
            }

            _ = try Git.value(["fetch", "origin", "main"], at: path)
            let branch = try Git.branch(at: path)
            guard branch == "main" else {
                return .init(repository: repository, action: .skip("current branch is \(branch.isEmpty ? "detached" : branch)"))
            }
            guard try Git.clean(at: path) else {
                return .init(repository: repository, action: .skip("worktree is dirty"))
            }
            guard try Git.upstream(at: path) == "origin/main" else {
                return .init(repository: repository, action: .fail("local main does not track origin/main"))
            }

            let ahead = try Git.count("origin/main..main", at: path)
            let behind = try Git.count("main..origin/main", at: path)
            guard ahead == 0 else {
                return .init(repository: repository, action: .skip("local main has \(ahead) unpushed commit(s)"))
            }
            return .init(repository: repository, action: behind == 0 ? .current : .update)
        }

        private func clone(_ repository: Repository, to path: URL, in packages: URL) throws(Workspace.Error) {
            let temporary = packages.appending(path: ".workspace-\(repository.name)-\(UUID().uuidString)")
            let result = try Git.run(["clone", "--origin", "origin", repository.url, temporary.path])
            guard result.code == 0 else {
                try? FileManager.default.removeItem(at: temporary)
                throw .process("clone failed for \(repository.name): \(result.text.trimmingCharacters(in: .whitespacesAndNewlines))")
            }

            do {
                try FileManager.default.moveItem(at: temporary, to: path)
            } catch {
                try? FileManager.default.removeItem(at: temporary)
                throw .filesystem("cannot install \(repository.name): \(error)")
            }

            _ = try Git.value(["switch", "main"], at: path)
            _ = try Git.value(["branch", "--set-upstream-to=origin/main", "main"], at: path)
        }
    }
}
