extension Workspace.Verification.Inventory.Digest {
    /// The fixed literals the `inventoryDigest` wire field can carry that
    /// are not themselves digests.
    public enum Token {}
}

extension Workspace.Verification.Inventory.Digest.Token {
    /// What a receipt carries when nothing was measured. Fixed here rather
    /// than spelled at each site, because the control plane's envelope
    /// compares against exactly this string.
    public static let unmeasured: Swift.String = "unmeasured"
}
