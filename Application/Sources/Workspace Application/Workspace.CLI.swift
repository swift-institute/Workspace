private import Build_Coordinator
public import Command
private import GitHub_HTTP
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
        public var workspacePath: Swift.String
        public var fresh: Bool
        public var changed: Bool
        public var institute: Bool
        public var arguments: [Swift.String]

        public init(
            operation: Operation = .sync,
            dry: Bool = false,
            consumer: Swift.String = "",
            dependency: Swift.String = "",
            modes: [Mode] = [],
            packagePath: Swift.String = "",
            workspacePath: Swift.String = "",
            fresh: Bool = false,
            changed: Bool = false,
            institute: Bool = false,
            arguments: [Swift.String] = []
        ) {
            self.operation = operation
            self.dry = dry
            self.consumer = consumer
            self.dependency = dependency
            self.modes = modes
            self.packagePath = packagePath
            self.workspacePath = workspacePath
            self.fresh = fresh
            self.changed = changed
            self.institute = institute
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
                placeholder:
                    "install|sync|build|doctor|inventory|compose|restore|verify|context|navigation|package|lint",
                help: .init(abstract: "Operation to perform.")
            )
            Command.Positional<Self, Mode>.Many(
                \.modes,
                name: "mode",
                placeholder:
                    "install|check|serve|build|test|run|resolve|update|regenerate|clean|dump-package|lint",
                arity: .atMost(1),
                help: .init(
                    abstract:
                        "Required after context, navigation, or package; optional after inventory "
                        + "or lint."
                )
            )
            Command.Flag(
                \.dry,
                name: .long(.literal("dry-run")),
                help: .init(
                    abstract:
                        "Plan synchronization or inventory regeneration without changing files "
                        + "or Git metadata."
                )
            )
            Command.Flag(
                \.fresh,
                name: .long(.literal("fresh")),
                help: .init(
                    abstract:
                        "Use isolated build state — a scratch directory for a package build or "
                        + "test, a derived-data directory for the workspace build."
                )
            )
            Command.Flag(
                \.changed,
                name: .long(.literal("changed")),
                help: .init(
                    abstract:
                        "Sweep only packages with local work — an unclean worktree, or commits not "
                        + "yet in the tracked upstream (lint sweep only)."
                )
            )
            Command.Flag(
                \.institute,
                name: .long(.literal("institute")),
                help: .init(
                    abstract:
                        "Run the institute-internal doctor checks too, which discover the live "
                        + "GitHub organizations (needs an authenticated gh; ~460 requests)."
                )
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
            Command.Option(
                \.workspacePath,
                name: .long(.literal("workspace-path")),
                placeholder: "path",
                help: .init(
                    abstract: "Workspace checkout a navigation or lint invocation resolves against."
                )
            )
            Command.Option<Self, Swift.String>.Many(
                \.arguments,
                name: .long(.literal("argument")),
                placeholder: "swiftpm-argument",
                help: .init(
                    abstract:
                        "Argument forwarded to the underlying tool (repeatable) — SwiftPM for a "
                        + "package operation, xcodebuild for the workspace build."
                )
            )
        }
    }

    public mutating func validate() throws(Command.Error) {
        guard operation == .lint || !changed else {
            throw .validationFailed(reason: "--changed is valid only with the lint sweep.")
        }
        // Rejected rather than ignored: a flag that asks for a measurement
        // and is silently dropped produces a report that looks like the one
        // that measured, which is the defect `--institute` exists to fix.
        guard operation == .doctor || !institute else {
            throw .validationFailed(reason: "--institute is valid only with doctor.")
        }
        if operation == .install {
            guard modes.isEmpty else {
                throw .validationFailed(reason: "install takes no mode.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with install."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(reason: "--package-path is valid only with package.")
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--workspace-path is valid only with navigation or lint."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .context {
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
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(reason: "--package-path is valid only with package.")
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is valid only with navigation.")
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .navigation {
            guard
                modes.count == 1,
                modes.first == .install || modes.first == .check || modes.first == .serve
            else {
                throw .validationFailed(reason: "navigation requires install, check, or serve.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with navigation."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
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
        } else if operation == .lint {
            guard modes.isEmpty || modes.first == .install || modes.first == .check else {
                throw .validationFailed(
                    reason: "lint takes install, check, or no mode (the ecosystem sweep)."
                )
            }
            guard modes.isEmpty || !changed else {
                throw .validationFailed(reason: "--changed is valid only with the lint sweep.")
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with lint."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(
                    reason: "--package-path is valid only with package; lint sweeps the inventory."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .package {
            guard modes.count == 1, let mode = modes.first else {
                throw .validationFailed(
                    reason:
                        "package requires build, test, run, resolve, update, clean, dump-package, or lint."
                )
            }
            let action = mode.buildAction
            guard action != nil || mode == .lint else {
                throw .validationFailed(
                    reason:
                        "package requires build, test, run, resolve, update, clean, dump-package, or lint."
                )
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with package."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh || action == .build || action == .test else {
                throw .validationFailed(reason: "--fresh is valid only with package build or test.")
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is valid only with navigation.")
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
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard !fresh, packagePath.isEmpty, workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--fresh, --package-path, and --workspace-path are not valid here."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .inventory {
            guard modes.isEmpty || (modes.count == 1 && modes.first == .regenerate) else {
                throw .validationFailed(
                    reason: "inventory takes regenerate or no mode (the read-only register)."
                )
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with inventory."
                )
            }
            guard !dry || modes.first == .regenerate else {
                throw .validationFailed(
                    reason:
                        "--dry-run is valid only with inventory regenerate; inventory is already "
                        + "read-only."
                )
            }
            guard !fresh, packagePath.isEmpty, workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--fresh, --package-path, and --workspace-path are not valid here."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        } else if operation == .build {
            guard modes.isEmpty else {
                throw .validationFailed(
                    reason: "build takes no mode; it builds the whole selection."
                )
            }
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are not valid with build."
                )
            }
            guard !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard packagePath.isEmpty else {
                throw .validationFailed(
                    reason: "--package-path is valid only with package; build builds the selection."
                )
            }
            guard workspacePath.isEmpty else {
                throw .validationFailed(reason: "--workspace-path is valid only with navigation or lint.")
            }
        } else {
            guard consumer.isEmpty, dependency.isEmpty else {
                throw .validationFailed(
                    reason: "--consumer and --dependency are valid only with compose, restore, or verify."
                )
            }
            guard operation == .sync || !dry else {
                throw .validationFailed(
                    reason: "--dry-run is valid only with sync or inventory regenerate."
                )
            }
            guard modes.isEmpty else {
                throw .validationFailed(reason: "install and check are valid only after context.")
            }
            guard !fresh, packagePath.isEmpty, workspacePath.isEmpty else {
                throw .validationFailed(
                    reason: "--fresh, --package-path, and --workspace-path are not valid here."
                )
            }
            guard arguments.isEmpty else {
                throw .validationFailed(reason: "--argument is valid only with package.")
            }
        }
    }

    public mutating func run() async throws(Workspace.Error) {
        if case .install = operation {
            let installation = try Workspace.Installation()
            try installation.install()
            print("workspace: installed and verified")
            print("workspace command: \(installation.command)")
            print("workspace executable: \(installation.executable)")
            return
        }

        guard let working = Environment.read("PWD") else {
            throw .configuration("PWD is not available")
        }

        if case .package = operation, modes.first == .lint {
            // The inner-loop path. It reads no inventory, enumerates no
            // organisation, and constructs no `Workspace.Root`: standing
            // inside a package, the package root and the installed
            // binaries are both reachable by walking up. That is what
            // keeps this mode from paying ecosystem-scale costs.
            let target = try Workspace.Lint.Target.resolve(
                packagePath.isEmpty ? working : packagePath
            )
            let lint = try Workspace.Lint.resolve(from: target.package.description)
            // The default bundle comes from where the package sits under
            // the hierarchy the installation was found in — the same
            // ascent, no extra reads. It is used only when the package
            // carries no `Lint.swift`.
            let measurement = lint.measure(
                target,
                using: try lint.installation(),
                default: Workspace.Lint.Bundle.resolve(
                    target.package,
                    under: lint.hierarchy
                )
            )
            print(measurement)
            Process.Exit.normal(measurement.verdict.fails ? (measurement.verdict.isUnmeasured ? 2 : 1) : 0)
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

        let checkoutValue =
            (operation == .navigation || operation == .lint) && !workspacePath.isEmpty
            ? workspacePath
            : working
        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: checkoutValue)
        } catch {
            throw .configuration("Workspace checkout is not a valid path: \(error)")
        }
        let root = try Workspace.Root(checkout: checkout)

        if case .lint = operation {
            let lint = Workspace.Lint(root: root)
            switch modes.first {
            case .some(.install):
                try lint.install()
                let manifest = try lint.installedManifest()
                print("lint: installed swift-linter \(manifest.digest)")
                print("lint: \(try lint.executable(for: manifest))")
            case .some(.check):
                let diagnostics = try lint.diagnostics()
                guard diagnostics.isEmpty else {
                    throw .configuration(diagnostics.joined(separator: "\n"))
                }
                print("lint: current — digest \(try lint.installedManifest().digest) matches CI")
            case nil:
                let configuration = try Workspace.Configuration.load(at: root.checkout)
                let report = try await Workspace.Lint.Sweep(
                    lint: lint,
                    root: root,
                    repositories: configuration.repositories
                ).run(scope: changed ? .changed : .all)
                print(report)
                Process.Exit.normal(report.status)
            default:
                throw .configuration("lint operation must be install, check, or absent")
            }
            return
        }

        if case .navigation = operation {
            switch modes.first {
            case .some(.install):
                let configuration = try Workspace.Configuration.load(at: root.checkout)
                let navigation = Workspace.Navigation(
                    root: root,
                    configuration: configuration
                )
                try navigation.install()
                print("navigation: installed and verified")
                print("navigation MCP descriptor: \(navigation.descriptorFile)")
            case .some(.check):
                let configuration = try Workspace.Configuration.load(at: root.checkout)
                let navigation = Workspace.Navigation(
                    root: root,
                    configuration: configuration
                )
                let diagnostics = try navigation.diagnostics()
                guard diagnostics.isEmpty else {
                    throw .configuration(diagnostics.joined(separator: "\n"))
                }
                print("navigation: current")
            case .some(.serve):
                try Workspace.Navigation.serve()
            case nil:
                throw .configuration("navigation operation was not provided")
            default:
                throw .configuration("navigation operation must be install, check, or serve")
            }
            return
        }

        if case .context = operation {
            let context = try Workspace.Context(root: root)
            switch modes.first {
            case .some(.install):
                print(try context.install().summary)
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
        case .install:
            return
        case .sync:
            let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
            try Workspace.Sync(root: root, selection: selection).run(dry: dry)
        case .build:
            let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
            print(selection.origin)
            let status = try Workspace.Xcode.Build(root: root, selection: selection)
                .run(fresh: fresh, arguments: arguments)
            Process.Exit.normal(status)
        case .doctor:
            let selection = try Workspace.Selection.effective(at: root.checkout, in: configuration)
            let report = await Workspace.Doctor(
                root: root,
                configuration: configuration,
                selection: selection,
                progress: .standardOutput
            ).run(access: institute ? .institute() : .contributor)
            print(report)
            Process.Exit.normal(report.status)
        case .inventory:
            switch modes.first {
            case nil:
                print(
                    Workspace.Inventory.Register(
                        repositories: configuration.repositories
                    )
                )
            case .some(.regenerate):
                let document = try Workspace.Configuration.Document.load(at: root.checkout)
                let http = GitHub.HTTP.Client<
                    Workspace.Inventory.Transport.Error,
                    GitHub.HTTP.Pagination.Error
                >(
                    agent: .init(rawValue: "swift-institute-workspace"),
                    version: .init(rawValue: "2022-11-28"),
                    execute: Workspace.Inventory.Transport.githubCLI()
                )
                let application = Workspace.Inventory.Application(
                    root: root.checkout,
                    policy: .institute(),
                    // `gh` supplies the credential; see Workspace.Inventory.Transport.
                    client: Workspace.Inventory.client(
                        http,
                        authentication: .token(.init(rawValue: ""))
                    )
                )
                let plan: Workspace.Inventory.Writer.Plan
                do {
                    plan = try await application.run(existing: document, dry: dry)
                } catch {
                    throw .configuration("inventory regenerate: \(error)")
                }
                switch plan {
                case .current:
                    print("inventory regenerate: Workspace.json is current")
                case .replace:
                    print(
                        dry
                            ? "inventory regenerate: would replace Workspace.json"
                            : "inventory regenerate: replaced Workspace.json"
                    )
                }
            default:
                throw .configuration("inventory operation must be regenerate or absent")
            }
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
        case .navigation:
            return
        case .package:
            return
        case .lint:
            return
        }
    }
}
