import Command
import Testing

@testable import Workspace_Application

extension Workspace.CLI.Test {
    @Suite struct Lint {}
}

extension Workspace.CLI.Test.Lint {
    /// The sweep takes no mode. `institute lint` is the ecosystem run;
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
    func `ledger accepts deterministic output and supplied coordinates`() throws {
        let revision = Swift.String(repeating: "a", count: 40)
        let command = try Command.parse(
            Workspace.CLI.self,
            from: [
                "lint", "ledger",
                "--format", "json",
                "--disposition", "PLAT-ARCH-022=remediation@swift-foundations/swift-linter#20",
                "--verification",
                "swift-primitives/swift-bytes@\(revision)="
                    + "https://github.com/swift-primitives/swift-bytes/actions/runs/42",
            ],
            initial: .init()
        )

        #expect(command.operation == .lint)
        #expect(command.modes == [.ledger])
        #expect(command.output == .json)
        #expect(command.dispositions.count == 1)
        #expect(command.verifications.count == 1)
    }

    @Test(arguments: [
        ["lint", "ledger", "--changed"],
        ["lint", "ledger", "--fix"],
        ["lint", "ledger", "--dry-run"],
        ["lint", "ledger", "--disposition", "not-a-coordinate"],
        ["lint", "ledger", "--verification", "not-a-coordinate"],
        ["lint", "--format", "json"],
        ["doctor", "--disposition", "RULE=remediation@owner/repository#1"],
    ])
    func `ledger rejects narrowing mutation and misplaced inputs`(arguments: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            try Command.parse(Workspace.CLI.self, from: arguments, initial: .init())
        }
    }

    @Test
    func `ledger rejects duplicate rule ownership before measuring`() {
        #expect(throws: Command.Error.self) {
            try Command.parse(
                Workspace.CLI.self,
                from: [
                    "lint", "ledger",
                    "--disposition", "RULE=retention@owner/repository#1",
                    "--disposition", "RULE=remediation@owner/repository#2",
                ],
                initial: .init()
            )
        }
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

extension Workspace.CLI.Test.Lint {
    @Test
    func `the sweep accepts a fix request`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["lint", "--fix"],
            initial: .init()
        )
        #expect(command.operation == .lint)
        #expect(command.fix)
        #expect(!command.dry)
    }

    /// `--dry-run` is otherwise rejected here; with `--fix` it is the
    /// preview of the rewrite, which is the one plan a lint run has to show.
    @Test
    func `a fix accepts a dry run`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["lint", "--fix", "--dry-run"],
            initial: .init()
        )
        #expect(command.fix)
        #expect(command.dry)
    }

    @Test
    func `a dry run without a fix is still rejected`() {
        #expect(throws: (any Swift.Error).self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["lint", "--dry-run"],
                initial: .init()
            )
        }
    }

    /// A fix is a rewrite, and the operations that cannot rewrite must say
    /// so rather than drop the flag — a silently ignored `--fix` leaves the
    /// caller reading findings and believing they are a repair record.
    @Test
    func `a fix outside lint is rejected`() {
        #expect(throws: (any Swift.Error).self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["doctor", "--fix"],
                initial: .init()
            )
        }
    }

    @Test
    func `package lint accepts a fix`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["package", "lint", "--fix"],
            initial: .init()
        )
        #expect(command.operation == .package)
        #expect(command.modes == [.lint])
        #expect(command.fix)
    }
}
