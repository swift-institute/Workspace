public import File_System
public import JSON

extension Workspace.Receipt {
    /// A content-addressed receipt: `JSON.Serializable` plus the one
    /// canonicalization-and-digest discipline every Institute receipt in
    /// this module shares.
    ///
    /// Conforming adds no requirement beyond `JSON.Serializable` itself —
    /// ``canonical`` and ``digest(at:)`` are supplied here, once, so the
    /// module contains exactly one SHA-256 spawn site regardless of how many
    /// receipt shapes exist.
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
    /// Spawns the platform digest tool rather than hashing in-process, the
    /// same reasoning ``Workspace/Lint/Install/digestOf(_:)`` documents: the
    /// ecosystem publishes no SHA-2 implementation. The canonical text is
    /// written to a scratch file beside the checkout and removed
    /// immediately after — best-effort; a failure to remove it must not
    /// mask the digest itself.
    public func digest(at root: Workspace.Root) throws(Workspace.Error) -> Swift.String {
        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: root.checkout.path,
                prefix: ".workspace-receipt-",
                suffix: ".json"
            )
        } catch {
            throw .filesystem("cannot allocate a scratch path for the receipt digest: \(error)")
        }
        let file = File(path)
        do throws(File.System.Write.Atomic.Error) {
            try file.write.atomic(canonical)
        } catch {
            throw .filesystem("cannot write a scratch receipt for digesting: \(error)")
        }
        defer {
            do { try file.delete() } catch {}
        }

        let output = try Workspace.Doctor.spawn("shasum", arguments: ["-a", "256", file.description])
        guard
            let field = output.split(separator: " ", omittingEmptySubsequences: true).first,
            field.count == 64,
            field.allSatisfy(\.isHexDigit)
        else {
            throw .process("cannot read a SHA-256 digest for the receipt out of: \(output)")
        }
        return Swift.String(field).lowercased()
    }
}
