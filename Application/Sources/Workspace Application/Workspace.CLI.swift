public import Command
private import Environment
private import File_System
private import Process

extension Workspace {
    public struct CLI: Sendable, Command.`Protocol` {
        public var operation: Operation
        public var dry: Bool
        public var consumer: Swift.String
        public var dependency: Swift.String

        public init(
            operation: Operation = .sync,
            dry: Bool = false,
            consumer: Swift.String = "",
            dependency: Swift.String = ""
        ) {
            self.operation = operation
            self.dry = dry
            self.consumer = consumer
            self.dependency = dependency
        }
    }
}

extension Workspace.CLI {
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
                placeholder: "sync|doctor|compose|restore|verify",
                help: .init(abstract: "Operation to perform.")
            )
            Command.Flag(
                \.dry,
                name: .long(.literal("dry-run")),
                help: .init(abstract: "Plan synchronization without changing files or Git metadata.")
            )
            Command.Option(
                \.consumer,
                name: .long(.literal("consumer")),
                placeholder: "repository",
                help: .init(
                    abstract: "Workspace repository whose manifest is composed (compose/restore/verify)."
                )
            )
            Command.Option(
                \.dependency,
                name: .long(.literal("dependency")),
                placeholder: "repository",
                help: .init(
                    abstract: "Workspace repository redirected to a local source (compose/restore/verify)."
                )
            )
        }
    }

    public mutating func validate() throws(Command.Error) {
        if operation.composesADependency {
            guard !consumer.isEmpty else {
                throw .validationFailed(reason: "\(operation.argumentDescription) requires --consumer.")
            }
            guard !dependency.isEmpty else {
                throw .validationFailed(reason: "\(operation.argumentDescription) requires --dependency.")
            }
            guard !dry else {
                throw .validationFailed(reason: "--dry-run is valid only with sync.")
            }
        } else {
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are valid only with compose, restore, or verify."
                )
            }
            guard operation == .sync || !dry else {
                throw .validationFailed(reason: "--dry-run is valid only with sync.")
            }
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
            let report = await Workspace.Doctor(root: root, configuration: configuration).run()
            print(report)
            Process.Exit.normal(report.status)
        case .compose:
            try Workspace.Composition(root: root, configuration: configuration)
                .compose(consumer: consumer, dependency: dependency)
        case .restore:
            try Workspace.Composition(root: root, configuration: configuration)
                .restore(consumer: consumer, dependency: dependency)
        case .verify:
            try Workspace.Composition(root: root, configuration: configuration)
                .verify(consumer: consumer, dependency: dependency)
        }
    }
}
