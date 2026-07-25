import File_System
import Foundation
import Git_Foundation

@testable import Workspace_Application

extension Workspace.Sync {
    struct Fixture {
        let base: URL
        let root: URL
        let source: URL
        let remote: URL
        let local: URL
        let client: Git.Client

        init() throws {
            base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            root = base.appending(path: "Workspace")
            source = base.appending(path: "source")
            remote = base.appending(path: "remote.git")
            local = root.appending(path: "Packages/swift-example")
            client = .init()

            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: root.appending(path: "Packages"),
                withIntermediateDirectories: true
            )
            try client.initialize(at: source.path, bare: false)
            try command(["config", "user.email", "workspace@swift.institute"], at: source)
            try command(["config", "user.name", "Workspace Tests"], at: source)
            try command(["branch", "-M", "main"], at: source)
            try commit("first", contents: "first\n", at: source)
            try client.clone(source.path, branch: "main", bare: true, to: remote.path)
            try client.clone(remote.path, branch: "main", to: local.path)
        }

        func remove() {
            try? FileManager.default.removeItem(at: base)
        }

        func push(_ message: Swift.String, contents: Swift.String) throws {
            try commit(message, contents: contents, at: source)
            try command(["push", remote.path, "main"], at: source)
        }

        func replaceRemote() throws {
            let replacement = base.appending(path: "replacement")
            try client.initialize(at: replacement.path, bare: false)
            try command(["config", "user.email", "workspace@swift.institute"], at: replacement)
            try command(["config", "user.name", "Workspace Tests"], at: replacement)
            try command(["branch", "-M", "main"], at: replacement)
            try commit("replacement", contents: "replacement\n", at: replacement)
            try command(["push", "--force", remote.path, "main"], at: replacement)
        }

        func application() throws -> Workspace.Sync {
            let directory = try File.Directory(validating: root.path)
            return Workspace.Sync(
                root: directory,
                configuration: .init(
                    version: 1,
                    scope: "swift-institute",
                    swift: "6.3",
                    xcode: "26.0",
                    repositories: [
                        .init(name: "swift-example", url: remote.path, layer: .foundations)
                    ]
                ),
                client: client
            )
        }

        func state() throws -> State {
            .init(
                head: try client.head(at: local.path),
                origin: try client.head("origin/main", at: local.path),
                fetch: try? Data(contentsOf: local.appending(path: ".git/FETCH_HEAD")),
                status: try client.status(at: local.path)
            )
        }

        func residue() throws -> [Swift.String] {
            try FileManager.default.contentsOfDirectory(
                atPath: root.appending(path: "Packages").path
            ).filter { $0 != "swift-example" }
        }

        private func commit(
            _ message: Swift.String,
            contents: Swift.String,
            at repository: URL
        ) throws {
            try contents.write(
                to: repository.appending(path: "Fixture.txt"),
                atomically: true,
                encoding: .utf8
            )
            try command(["add", "Fixture.txt"], at: repository)
            try command(["commit", "-m", message], at: repository)
        }

        private func command(_ arguments: [Swift.String], at directory: URL) throws {
            let process = Foundation.Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.currentDirectoryURL = directory
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw CocoaError(.executableNotLoadable)
            }
        }
    }
}
