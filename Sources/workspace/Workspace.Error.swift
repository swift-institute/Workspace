extension Workspace {
    public enum Error: Swift.Error, CustomStringConvertible {
        case arguments(String)
        case configuration(String)
        case filesystem(String)
        case process(String)
        case repository(String)

        public var description: String {
            switch self {
            case .arguments(let message): message
            case .configuration(let message): message
            case .filesystem(let message): message
            case .process(let message): message
            case .repository(let message): message
            }
        }
    }
}
