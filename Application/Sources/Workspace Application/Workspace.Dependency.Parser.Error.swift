extension Workspace.Dependency.Parser {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidUTF8
        case unterminatedBlockComment(line: Swift.Int)
        case unterminatedString(line: Swift.Int)
    }
}

extension Workspace.Dependency.Parser.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .invalidUTF8:
            "manifest is not UTF-8"
        case .unterminatedBlockComment(let line):
            "unterminated block comment beginning at line \(line)"
        case .unterminatedString(let line):
            "unterminated string literal beginning at line \(line)"
        }
    }
}
