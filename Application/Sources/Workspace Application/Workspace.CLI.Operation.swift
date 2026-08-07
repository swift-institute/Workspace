public import Command

extension Workspace.CLI {
    public enum Operation: Sendable, Equatable, Argument.Codable {
        case install
        case sync
        case doctor
        case inventory
        case dependencies
        case compose
        case restore
        case verify
        case context
        case navigation
        case package
        case lint
        case build
        case coherence
        case conversion
        case github
        case verification
        case architecture

        public init?(argument: Swift.String) {
            switch argument {
            case "install": self = .install
            case "sync": self = .sync
            case "doctor": self = .doctor
            case "inventory": self = .inventory
            case "dependencies": self = .dependencies
            case "compose": self = .compose
            case "restore": self = .restore
            case "verify": self = .verify
            case "context": self = .context
            case "navigation": self = .navigation
            case "package": self = .package
            case "lint": self = .lint
            case "build": self = .build
            case "coherence": self = .coherence
            case "conversion": self = .conversion
            case "github": self = .github
            case "verification": self = .verification
            case "architecture": self = .architecture
            default: return nil
            }
        }
    }
}

extension Workspace.CLI.Operation {
    public var argumentDescription: Swift.String {
        switch self {
        case .install: "install"
        case .sync: "sync"
        case .doctor: "doctor"
        case .inventory: "inventory"
        case .dependencies: "dependencies"
        case .compose: "compose"
        case .restore: "restore"
        case .verify: "verify"
        case .context: "context"
        case .navigation: "navigation"
        case .package: "package"
        case .lint: "lint"
        case .build: "build"
        case .coherence: "coherence"
        case .conversion: "conversion"
        case .github: "github"
        case .verification: "verification"
        case .architecture: "architecture"
        }
    }
}

extension Workspace.CLI.Operation {
    /// Whether the operation acts on a single composition and therefore
    /// requires both `--consumer` and `--dependency`.
    ///
    /// `sync` and `doctor` act on the whole workspace and take neither; the
    /// three composition operations name exactly one consumer and one
    /// dependency. The distinction is what ``Workspace/CLI/validate()`` gates
    /// on, so it lives here rather than being re-derived at the call site.
    internal var composesADependency: Swift.Bool {
        switch self {
        case .install, .sync, .doctor, .inventory, .dependencies, .context, .navigation, .package,
            .lint, .build, .coherence, .conversion, .github, .verification, .architecture:
            false
        case .compose, .restore, .verify: true
        }
    }
}
