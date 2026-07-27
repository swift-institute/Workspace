extension Build {
    /// A failure to configure or execute one coordinated build operation.
    public enum Error: Swift.Error, CustomStringConvertible, Equatable, Sendable {
        case configuration(Swift.String)
        case filesystem(Swift.String)
        case process(Swift.String)
    }
}

extension Build.Error {
    public var description: Swift.String {
        switch self {
        case .configuration(let message): message
        case .filesystem(let message): message
        case .process(let message): message
        }
    }
}
