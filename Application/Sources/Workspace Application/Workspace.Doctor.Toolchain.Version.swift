extension Workspace.Doctor.Toolchain {
    /// A dotted release version, ordered by numeric component.
    ///
    /// The toolchain requirement is a *floor*, not a pin, so the comparison
    /// has to understand that 6.4 is newer than 6.3.3 — which string
    /// containment cannot. Components are compared left to right, and a
    /// shorter version is padded with zeroes, so `26.6` and `26.6.0` are
    /// the same version.
    public struct Version: Comparable, Hashable, Sendable {
        public let components: [Swift.Int]

        /// The components without trailing zeroes, so that equality and
        /// ordering agree: `26.6` and `26.6.0` are the same version, and a
        /// type where `!(a < b) && !(b < a)` but `a != b` would be lying
        /// about one of the two.
        private var normalized: [Swift.Int] {
            var components = self.components
            while components.count > 1, components.last == 0 {
                components.removeLast()
            }
            return components
        }

        public static func == (lhs: Self, rhs: Self) -> Swift.Bool {
            lhs.normalized == rhs.normalized
        }

        public func hash(into hasher: inout Swift.Hasher) {
            hasher.combine(normalized)
        }

        /// Reads a dotted version, rejecting anything that is not entirely
        /// digits and separators.
        ///
        /// - Parameter text: The candidate version, such as `6.3.3`.
        public init?(_ text: Swift.Substring) {
            var components = [Swift.Int]()
            for field in text.split(separator: ".", omittingEmptySubsequences: false) {
                guard !field.isEmpty, let value = Swift.Int(field) else { return nil }
                components.append(value)
            }
            guard !components.isEmpty else { return nil }
            self.components = components
        }

        public init?(_ text: Swift.String) {
            self.init(text[...])
        }

        public static func < (lhs: Self, rhs: Self) -> Swift.Bool {
            let width = Swift.max(lhs.components.count, rhs.components.count)
            for index in 0..<width {
                let left = index < lhs.components.count ? lhs.components[index] : 0
                let right = index < rhs.components.count ? rhs.components[index] : 0
                guard left == right else { return left < right }
            }
            return false
        }
    }
}

extension Workspace.Doctor.Toolchain.Version {
    /// The version a tool reports immediately after `prefix` in its output.
    ///
    /// Tools state their version in prose — `Apple Swift version 6.3.3
    /// (swift-6.3.3-RELEASE)`, `Xcode 26.6` — so the prefix is what pins
    /// which number in that prose is the version.
    ///
    /// - Parameters:
    ///   - output: The tool's full version output.
    ///   - prefix: The text immediately preceding the version number.
    /// - Returns: The parsed version and the exact text it was read from,
    ///   or `nil` when the prefix is absent or is not followed by a version.
    public static func read(
        from output: Swift.String,
        after prefix: Swift.String
    ) -> (version: Self, text: Swift.String)? {
        var index = output.startIndex
        while index < output.endIndex {
            guard output[index...].hasPrefix(prefix) else {
                output.formIndex(after: &index)
                continue
            }
            let remainder = output[output.index(index, offsetBy: prefix.count)...]
            let field = remainder.prefix { !$0.isWhitespace }
            guard let version = Self(field) else { return nil }
            return (version, Swift.String(field))
        }
        return nil
    }
}
