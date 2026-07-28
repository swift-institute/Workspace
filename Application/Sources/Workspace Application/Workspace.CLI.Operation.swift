public import Command

extension Workspace.CLI {
    public enum Operation: Sendable, Equatable, Argument.Codable {
        case sync
        case doctor
        case inventory
        case compose
        case restore
        case verify
        case context
        case navigation
        case package

        public init?(argument: Swift.String) {
            switch argument {
            case "sync": self = .sync
            case "doctor": self = .doctor
            case "inventory": self = .inventory
            case "compose": self = .compose
            case "restore": self = .restore
            case "verify": self = .verify
            case "context": self = .context
            case "navigation": self = .navigation
            case "package": self = .package
            default: return nil
            }
        }
    }
}

extension Workspace.CLI.Operation {
    public var argumentDescription: Swift.String {
        switch self {
        case .sync: "sync"
        case .doctor: "doctor"
        case .inventory: "inventory"
        case .compose: "compose"
        case .restore: "restore"
        case .verify: "verify"
        case .context: "context"
        case .navigation: "navigation"
        case .package: "package"
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
        case .sync, .doctor, .inventory, .context, .navigation, .package: false
        case .compose, .restore, .verify: true
        }
    }
}
