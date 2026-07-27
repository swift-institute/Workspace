import File_System
import Foundation
import Testing

@testable import Workspace_Application

extension Workspace.Root {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Workspace.Root.Test.Unit {
    @Test
    func `a physical checkout owns a sibling materialization hierarchy`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let checkout = base.appending(path: "X/Workspace")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)

        let root = try Workspace.Root(checkout: File.Directory(validating: checkout.path))
        let canonical = try File.System.Canonical.resolve(File.Path(checkout.path))

        #expect(root.checkout.path == canonical)
        #expect(root.hierarchy == File.Directory(canonical).parent)
    }

    @Test
    func `a symlinked checkout resolves its physical checkout and sibling hierarchy`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let physical = base.appending(path: "physical/X/Workspace")
        let alias = base.appending(path: "alias-workspace")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: physical, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: physical)

        let root = try Workspace.Root(checkout: File.Directory(validating: alias.path))
        let canonical = try File.System.Canonical.resolve(File.Path(physical.path))

        #expect(root.checkout.path == canonical)
        #expect(root.hierarchy == File.Directory(canonical).parent)
        #expect(
            root.hierarchy
                != File.Directory(try File.System.Canonical.resolve(File.Path(base.path)))
        )
    }
}

extension Workspace.Root.Test.`Edge Case` {
    @Test
    func `a missing materialization hierarchy is admitted for later creation`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let checkout = base.appending(path: "Workspace")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        let root = try Workspace.Root(checkout: File.Directory(validating: checkout.path))
        let target = root.hierarchy[directory: "swift-standards"][directory: "swift-ietf"]

        try root.preflight(target, under: root.hierarchy)
    }

    @Test
    func `a regular file materialization prefix fails closed`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let checkout = base.appending(path: "Workspace")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        _ = FileManager.default.createFile(
            atPath: base.appending(path: "swift-foundations").path,
            contents: Data("collision".utf8)
        )
        let root = try Workspace.Root(checkout: File.Directory(validating: checkout.path))
        let target = root.hierarchy[directory: "swift-foundations"][directory: "swift-example"]

        #expect(throws: Workspace.Error.self) {
            try root.preflight(target, under: root.hierarchy)
        }
    }

    @Test
    func `a symbolic link materialization prefix fails closed`() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let checkout = base.appending(path: "Workspace")
        let outside = base.appending(path: "outside")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: base.appending(path: "swift-foundations"),
            withDestinationURL: outside
        )
        let root = try Workspace.Root(checkout: File.Directory(validating: checkout.path))
        let target = root.hierarchy[directory: "swift-foundations"][directory: "swift-example"]

        #expect(throws: Workspace.Error.self) {
            try root.preflight(target, under: root.hierarchy)
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: outside.appending(path: "swift-example").path
            )
        )
    }
}
