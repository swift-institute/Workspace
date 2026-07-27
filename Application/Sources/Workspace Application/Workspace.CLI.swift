public import Command
private import Build_Coordinator
private import Environment
private import File_System
private import Process

extension Workspace {
    public struct CLI: Sendable, Command.`Protocol` {
        public var operation: Operation
        public var dry: Bool
        public var consumer: Swift.String
        public var dependency: Swift.String
        public var modes: [Mode]
        public var packagePath: Swift.String
        public var fresh: Bool
        public var arguments: [Swift.String]

        public init(
            operation: Operation = .sync,
            dry: Bool = false,
            consumer: Swift.String = "",
            dependency: Swift.String = "",
            modes: [Mode] = [],
            packagePath: Swift.String = "",
            fresh: Bool = false,
            arguments: [Swift.String] = []
        ) {
            self.operation = operation
            self.dry = dry
            self.consumer = consumer
            self.dependency = dependency
            self.modes = modes
            self.packagePath = packagePath
            self.fresh = fresh
            self.arguments = arguments
        }
    }
}

extension Workspace.CLI {
    public static var configuration: Command.Configuration {
        .init(
            name: "workspace",
            abstract: "Synchronize, diagnose, and operate the public Swift Institute workspace."
        )
    }

    public static var schema: Command.Schema.Definition<Self> {
        Command.Schema.Definition<Self> {
            Command.Positional(
                \.operation,
                name: "operation",
                placeholder: "sync|doctor|compose|restore|verify|context|package",
                help: .init(abstract: "Operation to perform.")
            )
            Command.Positional<Self, Mode>.Many(
                \.modes,
                name: "mode",
                placeholder: "install|check|build|test|run|resolve|update|clean|dump-package",
                arity: .atMost(1),
                help: .init(abstract: "Required after context or package.")
            )
            Command.Flag(
                \.dry,
                name: .long(.literal("dry-run")),
                help: .init(abstract: "Plan synchronization without changing files or Git metadata.")
            )
            Command.Flag(
                \.fresh,
                name: .long(.literal("fresh")),
                help: .init(abstract: "Use isolated scratch state for a package build or test.")
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
            Command.Option(
                \.packagePath,
                name: .long(.literal("package-path")),
                placeholder: "path",
                help: .init(
                    abstract: "Package root for a package operation (defaults to PWD)."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.arguments,
                name: .long(.literal("argument")),
                placeholder: "swiftpm-argument",
                help: .init(
                    abstract: "Argument forwarded to SwiftPM (repeatable; package operations only)."
                )
            )
        }
    }

    public mutating func validate() throws(Command.Error) {
        if operation == .context {
            guard
                modes.count == 1,
                modes.first == .install || modes.first == .check
            else {
                throw .validationFailed(reason: "context requires install or check.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with context."
                )
            }
            guard !dry else {
                throw .validationFailed(reason: "--dry-run is valid only with sync.")
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(reason: "--package-path is valid only with package.")
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .package {
            guard modes.count == 1, let action = modes.first?.buildAction else {
                throw .validationFailed(
                    reason: "package requires build, test, run, resolve, update, clean, or dump-package."
                )
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with package."
                )
            }
            guard !dry else {
                throw .validationFailed(reason: "--dry-run is valid only with sync.")
            }
            guard !fresh || action == .build || action == .test else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
        } else if operation.composesADependency {
            guard modes.isEmpty else {
                throw .validationFailed(reason: "install and check are valid only after context.")
            }
            guard !consumer.isEmpty else {
                throw .validationFailed(reason: "\(operation.argumentDescription) requires --consumer.")
            }
            guard !dependency.isEmpty else {
                throw .validationFailed(reason: "\(operation.argumentDescription) requires --dependency.")
            }
            guard !dry else {
                throw .validationFailed(reason: "--dry-run is valid only with sync.")
            }
            guard !fresh, packagePath.isEmpty else {
                throw .validationFailed(
                    reason: "--fresh and --package-path are valid only with package."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
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
            guard modes.isEmpty else {
                throw .validationFailed(reason: "install and check are valid only after context.")
            }
            guard !fresh, packagePath.isEmpty else {
                throw .validationFailed(
                    reason: "--fresh and --package-path are valid only with package."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        }
    }

    public mutating func run() async throws(Workspace.Error) {
        guard let working = Environment.read("PWD") else {
            throw .configuration("PWD is not available")
        }

        if case .package = operation {
            guard let action = modes.first?.buildAction else {
                throw .configuration("package operation was not provided")
            }
            let status: Swift.Int32
            do throws(Build.Error) {
                status = try Build.Coordinator().run(
                    action,
                    at: packagePath.isEmpty ? working : packagePath,
                    fresh: fresh,
                    arguments: arguments
                )
            } catch {
                throw .process("\(error)")
            }
            Process.Exit.normal(status)
        }

        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: working)
        } catch {
            throw .configuration("PWD is not a valid path: \(error)")
        }
        let root = try Workspace.Root(checkout: checkout)

        if case .context = operation {
            let context = try Workspace.Context(root: root)
            switch modes.first {
            case .some(.install):
                try context.install()
                print("context: installed and verified")
            case .some(.check):
                let diagnostics = try context.diagnostics()
                guard diagnostics.isEmpty else {
                    throw .configuration(diagnostics.joined(separator: "\n"))
                }
                print("context: current")
            case nil:
                throw .configuration("context operation was not provided")
            default:
                throw .configuration("context operation must be install or check")
            }
            return
        }

        let configuration = try Workspace.Configuration.load(at: root.checkout)
        switch operation {
        case .sync:
            let selection = try Workspace.Selection.load(at: root.checkout).resolved(in: configuration)
            try Workspace.Sync(root: root, selection: selection).run(dry: dry)
        case .doctor:
            let selection = try Workspace.Selection.load(at: root.checkout).resolved(in: configuration)
            let report = await Workspace.Doctor(
                root: root,
                configuration: configuration,
                selection: selection
            ).run()
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
        case .context:
            return
        case .package:
            return
        }
    }
}
