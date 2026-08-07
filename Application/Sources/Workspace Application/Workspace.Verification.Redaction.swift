extension Workspace.Verification {
    /// Recognizes secret-shaped tokens and absolute machine paths in
    /// captured free text before it can reach a sealed receipt.
    ///
    /// Producer requirement 5 (Task 2-01): "emit no token, credential,
    /// machine path, or unapproved private content." This is the one
    /// mechanical check standing behind that requirement — every free-text
    /// field a verification run captures (a first compile diagnostic, a
    /// lint finding line) is scanned here before ``Run/run()`` will seal
    /// it into a receipt; a match refuses the seal outright rather than
    /// silently truncating or redacting the text, because a truncated
    /// secret is still a leaked secret and a silently redacted diagnostic
    /// is a receipt claiming to have recorded evidence it did not.
    public enum Redaction {}
}

extension Workspace.Verification.Redaction {
    /// Prefixes GitHub, AWS, and PEM-encoded material actually begin
    /// with — not a general secret scanner, which cannot exist, but a
    /// closed, checkable list of shapes this instrument refuses to carry.
    static let tokenPrefixes: [Swift.String] = [
        "ghp_", "gho_", "ghs_", "ghu_", "ghr_", "github_pat_",
        "AKIA", "ASIA",
        "-----BEGIN",
        "xoxb-", "xoxp-", "xoxa-",
    ]

    /// Substrings that name this machine's own filesystem rather than a
    /// package-relative path — the "machine path" half of requirement 5.
    static let machinePathRoots: [Swift.String] = [
        "/Users/", "/home/", "/private/tmp/", "/private/var/", "/private/etc/",
    ]

    static func containsSecretShape(_ text: Swift.String) -> Swift.Bool {
        for prefix in tokenPrefixes where text.contains(prefix) { return true }
        if text.contains("Bearer ") || text.contains("Authorization:") { return true }
        return false
    }

    static func containsMachinePath(_ text: Swift.String) -> Swift.Bool {
        for root in machinePathRoots where text.contains(root) { return true }
        return false
    }

    /// Rewrites every occurrence of `root` in `text` as a package-relative
    /// path, so captured tool output can name the file it is about without
    /// naming this machine.
    ///
    /// This is deliberately *not* a redaction: nothing is hidden. A lint
    /// finding reads `Sources/Foo/Bar.swift:12:3: …` instead of
    /// `/home/runner/work/Foo/Sources/Foo/Bar.swift:12:3: …` — the same
    /// finding, in the coordinates a receipt's reader actually has. Any
    /// absolute path that is *not* under `root` survives untouched and is
    /// still refused by ``diagnose(_:)``; this narrows what has to be
    /// refused, it does not weaken the refusal.
    public static func relative(_ text: Swift.String, to root: Swift.String) -> Swift.String {
        var prefix = root
        while prefix.count > 1, prefix.hasSuffix("/") { prefix.removeLast() }
        guard !prefix.isEmpty, prefix != "/" else { return text }
        return text.replacing(prefix + "/", with: "").replacing(prefix, with: ".")
    }

    /// `nil` when `text` is safe to seal; otherwise the reason it is not,
    /// suitable for a refusal error's message.
    public static func diagnose(_ text: Swift.String) -> Swift.String? {
        if containsSecretShape(text) {
            return "carries a secret-shaped token"
        }
        if containsMachinePath(text) {
            return "carries an absolute machine path"
        }
        return nil
    }
}
