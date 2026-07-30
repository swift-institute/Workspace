public import Command

extension Workspace.Coherence {
    /// Which build path measures one coherence run.
    ///
    /// `xcodebuildMerged` is Phase 1's calibration scaffolding: the
    /// existing merged `xcodebuild` graph (``Xcode/Build``), forced to
    /// macOS. Per the standing cross-platform mandate (macOS-only
    /// tooling is a blocker), ``swiftPMComposedRoot`` is the
    /// mandate-required end state — a synthetic root package
    /// (``Workspace/Composed``) whose `.package(path:)` dependencies span
    /// the selection, built with `swift build` through
    /// ``Build/Coordinator``: no Xcode, no workspace bundle, runnable on
    /// Ubuntu. Selectable so Phase 1 stays available for calibration
    /// alongside it (swift-institute/Workspace#80, #81).
    ///
    /// The raw value is exactly the string the receipt's
    /// `instrument.buildPath` field records, so a receipt and the
    /// build path that produced it never need a second mapping.
    public enum BuildPath: Swift.String, Swift.CaseIterable, Equatable, Sendable, Argument.Codable {
        case xcodebuildMerged = "xcodebuild-merged"
        case swiftPMComposedRoot = "swiftpm-composed-root"

        public init?(argument: Swift.String) {
            self.init(rawValue: argument)
        }

        public var argumentDescription: Swift.String { rawValue }
    }
}
