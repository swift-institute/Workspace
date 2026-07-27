public import Command
internal import Build_Coordinator

extension Workspace.CLI {
    /// The second positional component of a compound Workspace operation.
    public enum Mode: Sendable, Equatable, Argument.Codable {
        case install
        case check
        case build
        case test
        case run
        case resolve
        case update
        case clean
        case dumpPackage

        public init?(argument: Swift.String) {
            switch argument {
            case "install": self = .install
            case "check": self = .check
            case "build": self = .build
            case "test": self = .test
            case "run": self = .run
            case "resolve": self = .resolve
            case "update": self = .update
            case "clean": self = .clean
            case "dump-package": self = .dumpPackage
            default: return nil
            }
        }

        public var argumentDescription: Swift.String {
            switch self {
            case .install: "install"
            case .check: "check"
            case .build: "build"
            case .test: "test"
            case .run: "run"
            case .resolve: "resolve"
            case .update: "update"
            case .clean: "clean"
            case .dumpPackage: "dump-package"
            }
        }
    }
}

extension Workspace.CLI.Mode {
    var buildAction: Build.Action? {
        switch self {
        case .install, .check: nil
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
