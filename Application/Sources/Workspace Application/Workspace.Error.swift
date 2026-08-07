extension Workspace {
    public enum Error: Swift.Error, CustomStringConvertible {
        case changed
        case composition(Swift.String)
        case configuration(Swift.String)
        case filesystem(Swift.String)
        case process(Swift.String)
        case repository(Swift.String)
    }
}

extension Workspace.Error {
    public var description: Swift.String {
        switch self {
        case .changed: "Institute.json changed during inventory discovery"
        case .composition(let message): message
        case .configuration(let message): message
        case .filesystem(let message): message
        case .process(let message): message
        case .repository(let message): message
        }
    }
}
