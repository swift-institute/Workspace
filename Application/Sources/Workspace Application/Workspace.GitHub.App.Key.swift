internal import RFC_4648
internal import File_System

extension Workspace.GitHub.App {
    /// A private key in the DER encoding the platform signing facility imports.
    ///
    /// The bytes are PKCS#1 `RSAPrivateKey`. GitHub hands out keys in that
    /// armour (`BEGIN RSA PRIVATE KEY`); a key that has been through a
    /// conversion tool arrives wrapped in PKCS#8 `PrivateKeyInfo`, so both are
    /// accepted and the wrapper is peeled here rather than at the call site.
    struct Key {
        let der: [Byte]
    }
}

extension Workspace.GitHub.App.Key {
    /// Extracts the DER body from PEM armour.
    ///
    /// Nothing derived from the key is ever put in a thrown message: a
    /// diagnostic quoting "the byte at offset N" of a private key is a
    /// disclosure, so failures say only that the file is not importable.
    init(pem: Swift.String) throws(Workspace.GitHub.App.Error) {
        var body = ""
        var inside = false
        var pkcs8 = false
        for line in pem.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = Swift.String(line).trimmed()
            if trimmed.hasPrefix("-----BEGIN") {
                inside = true
                pkcs8 = !trimmed.contains("RSA PRIVATE KEY")
                continue
            }
            if trimmed.hasPrefix("-----END") { break }
            if inside { body += trimmed }
        }
        guard inside, !body.isEmpty, let decoded = [Byte](base64Encoded: body) else {
            throw .malformedKey
        }
        self.der = pkcs8 ? try Self.unwrap(decoded) : decoded
    }

    /// Peels PKCS#8 `PrivateKeyInfo` down to the PKCS#1 `RSAPrivateKey` its
    /// final OCTET STRING carries.
    ///
    /// A minimal DER walk — SEQUENCE, INTEGER version, SEQUENCE algorithm,
    /// OCTET STRING key — sufficient for exactly this structure and no more.
    static func unwrap(_ der: [Byte]) throws(Workspace.GitHub.App.Error) -> [Byte] {
        var cursor = 0

        func length() throws(Workspace.GitHub.App.Error) -> Swift.Int {
            guard cursor < der.count else { throw .malformedKey }
            let first = der[cursor]
            cursor += 1
            guard first & 0x80 != 0 else { return Swift.Int(first) }
            let count = Swift.Int(first & 0x7F)
            guard count > 0, count <= 4, cursor + count <= der.count else { throw .malformedKey }
            var value = 0
            for _ in 0..<count {
                value = value << 8 | Swift.Int(der[cursor])
                cursor += 1
            }
            return value
        }

        func expect(_ tag: Byte) throws(Workspace.GitHub.App.Error) -> Swift.Int {
            guard cursor < der.count, der[cursor] == tag else { throw .malformedKey }
            cursor += 1
            return try length()
        }

        _ = try expect(0x30)  // PrivateKeyInfo
        let versionLength = try expect(0x02)  // version
        cursor += versionLength
        let algorithmLength = try expect(0x30)  // privateKeyAlgorithm
        cursor += algorithmLength
        let keyLength = try expect(0x04)  // privateKey
        guard cursor >= 0, cursor + keyLength <= der.count else { throw .malformedKey }
        return Array(der[cursor..<(cursor + keyLength)])
    }
}
