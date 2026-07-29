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
        /// The canonical, sibling materialization location.
        let local: URL
        /// The retired location inside the checkout. It must stay untouched.
        let legacy: URL
        let client: Git.Client

        init() throws {
            let temporary =
                FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
            base = URL(
                fileURLWithPath:
                    try File.System.Canonical.resolve(File.Path(temporary.path)).description,
                isDirectory: true
            )
            root = base.appending(path: "Workspace")
            source = base.appending(path: "source")
            remote = base.appending(path: "remote.git")
            local = base.appending(path: "swift-foundations/swift-example")
            legacy = root.appending(path: "swift-foundations/swift-example")
            client = .init()

            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: base.appending(path: "swift-foundations"),
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
    }
}

extension Workspace.Sync.Fixture {
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
        let repository = Workspace.Repository(
            name: "swift-example",
            url: remote.path,
            organization: "swift-foundations",
            layer: .foundations
        )
        return Workspace.Sync(
            root: try Workspace.Root(checkout: directory),
            selection: .init(repositories: [repository], origin: .committed(count: 1)),
            client: client
        )
    }

    func state() throws -> State {
        .init(
            head: try client.head(at: local.path),
            origin: try client.head("origin/main", at: local.path),
            fetch: try? Data(contentsOf: local.appending(path: ".git/FETCH_HEAD")),
            status: try client.status(at: local.path),
            workspace: try? Data(contentsOf: root.appending(path: "institute.xcworkspace/contents.xcworkspacedata")),
            ledger: try? Data(contentsOf: root.appending(path: ".workspace/compositions.json")),
            canonical: try entries(at: base.appending(path: "swift-foundations")),
            legacy: try entries(at: root.appending(path: "swift-foundations"))
        )
    }

    func residue() throws -> [Swift.String] {
        try FileManager.default.contentsOfDirectory(
            atPath: base.path
        )
        .filter { $0.hasPrefix(".workspace-") }
        .sorted()
    }

    private func entries(at directory: URL) throws -> [Swift.String] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.subpathsOfDirectory(atPath: directory.path).sorted()
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
