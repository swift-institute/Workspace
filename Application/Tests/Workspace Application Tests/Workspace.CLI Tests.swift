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

    @Test(arguments: [
        ("install", Workspace.CLI.Mode.install),
        ("check", Workspace.CLI.Mode.check),
    ])
    func `context parses its operation`(
        argument: Swift.String,
        expected: Workspace.CLI.Mode
    ) throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["context", argument],
            initial: .init()
        )

        #expect(command.operation == .context)
        #expect(command.modes == [expected])
    }

    @Test(arguments: [
        ("install", Workspace.CLI.Mode.install),
        ("check", Workspace.CLI.Mode.check),
        ("serve", Workspace.CLI.Mode.serve),
    ])
    func `navigation parses its operation`(
        argument: Swift.String,
        expected: Workspace.CLI.Mode
    ) throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: [
                "navigation",
                argument,
                "--workspace-path",
                "/tmp/Workspace",
            ],
            initial: .init()
        )

        #expect(command.operation == .navigation)
        #expect(command.modes == [expected])
        #expect(command.workspacePath == "/tmp/Workspace")
    }

    @Test(arguments: [
        ("build", Workspace.CLI.Mode.build),
        ("test", Workspace.CLI.Mode.test),
        ("resolve", Workspace.CLI.Mode.resolve),
        ("dump-package", Workspace.CLI.Mode.dumpPackage),
    ])
    func `package parses its operation`(
        argument: Swift.String,
        expected: Workspace.CLI.Mode
    ) throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["package", argument, "--package-path", "/tmp/example"],
            initial: .init()
        )

        #expect(command.operation == .package)
        #expect(command.modes == [expected])
        #expect(command.packagePath == "/tmp/example")
    }

    @Test
    func `fresh package test parses`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["package", "test", "--fresh"],
            initial: .init()
        )

        #expect(command.fresh)
    }

    @Test
    func `package forwards repeated SwiftPM arguments`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: [
                "package", "test",
                "--argument=--filter",
                "--argument", "Performance",
            ],
            initial: .init()
        )

        #expect(command.arguments == ["--filter", "Performance"])
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

    @Test
    func `context requires an operation`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["context"],
                initial: .init()
            )
        }
    }

    @Test
    func `context rejects a package operation`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["context", "build"],
                initial: .init()
            )
        }
    }

    @Test
    func `navigation requires an operation`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["navigation"],
                initial: .init()
            )
        }
    }

    @Test
    func `navigation rejects a package operation`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["navigation", "build"],
                initial: .init()
            )
        }
    }

    @Test
    func `non-context operation rejects a context operation`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["sync", "install"],
                initial: .init()
            )
        }
    }

    @Test
    func `package requires an operation`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["package"],
                initial: .init()
            )
        }
    }

    @Test
    func `package rejects a context operation`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["package", "install"],
                initial: .init()
            )
        }
    }

    @Test
    func `fresh rejects package resolve`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["package", "resolve", "--fresh"],
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
