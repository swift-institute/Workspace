public import Byte_Primitives
public import FIPS_180_4
public import JSON

extension Workspace.Receipt {
    /// A content-addressed receipt: `JSON.Serializable` plus the one
    /// canonicalization-and-digest discipline every Institute receipt in
    /// this module shares.
    ///
    /// Conforming adds no requirement beyond `JSON.Serializable` itself —
    /// ``canonical`` and ``digest`` are supplied here, once, so the module
    /// contains exactly one digest site regardless of how many receipt
    /// shapes exist.
    public protocol Sealed: JSON.Serializable {}
}

extension Workspace.Receipt.Sealed {
    /// The canonical serialization the digest is computed over: sorted
    /// keys, compact (no pretty-printing whitespace to disagree about).
    public var canonical: Swift.String {
        json.serialize(sortKeys: true)
    }

    /// The SHA-256 of ``canonical``, as lowercase hexadecimal.
    ///
    /// Computed in-process over the canonical text's UTF-8 bytes through
    /// the Institute's sole SHA-2 owner — `FIPS_180_4.SHA256`
    /// (swift-standards/swift-fips-180-4, the Institute Receipt R37
    /// witness path). This replaced the historical platform `shasum`
    /// spawn-and-scratch-file workaround, which predated the ecosystem
    /// publishing a SHA-2 implementation (TX-APP1F).
    public var digest: Swift.String {
        FIPS_180_4.SHA256.digest(Array(canonical.utf8).map(Byte.init)).hex
    }
}
