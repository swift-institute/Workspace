extension Workspace.Lint {
    /// The finding stream Workspace asks swift-linter to emit.
    public enum Format: Swift.String, Sendable {
        /// The existing developer-facing diagnostic stream.
        case text

        /// SARIF 2.1.0, owned and classified by swift-linter.
        case sarif
    }
}

extension Workspace.Lint.Format {
    /// The output-format wire token owned by this enum.
    var token: Swift.String { rawValue }

    /// The channel the dispatched runner reads at the shared `Lint.run` terminal.
    ///
    /// swift-foundations/swift-linter#20 owns implementing this channel. Workspace
    /// sets it now so a pre-prerequisite runner fails the structured-output check
    /// instead of being mistaken for usable evidence.
    static let variable = "SWIFT_LINTER_FORMAT"
}
