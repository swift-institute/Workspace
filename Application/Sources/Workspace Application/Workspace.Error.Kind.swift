extension Workspace.Error {
    /// Which class of ``Workspace/Error`` occurred, and nothing else.
    ///
    /// Every ``Workspace/Error`` case but ``Workspace/Error/changed``
    /// carries a captured message, and those messages routinely name this
    /// machine's own filesystem (a failed `git` invocation quotes the
    /// checkout it ran in; a configuration failure quotes the file it could
    /// not read). That is exactly right for a terminal diagnostic and
    /// exactly wrong for anything crossing the receipt boundary, which
    /// ``Workspace/Verification/Redaction`` refuses to seal.
    ///
    /// This type is the leak-safe projection: it preserves *which* kind of
    /// failure happened — the half of the diagnosis a reader of a sealed
    /// receipt can act on — and discards the captured text entirely, so no
    /// path, token, or command line can travel with it.
    public enum Kind: Swift.String, Equatable, Sendable, CustomStringConvertible {
        case changed
        case composition
        case configuration
        case filesystem
        case process
        case repository

        public init(_ error: Workspace.Error) {
            switch error {
            case .changed: self = .changed
            case .composition: self = .composition
            case .configuration: self = .configuration
            case .filesystem: self = .filesystem
            case .process: self = .process
            case .repository: self = .repository
            }
        }
    }
}

extension Workspace.Error.Kind {
    public var description: Swift.String { rawValue }
}

extension Workspace.Error {
    /// This error's leak-safe classification.
    public var kind: Kind { .init(self) }
}
