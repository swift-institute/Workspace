extension Workspace.Lint {
    /// A typed external prerequisite for completing a lint measurement.
    public enum Prerequisite: Swift.String, Equatable, Sendable {
        /// Structured findings must reach both configured and prebuilt dispatch.
        case sarif

        /// The installed binaries must be built from the current rule packs
        /// before a fix run may rewrite source.
        ///
        /// Typed rather than left as prose because this is the prerequisite
        /// a wave lane most needs to tell apart from a finding of zero: the
        /// run did not happen, so the package's swift-linter state is
        /// unknown rather than clean.
        case currency
    }
}

extension Workspace.Lint.Prerequisite {
    /// The stable machine token owned by this prerequisite.
    public var token: Swift.String { rawValue }

    /// The exact owning Issue coordinate.
    public var issue: Swift.String {
        switch self {
        case .sarif: "https://github.com/swift-foundations/swift-linter/issues/20"
        case .currency: "https://github.com/swift-foundations/swift-linter/issues/33"
        }
    }

    /// Human prose rendered from the typed prerequisite.
    public var reason: Swift.String {
        switch self {
        case .sarif: "structured findings are unavailable; prerequisite \(issue)"
        case .currency:
            "the installed swift-linter is not built from the current rule packs; "
                + "prerequisite \(issue)"
        }
    }
}
