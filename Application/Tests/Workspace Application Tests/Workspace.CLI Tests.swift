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
