import File_System
import Foundation

@testable import Workspace_Application

extension Workspace.Doctor {
    /// A disposable checkout root whose toolchain interrogation is
    /// hermetic: the injected `tool` reports exactly the configured
    /// versions, so fixture runs never spawn processes.
    struct Fixture {
        let base: URL
        let directory: File.Directory
        let configuration: Workspace.Configuration

        init(repositories: [Workspace.Repository]) throws {
            base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            directory = try File.Directory(validating: base.path)
            configuration = .init(
                version: 1,
                scope: "test",
                swift: "6.3",
                xcode: "26.0",
                repositories: repositories
            )
        }
    }
}

extension Workspace.Doctor.Fixture {
    func doctor() -> Workspace.Doctor {
        .init(root: directory, configuration: configuration) { executable, _ in
            executable == "swift" ? "Swift version 6.3" : "Xcode 26.0"
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: base)
    }
}
