extension Workspace {
    public enum Error: Swift.Error, CustomStringConvertible {
        case changed
        case configuration(Swift.String)
        case filesystem(Swift.String)
        case process(Swift.String)
        case repository(Swift.String)

        public var description: Swift.String {
            switch self {
            case .changed: "Workspace.json changed during inventory discovery"
            case .configuration(let message): message
            case .filesystem(let message): message
            case .process(let message): message
            case .repository(let message): message
            }
        }
    }
}
