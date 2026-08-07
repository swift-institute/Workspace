public import WorkspaceArchitectureModel

extension Workspace.Architecture.Index {
    /// A 64-bit FNV-1a digest of the canonical rendering.
    ///
    /// The digest exists to prove reproducibility — regenerate twice,
    /// compare digests — not to resist an adversary.
    public struct Digest: Sendable, Equatable, Hashable {
        public let value: Swift.UInt64

        public init(text: Swift.String) {
            var hash: Swift.UInt64 = 0xcbf2_9ce4_8422_2325
            for byte in text.utf8 {
                hash ^= Swift.UInt64(byte)
                hash &*= 0x0000_0100_0000_01b3
            }
            self.value = hash
        }
    }
}

extension Workspace.Architecture.Index.Digest: CustomStringConvertible {
    public var description: Swift.String {
        Swift.String(value, radix: 16, uppercase: false)
    }
}
