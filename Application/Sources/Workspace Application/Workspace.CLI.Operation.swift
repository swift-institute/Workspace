public import Command

extension Workspace.CLI {
    public enum Operation: Sendable, Equatable, Argument.Codable {
        case sync
        case doctor

        public init?(argument: Swift.String) {
            switch argument {
            case "sync": self = .sync
            case "doctor": self = .doctor
            default: return nil
            }
        }

        public var argumentDescription: Swift.String {
            switch self {
            case .sync: "sync"
            case .doctor: "doctor"
            }
        }
    }
}
