import File_System
import Foundation
import Git_Foundation

@testable import Workspace_Application

extension Workspace.Doctor {
    /// A disposable checkout root whose toolchain interrogation is
    /// hermetic: the injected `tool` reports exactly the configured
    /// versions and a bundled-toolchain layout, and the injected
    /// environment carries no override, so fixture runs never spawn
    /// processes and never read the real environment.
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
    /// The selected developer directory the hermetic interrogation
    /// reports.
    static let developer = "/Library/Developer/Xcode.app/Contents/Developer"

    /// The hermetic toolchain interrogation: configured versions, a
    /// `swift` resolved inside ``developer``, and silence for anything
    /// else.
    @Sendable static func interrogation(
        _ executable: Swift.String,
        _ arguments: [Swift.String]
    ) -> Swift.String {
        switch executable {
        case "swift": "Swift version 6.3"
        case "xcodebuild": "Xcode 26.0"
        case "xcode-select": "\(developer)\n"
        case "xcrun": "\(developer)/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift\n"
        default: ""
        }
    }

    func doctor(
        environment: @escaping @Sendable (Swift.String) -> Swift.String? = { _ in nil },
        tool:
            @escaping @Sendable (
                _ executable: Swift.String,
                _ arguments: [Swift.String]
            ) throws(Workspace.Error) -> Swift.String = Self.interrogation
    ) -> Workspace.Doctor {
        .init(
            root: directory,
            configuration: configuration,
            environment: environment,
            tool: tool
        )
    }

    /// Materializes `name` at its org-layout location as a real Git
    /// repository, so gathers that interrogate the checkout have a
    /// subject. The location is derived through ``Workspace/Layout``
    /// from the fixture's configuration — the fixture holds no layout
    /// assumption of its own.
    func materialize(_ name: Swift.String) throws {
        guard let repository = configuration.repositories.first(where: { $0.name == name }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let location = base.appending(path: Workspace.Layout.reference(for: repository))
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        try Git.Client().initialize(at: location.path, bare: false)
    }

    /// Writes `contents` at `relative` under the checkout root.
    func write(_ contents: Swift.String, to relative: Swift.String) throws {
        try contents.write(
            to: base.appending(path: relative),
            atomically: true,
            encoding: .utf8
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: base)
    }
}
