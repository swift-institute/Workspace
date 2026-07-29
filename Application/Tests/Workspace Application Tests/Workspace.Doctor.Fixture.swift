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
        let root: Workspace.Root
        let configuration: Workspace.Configuration
        let selection: Workspace.Selection.Resolved

        init(
            repositories: [Workspace.Repository],
            selected: [Workspace.Repository]? = nil,
            origin: Workspace.Selection.Origin? = nil
        ) throws {
            let temporary =
                FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            let checkout = temporary.appending(path: "Workspace")
            try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
            let workspaceRoot = try Workspace.Root(
                checkout: File.Directory(validating: checkout.path)
            )
            base = URL(
                fileURLWithPath: workspaceRoot.hierarchy.description,
                isDirectory: true
            )
            directory = workspaceRoot.checkout
            root = workspaceRoot
            configuration = .init(
                version: 1,
                scope: "test",
                swift: "6.3",
                xcode: "26.0",
                repositories: repositories
            )
            let chosen = selected ?? repositories
            selection = .init(repositories: chosen, origin: origin ?? .committed(count: chosen.count))
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
        // The real output shapes, so the parse is exercised rather than
        // assumed: `swift` reports through the driver line and prefixes
        // the vendor, and `xcodebuild` follows its version with a build.
        case "swift":
            "swift-driver version: 1.168.5 Apple Swift version 6.3 (swiftlang-6.3.0.1)\n"
                + "Target: arm64-apple-macosx26.0.0"
        case "xcodebuild": "Xcode 26.0\nBuild version 17A400"
        case "xcode-select": "\(developer)\n"
        case "xcrun": "\(developer)/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift\n"
        default: ""
        }
    }

    func doctor(
        progress: Workspace.Doctor.Progress = .silent,
        environment: @escaping @Sendable (Swift.String) -> Swift.String? = { _ in nil },
        tool:
            @escaping @Sendable (
                _ executable: Swift.String,
                _ arguments: [Swift.String]
            ) throws(Workspace.Error) -> Swift.String = Self.interrogation
    ) -> Workspace.Doctor {
        .init(
            root: root,
            configuration: configuration,
            selection: selection,
            progress: progress,
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
        let location = try root.materialization(for: repository)
        try FileManager.default.createDirectory(
            atPath: location.description,
            withIntermediateDirectories: true
        )
        try Git.Client().initialize(at: location.description, bare: false)
    }

    /// Materializes only the retired in-checkout location. This is deliberately
    /// separate from ``materialize(_:)`` so doctor tests cannot accidentally
    /// treat legacy state as canonical state.
    func materializeLegacy(_ name: Swift.String) throws {
        guard let repository = configuration.repositories.first(where: { $0.name == name }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let location = try root.legacy(for: repository)
        try FileManager.default.createDirectory(
            atPath: location.description,
            withIntermediateDirectories: true
        )
        try Git.Client().initialize(at: location.description, bare: false)
    }

    /// Writes `contents` at `relative` under the sibling hierarchy.
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
