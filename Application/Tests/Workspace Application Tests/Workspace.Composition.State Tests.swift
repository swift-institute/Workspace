import File_System
import Foundation
import JSON
import Testing

@testable import Workspace_Application

extension Workspace.Composition.State {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct Integration {}
    }
}

extension Workspace.Composition.State.Test.Unit {
    private typealias Record = Workspace.Composition.Record
    private typealias State = Workspace.Composition.State

    private static let record = Record(
        consumer: "swift-color",
        dependency: "swift-color-standard",
        declared: ".package(url: \"https://github.com/swift-standards/swift-color-standard.git\", branch: \"main\")",
        planned: ".package(path: \"/abs/Packages/swift-color-standard\")"
    )

    @Test
    func `a record round-trips through JSON`() throws {
        let json = Record.serialize(Self.record)
        let decoded = try Record.deserialize(json)
        #expect(decoded == Self.record)
    }

    @Test
    func `a ledger round-trips through JSON`() throws {
        let state = State(records: [Self.record])
        let decoded = try State(jsonString: state.jsonString())
        #expect(decoded == state)
    }

    @Test
    func `record lookup, add, and remove`() {
        let empty = State()
        #expect(empty.record(consumer: "swift-color", dependency: "swift-color-standard") == nil)

        let one = empty.adding(Self.record)
        #expect(one.record(consumer: "swift-color", dependency: "swift-color-standard") == Self.record)

        let gone = one.removing(consumer: "swift-color", dependency: "swift-color-standard")
        #expect(gone.records.isEmpty)
    }

    @Test
    func `deserialize rejects a mismatched version`() {
        #expect(throws: JSON.Error.self) {
            _ = try State(jsonString: "{\"version\": 999, \"compositions\": []}")
        }
    }
}

extension Workspace.Composition.State.Test.Integration {
    private typealias Record = Workspace.Composition.Record
    private typealias State = Workspace.Composition.State

    @Test
    func `an absent ledger loads as empty`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let root = try File.Directory(validating: base.path)
        #expect(try State.load(at: root).records.isEmpty)
    }

    @Test
    func `a saved ledger reloads equal`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let root = try File.Directory(validating: base.path)
        let state = State(records: [
            Record(
                consumer: "swift-color",
                dependency: "swift-color-standard",
                declared: ".package(url: \"https://github.com/swift-standards/swift-color-standard.git\", branch: \"main\")",
                planned: ".package(path: \"\(base.path)/Packages/swift-color-standard\")"
            )
        ])
        try state.save(at: root)
        #expect(try State.load(at: root) == state)

        // The ledger lives under the git-ignored .workspace/ directory.
        let ledger = base.appending(path: ".workspace/compositions.json")
        #expect(FileManager.default.fileExists(atPath: ledger.path))
    }
}
