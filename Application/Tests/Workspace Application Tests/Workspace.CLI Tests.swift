import Command
import Testing

@testable import Workspace_Application

extension Workspace.CLI {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Workspace.CLI.Test.Unit {
    @Test
    func `sync selects mutating execution`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["sync"],
            initial: .init()
        )

        #expect(command.operation == .sync)
        #expect(!command.dry)
    }

    @Test
    func `sync dry run selects nonmutating execution`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["sync", "--dry-run"],
            initial: .init()
        )

        #expect(command.operation == .sync)
        #expect(command.dry)
    }

    @Test
    func `doctor selects diagnostic execution`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["doctor"],
            initial: .init()
        )

        #expect(command.operation == .doctor)
        #expect(!command.dry)
    }
}

extension Workspace.CLI.Test.`Edge Case` {
    @Test
    func `doctor rejects dry run`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["doctor", "--dry-run"],
                initial: .init()
            )
        }
    }
}

extension Workspace.CLI.Test.Unit {
    @Test(arguments: ["compose", "restore", "verify"])
    func `composition operations parse consumer and dependency`(
        operation: Swift.String
    ) throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: [operation, "--consumer", "swift-color", "--dependency", "swift-color-standard"],
            initial: .init()
        )

        #expect(command.operation.argumentDescription == operation)
        #expect(command.consumer == "swift-color")
        #expect(command.dependency == "swift-color-standard")
    }
}

extension Workspace.CLI.Test.`Edge Case` {
    @Test
    func `compose requires consumer`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["compose", "--dependency", "swift-color-standard"],
                initial: .init()
            )
        }
    }

    @Test
    func `compose requires dependency`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["compose", "--consumer", "swift-color"],
                initial: .init()
            )
        }
    }

    @Test
    func `sync rejects consumer and dependency`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["sync", "--consumer", "swift-color", "--dependency", "swift-color-standard"],
                initial: .init()
            )
        }
    }

    @Test
    func `compose rejects dry run`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["compose", "--consumer", "swift-color", "--dependency", "swift-color-standard", "--dry-run"],
                initial: .init()
            )
        }
    }
}
