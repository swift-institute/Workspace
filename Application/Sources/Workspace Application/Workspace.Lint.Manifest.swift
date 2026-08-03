extension Workspace.Lint {
    /// The build manifest published beside the linter binaries.
    ///
    /// The release is rebuilt from `main` of the engine and five rule
    /// packs, so a tag says nothing about what a binary contains. Each
    /// build records the exact revision of every input and a composite
    /// `digest` over them. That digest is what makes parity checkable:
    /// two builds carrying the same digest were built from the same
    /// revisions, whatever platform they target and whenever they were
    /// produced.
    ///
    /// Parsed rather than trusted whole — a manifest that arrives
    /// without a digest line is rejected, because a missing digest would
    /// otherwise compare equal to another missing digest and report
    /// parity between two unknown builds.
    public struct Manifest: Equatable, Sendable {
        /// The composite digest over every revision below.
        public let digest: Swift.String

        /// Every `key=value` line in file order, digest included.
        ///
        /// Kept verbatim so a divergence report can name *which* input
        /// moved, rather than only that something did.
        public let entries: [(key: Swift.String, value: Swift.String)]

        public static func == (lhs: Self, rhs: Self) -> Swift.Bool {
            lhs.digest == rhs.digest
                && lhs.entries.count == rhs.entries.count
                && zip(lhs.entries, rhs.entries).allSatisfy { $0 == $1 }
        }
    }
}

extension Workspace.Lint.Manifest {
    /// Parses a published build manifest.
    ///
    /// - Throws: ``Workspace/Error`` when no `digest=` line is present,
    ///   or when its value is not the hexadecimal shape a digest has.
    ///   Both are refusals to proceed on an unidentifiable build.
    public static func parse(
        _ text: Swift.String,
        label: Swift.String
    ) throws(Workspace.Error) -> Self {
        var entries = [(key: Swift.String, value: Swift.String)]()
        var digest: Swift.String?
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = Workspace.Lint.trimmed(line)
            guard !trimmed.isEmpty, let separator = trimmed.firstIndex(of: "=") else {
                continue
            }
            let key = Workspace.Lint.trimmed(trimmed[trimmed.startIndex..<separator])
            let value = Workspace.Lint.trimmed(trimmed[trimmed.index(after: separator)...])
            guard !key.isEmpty else { continue }
            entries.append((key: key, value: value))
            if key == "digest" {
                digest = value
            }
        }
        guard let digest, !digest.isEmpty else {
            throw .configuration(
                "\(label) carries no digest= line; refusing to identify the build by anything else"
            )
        }
        guard digest.allSatisfy({ $0.isHexDigit }) else {
            throw .configuration("\(label) digest is not hexadecimal: \(digest)")
        }
        return .init(digest: digest, entries: entries)
    }

    /// The value recorded for `key`, when the manifest carries one.
    public func value(for key: Swift.String) -> Swift.String? {
        entries.first { $0.key == key }?.value
    }

    /// The revision entries, excluding the digest and the build
    /// metadata that legitimately differs between platforms.
    ///
    /// Build time, toolchain, and platform are expected to differ
    /// between the macOS and Linux builds of the same digest; naming
    /// them as divergence would report a defect on every install.
    public var revisions: [(key: Swift.String, value: Swift.String)] {
        entries.filter { entry in
            !Self.incidental.contains(entry.key)
        }
    }

    /// The key recording when the build was produced.
    ///
    /// Incidental to a parity comparison — two platforms build the same
    /// revisions at different times — but the most legible thing to
    /// print when a report has to say *which* build it is about.
    static let builtAt = "built-at"

    static let incidental: Swift.Set<Swift.String> = [
        "digest",
        Self.builtAt,
        "platform",
        "swift-image",
        "xcode",
    ]
}

extension Workspace.Lint {
    /// Removes leading and trailing whitespace.
    ///
    /// A local helper rather than an extension on `Swift.String`: the
    /// two parsers in this capability are its only callers, and a
    /// module-wide method on a standard-library type would outlive that
    /// scope.
    static func trimmed(_ text: Swift.Substring) -> Swift.String {
        var slice = text
        while let first = slice.first, first.isWhitespace {
            slice = slice.dropFirst()
        }
        while let last = slice.last, last.isWhitespace {
            slice = slice.dropLast()
        }
        return Swift.String(slice)
    }
}
