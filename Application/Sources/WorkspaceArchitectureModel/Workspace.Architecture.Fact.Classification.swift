extension Workspace.Architecture.Fact {
    /// Whether a package root exposes any public API surface.
    public enum Classification: Sendable, Equatable {
        /// The manifest declares at least one product.
        case exposesPublicAPI
        /// The manifest declares zero products: nothing is public.
        case internalOnly
    }
}
