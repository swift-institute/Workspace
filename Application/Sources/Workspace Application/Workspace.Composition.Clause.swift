extension Workspace.Composition {
    /// A located `.package(...)` clause within manifest source: the exact text
    /// it spans and the UTF-8 byte range it occupies.
    ///
    /// Located by paren-matching over the **raw** manifest bytes, not by
    /// re-serialising an evaluated manifest. The reversal a composition owes is
    /// *byte-identical* — the declared clause must be restored verbatim — so it
    /// has to be captured verbatim, and only the original bytes are verbatim.
    /// String-literal contents are skipped during the scan, so a parenthesis
    /// inside a quoted URL or path cannot close the clause early.
    ///
    /// The range is expressed in bytes rather than `String.Index` because every
    /// delimiter this engine keys on — `.package(`, `(`, `)`, `"`, `\` — is
    /// ASCII, so byte boundaries at those points never fall inside a multi-byte
    /// UTF-8 scalar and slicing on them is exact. Working over `String.Index`
    /// would pull in Foundation's `range(of:)`, which the layer forbids.
    internal struct Clause: Swift.Sendable, Swift.Equatable {
        /// The exact source text of the clause, from `.package(` to its
        /// matching `)`, inclusive.
        internal let text: Swift.String

        /// The half-open UTF-8 byte range the clause occupies in its source.
        internal let range: Swift.Range<Swift.Int>
    }
}

extension Workspace.Composition.Clause {
    /// Every `.package(...)` clause in `source`, in source order.
    internal static func all(in source: Swift.String) -> [Self] {
        let bytes = [Swift.UInt8](source.utf8)
        let marker = [Swift.UInt8](".package(".utf8)

        var clauses: [Self] = []
        var index = 0
        while let start = firstIndex(of: marker, in: bytes, from: index) {
            let openParen = start + marker.count
            guard let close = closingParen(in: bytes, after: openParen) else {
                // Unbalanced from here on; nothing further is a well-formed
                // clause, so stop rather than ressynchronising on a guess.
                break
            }
            let range = start..<(close + 1)
            clauses.append(
                .init(
                    text: Swift.String(decoding: bytes[range], as: Swift.UTF8.self),
                    range: range
                )
            )
            index = close + 1
        }
        return clauses
    }

    /// The url-form clause whose declared URL has package identity `identity`,
    /// or `nil` when the source declares no such dependency by URL.
    ///
    /// Matched on derived identity, not on a literal URL comparison, so a
    /// declaration that omits a trailing `.git` or differs in case still
    /// matches — identity is exactly what SwiftPM keys a dependency on.
    internal static func url(
        identity: Swift.String,
        in source: Swift.String
    ) -> Self? {
        all(in: source).first { clause in
            guard let url = clause.declaredURL else { return false }
            return Self.identity(ofURL: url) == identity
        }
    }

    /// The declared URL of a url-form clause (`.package(url: "…", …)`), or
    /// `nil` when the clause is not url-form.
    internal var declaredURL: Swift.String? {
        Self.declaredURL(in: text)
    }

    /// The declared path of a path-form clause (`.package(path: "…")`), or
    /// `nil` when the clause is not path-form.
    internal var declaredPath: Swift.String? {
        Self.declaredPath(in: text)
    }

    /// The declared URL of a standalone url-form clause text.
    ///
    /// The standalone form lets a persisted clause be re-parsed without
    /// re-locating it in a manifest — a restore knows the exact clause text it
    /// stored and needs the identity it carries, not a position.
    internal static func declaredURL(in text: Swift.String) -> Swift.String? {
        quoted(after: "url:", in: text)
    }

    /// The declared path of a standalone path-form clause text.
    internal static func declaredPath(in text: Swift.String) -> Swift.String? {
        quoted(after: "path:", in: text)
    }

    /// `source` with this clause's byte span replaced by `replacement`.
    ///
    /// The clause carries a byte range into the exact `source` it was located
    /// in; applying it to any other text is a programmer error the caller
    /// prevents by re-locating against the text it edits.
    internal func replacing(
        with replacement: Swift.String,
        in source: Swift.String
    ) -> Swift.String {
        let bytes = [Swift.UInt8](source.utf8)
        var result = [Swift.UInt8]()
        result.reserveCapacity(bytes.count)
        result.append(contentsOf: bytes[bytes.startIndex..<range.lowerBound])
        result.append(contentsOf: replacement.utf8)
        result.append(contentsOf: bytes[range.upperBound..<bytes.endIndex])
        return Swift.String(decoding: result, as: Swift.UTF8.self)
    }

    /// SwiftPM's package identity for a source-control URL: the last path
    /// component, with a trailing slash and a trailing `.git` removed, folded
    /// to lower case. This mirrors how SwiftPM derives identity from a git URL.
    internal static func identity(ofURL url: Swift.String) -> Swift.String {
        var value = url[...]
        while value.last == "/" { value = value.dropLast() }
        if value.hasSuffix(".git") { value = value.dropLast(4) }
        let component = value.split(separator: "/").last.map(Swift.String.init) ?? Swift.String(value)
        return component.lowercased()
    }
}

extension Workspace.Composition.Clause {
    /// The first quoted string literal that follows `label` in the clause text,
    /// or `nil` when the label or a following literal is absent.
    ///
    /// Escaped quotes are not interpreted: a URL or filesystem path carrying a
    /// literal `"` is pathological here, and treating the first inner quote as
    /// the terminator fails loudly rather than smuggling a wrong value through.
    private static func quoted(after label: Swift.String, in text: Swift.String) -> Swift.String? {
        let bytes = [Swift.UInt8](text.utf8)
        let needle = [Swift.UInt8](label.utf8)
        let located = Workspace.Composition.Clause.firstIndex(of: needle, in: bytes, from: 0)
        guard let labelStart = located else { return nil }

        let quote = Swift.UInt8(ascii: "\"")
        var index = labelStart + needle.count
        while index < bytes.count, bytes[index] != quote { index += 1 }
        guard index < bytes.count else { return nil }
        let open = index + 1
        var close = open
        while close < bytes.count, bytes[close] != quote { close += 1 }
        guard close < bytes.count else { return nil }
        return Swift.String(decoding: bytes[open..<close], as: Swift.UTF8.self)
    }

    /// The index of the `)` that closes the `.package(` whose `(` sits at
    /// `start - 1`. Depth-counts parentheses and skips string-literal contents
    /// so a paren inside a quoted URL or path cannot close the clause early.
    /// `nil` when the parentheses never balance.
    private static func closingParen(in bytes: [Swift.UInt8], after start: Swift.Int) -> Swift.Int? {
        let quote = Swift.UInt8(ascii: "\"")
        let backslash = Swift.UInt8(ascii: "\\")
        let open = Swift.UInt8(ascii: "(")
        let close = Swift.UInt8(ascii: ")")

        var depth = 1
        var index = start
        var insideString = false
        var escaped = false
        while index < bytes.count {
            let byte = bytes[index]
            if insideString {
                if escaped {
                    escaped = false
                } else if byte == backslash {
                    escaped = true
                } else if byte == quote {
                    insideString = false
                }
            } else {
                switch byte {
                case quote: insideString = true
                case open: depth += 1
                case close:
                    depth -= 1
                    if depth == 0 { return index }
                default: break
                }
            }
            index += 1
        }
        return nil
    }

    /// The index in `haystack` at or after `from` where `needle` first occurs,
    /// or `nil`. A plain forward scan; manifests are small and this runs a
    /// handful of times per operation.
    private static func firstIndex(
        of needle: [Swift.UInt8],
        in haystack: [Swift.UInt8],
        from: Swift.Int
    ) -> Swift.Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        var start = from
        let last = haystack.count - needle.count
        while start <= last {
            var offset = 0
            while offset < needle.count, haystack[start + offset] == needle[offset] {
                offset += 1
            }
            if offset == needle.count { return start }
            start += 1
        }
        return nil
    }
}
