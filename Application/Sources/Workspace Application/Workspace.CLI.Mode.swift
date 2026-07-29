internal import Build_Coordinator
public import Command

extension Workspace.CLI {
    /// The second positional component of a compound Workspace operation.
    public enum Mode: Sendable, Equatable, Argument.Codable {
        case install
        case check
        case serve
        case build
        case test
        case run
        case resolve
        case update
        case regenerate
        case clean
        case dumpPackage
        case lint

        public init?(argument: Swift.String) {
            switch argument {
            case "install": self = .install
            case "check": self = .check
            case "serve": self = .serve
            case "build": self = .build
            case "test": self = .test
            case "run": self = .run
            case "resolve": self = .resolve
            case "update": self = .update
            case "regenerate": self = .regenerate
            case "clean": self = .clean
            case "dump-package": self = .dumpPackage
            case "lint": self = .lint
            default: return nil
            }
        }

        public var argumentDescription: Swift.String {
            switch self {
            case .install: "install"
            case .check: "check"
            case .serve: "serve"
            case .build: "build"
            case .test: "test"
            case .run: "run"
            case .resolve: "resolve"
            case .update: "update"
            case .regenerate: "regenerate"
            case .clean: "clean"
            case .dumpPackage: "dump-package"
            case .lint: "lint"
            }
        }
    }
}

extension Workspace.CLI.Mode {
    var buildAction: Build.Action? {
        switch self {
        case .install, .check, .serve, .regenerate, .lint: nil
        case .build: .build
        case .test: .test
        case .run: .run
        case .resolve: .resolve
        case .update: .update
        case .clean: .clean
        case .dumpPackage: .dumpPackage
        }
    }
}
