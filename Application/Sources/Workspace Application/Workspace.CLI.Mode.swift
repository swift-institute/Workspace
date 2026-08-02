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
        case ledger
        case pages
        case seal
        case token
        case packet

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
            case "ledger": self = .ledger
            case "pages": self = .pages
            case "seal": self = .seal
            case "token": self = .token
            case "packet": self = .packet
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
            case .ledger: "ledger"
            case .pages: "pages"
            case .seal: "seal"
            case .token: "token"
            case .packet: "packet"
            }
        }
    }
}

extension Workspace.CLI.Mode {
    var buildAction: Build.Action? {
        switch self {
        case .install, .check, .serve, .regenerate, .lint, .ledger, .pages, .seal, .token,
            .packet:
            nil
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
