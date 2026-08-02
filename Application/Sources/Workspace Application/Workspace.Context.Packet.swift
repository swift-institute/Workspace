extension Workspace.Context {
    /// A bounded, read-only view of one Issue's current operational context.
    ///
    /// The packet deliberately reports state; it does not infer programme policy
    /// or change GitHub records.
    public enum Packet: Sendable {}
}
