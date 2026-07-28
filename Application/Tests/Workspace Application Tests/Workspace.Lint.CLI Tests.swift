import Command
import Testing

@testable import Workspace_Application

extension Workspace.CLI.Test {
    @Suite struct Lint {}
}

extension Workspace.CLI.Test.Lint {
    /// The sweep takes no mode. `workspace lint` is the ecosystem run;
    /// the tool operations are named.
    @Test
    func `a bare lint is the ecosystem sweep`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["lint"],
            initial: .init()
        )
        #expect(command.operation == .lint)
        #expect(command.modes.isEmpty)
        #expect(!command.changed)
    }

    @Test(arguments: [
        ("install", Workspace.CLI.Mode.install),
        ("check", Workspace.CLI.Mode.check),
    ])
    func `lint parses its tool operations`(
        argument: Swift.String,
        expected: Workspace.CLI.Mode
    ) throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["lint", argument],
            initial: .init()
        )
        #expect(command.operation == .lint)
        #expect(command.modes == [expected])
    }

    @Test
    func `the sweep accepts a changed scope`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["lint", "--changed"],
            initial: .init()
        )
        #expect(command.operation == .lint)
        #expect(command.changed)
    }

    /// The inner-loop verb, alongside `package build` and `package
    /// test`. Mirroring the existing shape is what makes it findable
    /// without being told.
    @Test
    func `package lint parses`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["package", "lint"],
            initial: .init()
        )
        #expect(command.operation == .package)
        #expect(command.modes == [.lint])
    }

    @Test
    func `package lint takes no fresh scratch`() {
        #expect(throws: Command.Error.self) {
            try Command.parse(
                Workspace.CLI.self,
                from: ["package", "lint", "--fresh"],
                initial: .init()
            )
        }
    }

    /// `--changed` on a single package would read as a filter and do
    /// nothing. A flag that silently has no effect is worse than one
    /// that is rejected.
    @Test(arguments: [
        ["package", "lint", "--changed"],
        ["lint", "check", "--changed"],
        ["doctor", "--changed"],
        ["sync", "--changed"],
    ])
    func `changed belongs to the sweep alone`(argument: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            try Command.parse(Workspace.CLI.self, from: argument, initial: .init())
        }
    }

    @Test(arguments: [
        ["lint", "serve"],
        ["lint", "build"],
        ["lint", "--package-path", "/tmp"],
        ["lint", "--consumer", "a", "--dependency", "b"],
        ["lint", "--dry-run"],
    ])
    func `lint rejects options that belong elsewhere`(argument: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            try Command.parse(Workspace.CLI.self, from: argument, initial: .init())
        }
    }
}
