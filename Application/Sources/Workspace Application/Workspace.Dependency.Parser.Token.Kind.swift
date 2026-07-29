extension Workspace.Dependency.Parser.Token {
    enum Kind: Equatable, Sendable {
        case identifier(Swift.String)
        case punctuation(UInt8)
        case string(Swift.String, interpolated: Swift.Bool)
    }
}
