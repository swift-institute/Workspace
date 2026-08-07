import Build_Coordinator
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
    func `install selects the command bootstrap`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["install"],
            initial: .init()
        )

        #expect(command.operation == .install)
        #expect(command.modes.isEmpty)
    }

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
        #expect(!command.institute)
    }

    @Test
    func `doctor institute selects the institute-internal checks`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["doctor", "--institute"],
            initial: .init()
        )

        #expect(command.operation == .doctor)
        #expect(command.institute)
    }

    @Test
    func `inventory selects the read-only register`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["inventory"],
            initial: .init()
        )

        #expect(command.operation == .inventory)
        #expect(command.modes.isEmpty)
        #expect(!command.dry)
    }

    @Test
    func `inventory regenerate selects mutating execution`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["inventory", "regenerate"],
            initial: .init()
        )

        #expect(command.operation == .inventory)
        #expect(command.modes == [.regenerate])
        #expect(!command.dry)
    }

    @Test
    func `inventory regenerate dry run selects nonmutating planning`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["inventory", "regenerate", "--dry-run"],
            initial: .init()
        )

        #expect(command.operation == .inventory)
        #expect(command.modes == [.regenerate])
        #expect(command.dry)
    }

    @Test
    func `inventory pages selects the read-only page enumeration`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["inventory", "pages"],
            initial: .init()
        )

        #expect(command.operation == .inventory)
        #expect(command.modes == [.pages])
        #expect(!command.dry)
    }

    @Test
    func `inventory pages rejects dry run because enumeration is already read-only`() {
        #expect(throws: Command.Error.self) {
            try Command.parse(
                Workspace.CLI.self,
                from: ["inventory", "pages", "--dry-run"],
                initial: .init()
            )
        }
    }

    @Test
    func `inventory effective parses its scope and output path`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: [
                "inventory", "effective",
                "--inventory-scope", "effective",
                "--inventory-output", "/tmp/effective.json",
            ],
            initial: .init()
        )

        #expect(command.operation == .inventory)
        #expect(command.modes == [.effective])
        #expect(command.inventoryScope == "effective")
        #expect(command.inventoryOutput == "/tmp/effective.json")
    }

    @Test
    func `inventory effective parses the public-only scope`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: [
                "inventory", "effective",
                "--inventory-scope", "public",
                "--inventory-output", "/tmp/effective.json",
            ],
            initial: .init()
        )

        #expect(command.modes == [.effective])
        #expect(command.inventoryScope == "public")
    }

    @Test
    func `inventory effective rejects dry run`() {
        #expect(throws: Command.Error.self) {
            try Command.parse(
                Workspace.CLI.self,
                from: [
                    "inventory", "effective",
                    "--inventory-scope", "public",
                    "--inventory-output", "/tmp/effective.json",
                    "--dry-run",
                ],
                initial: .init()
            )
        }
    }

    @Test
    func `inventory register rejects the effective-only report options`() {
        #expect(throws: Command.Error.self) {
            try Command.parse(
                Workspace.CLI.self,
                from: ["inventory", "--inventory-scope", "public"],
                initial: .init()
            )
        }
    }

    @Test
    func `dependencies parses deterministic output and policy exception inputs`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: [
                "dependencies",
                "--format", "json",
                "--sanctioned-exception", "apple/swift-crypto",
                "--sanctioned-exception", "swiftlang/swift-syntax",
            ],
            initial: .init()
        )

        #expect(command.operation == .dependencies)
        #expect(command.output == .json)
        #expect(
            command.sanctionedExceptions == [
                "apple/swift-crypto",
                "swiftlang/swift-syntax",
            ]
        )
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

    @Test
    func `context packet parses its bounded current Issue contract`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: [
                "context", "packet",
                "--issue", "swift-institute/Workspace#100",
                "--format", "json",
                "--max-bytes", "512",
                "--include-comment", "https://api.github.com/repos/swift-institute/Workspace/issues/comments/1",
            ],
            initial: .init()
        )

        #expect(command.modes == [.packet])
        #expect(command.issue == "swift-institute/Workspace#100")
        #expect(command.output == .json)
        #expect(command.maxBytes == 512)
        #expect(command.includedComments.count == 1)
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

    @Test(arguments: [
        Workspace.CLI.Mode.build,
        Workspace.CLI.Mode.test,
    ])
    func `jobs caps compile concurrency on package build or test`(
        mode: Workspace.CLI.Mode
    ) throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["package", mode.argumentDescription, "--jobs", "2"],
            initial: .init()
        )

        #expect(command.jobs == 2)
    }

    @Test
    func `jobs is nil by default, so the coordinator keeps choosing the machine's core count`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["package", "build"],
            initial: .init()
        )

        #expect(command.jobs == nil)
    }

    @Test
    func `the parsed jobs cap reaches the coordinator constructor unchanged`() throws {
        // Plumbing only: `run()` passes `jobs` straight into
        // `Build.Coordinator(jobs:)` without transforming it, so asserting
        // the constructor echoes the parsed value is the whole contract —
        // `Build.Coordinator` and `Build.Action` already prove the rest of
        // the chain (jobs reaching SwiftPM's `-j`) independently.
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["package", "test", "--jobs", "5"],
            initial: .init()
        )

        #expect(Build.Coordinator(jobs: command.jobs).jobs == 5)
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
    func `install takes no mode`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["install", "check"],
                initial: .init()
            )
        }
    }

    @Test
    func `install rejects package arguments`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["install", "--package-path", "Application"],
                initial: .init()
            )
        }
    }

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
    func `inventory rejects dry run because the register is already read-only`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["inventory", "--dry-run"],
                initial: .init()
            )
        }
    }

    @Test
    func `inventory rejects a mutating mode that is not regeneration`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["inventory", "update"],
                initial: .init()
            )
        }
    }

    @Test
    func `dependencies rejects malformed or duplicate exception inputs`() {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: ["dependencies", "--sanctioned-exception", "not-an-identity"],
                initial: .init()
            )
        }
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: [
                    "dependencies",
                    "--sanctioned-exception", "apple/swift-crypto",
                    "--sanctioned-exception", "apple/swift-crypto",
                ],
                initial: .init()
            )
        }
    }

    // A dropped `--institute` would print a report indistinguishable from
    // the one that measured the roster. Rejecting it is the point.
    @Test(arguments: [["sync"], ["inventory"], ["lint"], ["package", "build"]])
    func `institute is rejected outside doctor`(argument: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: argument + ["--institute"],
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

    // `Build.Action.acceptsJobs` covers run too, but the CLI surface stays
    // narrower than the API: build and test are the coordinated-build entry
    // points issue #88 asks for, and widening silently to `run` later is a
    // deliberate choice, not a side effect of this guard's shape.
    @Test(arguments: [
        ["package", "resolve"],
        ["package", "run"],
        ["package", "lint"],
        ["build"],
        ["sync"],
        ["doctor"],
    ])
    func `jobs is rejected outside package build or test`(argument: [Swift.String]) {
        #expect(throws: Command.Error.self) {
            _ = try Command.parse(
                Workspace.CLI.self,
                from: argument + ["--jobs", "2"],
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

extension Workspace.CLI.Test.Unit {
    @Test
    func `build selects the whole selection, not a package`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["build"],
            initial: .init()
        )

        #expect(command.operation == .build)
        #expect(command.modes.isEmpty)
        #expect(command.packagePath.isEmpty)
    }

    @Test
    func `build accepts isolated derived data and forwarded xcodebuild arguments`() throws {
        let command = try Command.parse(
            Workspace.CLI.self,
            from: ["build", "--fresh", "--argument", "CONFIGURATION=Release"],
            initial: .init()
        )

        #expect(command.operation == .build)
        #expect(command.fresh)
        #expect(command.arguments == ["CONFIGURATION=Release"])
    }
}

extension Workspace.CLI.Test.`Edge Case` {
    @Test
    func `build takes no mode`() {
        // `institute build build` would read as a package operation and is a
        // plausible slip; it must not silently mean the whole selection.
        #expect(throws: Command.Error.self) {
            var command = Workspace.CLI(operation: .build, modes: [.build])
            try command.validate()
        }
    }

    @Test
    func `build refuses a package path rather than narrowing to one package`() {
        #expect(throws: Command.Error.self) {
            var command = Workspace.CLI(operation: .build, packagePath: "/tmp/pkg")
            try command.validate()
        }
    }

    @Test
    func `build has no dry run`() {
        // There is nothing to plan: the selection and the scheme are already
        // on disk, and a build that changed nothing would still be a build.
        #expect(throws: Command.Error.self) {
            var command = Workspace.CLI(operation: .build, dry: true)
            try command.validate()
        }
    }
}
