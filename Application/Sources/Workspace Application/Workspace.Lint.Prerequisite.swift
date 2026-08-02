extension Workspace.Lint {
    /// A typed external prerequisite for completing a lint measurement.
    public enum Prerequisite: Swift.String, Equatable, Sendable {
        /// Structured findings must reach both configured and prebuilt dispatch.
        case sarif
    }
}

extension Workspace.Lint.Prerequisite {
    /// The stable machine token owned by this prerequisite.
    public var token: Swift.String { rawValue }

    /// The exact owning Issue coordinate.
    public var issue: Swift.String {
        switch self {
        case .sarif: "https://github.com/swift-foundations/swift-linter/issues/20"
        }
    }

    /// Human prose rendered from the typed prerequisite.
    public var reason: Swift.String {
        switch self {
        case .sarif: "structured findings are unavailable; prerequisite \(issue)"
        }
    }
}
