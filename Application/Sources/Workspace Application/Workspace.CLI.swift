public import Command
private import Environment
private import File_System

extension Workspace {
    public struct CLI: Sendable, Command.`Protocol` {
        public var operation: Operation
        public var dry: Bool

        public init(operation: Operation = .sync, dry: Bool = false) {
            self.operation = operation
            self.dry = dry
        }

        public static var configuration: Command.Configuration {
            .init(
                name: "workspace",
                abstract: "Synchronize and diagnose the public Swift Institute workspace."
            )
        }

        public static var schema: Command.Schema.Definition<Self> {
            Command.Schema.Definition<Self> {
                Command.Positional(
                    \.operation,
                    name: "operation",
                    placeholder: "sync|doctor",
                    help: .init(abstract: "Operation to perform.")
                )
                Command.Flag(
                    \.dry,
                    name: .long(.literal("dry-run")),
                    help: .init(abstract: "Plan synchronization without changing files or Git metadata.")
                )
            }
        }

        public mutating func validate() throws(Command.Error) {
            guard operation == .sync || !dry else {
                throw .validationFailed(reason: "--dry-run is valid only with sync.")
            }
        }

        public mutating func run() async throws(Workspace.Error) {
            guard let working = Environment.read("PWD") else {
                throw .configuration("PWD is not available")
            }

            let root: File.Directory
            do throws(File.Path.Error) {
                root = try File.Directory(validating: working)
            } catch {
                throw .configuration("PWD is not a valid path: \(error)")
            }

            let configuration = try Workspace.Configuration.load(at: root)
            switch operation {
            case .sync:
                try Workspace.Sync(root: root, configuration: configuration).run(dry: dry)
            case .doctor:
                try Workspace.Doctor(root: root, configuration: configuration).run()
            }
        }
    }
}
