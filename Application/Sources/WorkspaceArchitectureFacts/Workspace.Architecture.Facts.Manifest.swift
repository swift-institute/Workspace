public import WorkspaceArchitectureModel

extension Workspace.Architecture.Facts {
    /// What derivation reads out of one package manifest.
    ///
    /// The scanner extracts declaration names and dependency URLs from the
    /// manifest source; a caller holding fully evaluated manifest data
    /// (for example `swift package dump-package` output) constructs the
    /// value directly instead.
    public struct Manifest: Sendable, Equatable {
        public let targets: [Swift.String]
        public let products: [Swift.String]
        public let dependencyURLs: [Swift.String]

        public init(
            targets: [Swift.String],
            products: [Swift.String],
            dependencyURLs: [Swift.String]
        ) {
            self.targets = targets
            self.products = products
            self.dependencyURLs = dependencyURLs
        }
    }
}

extension Workspace.Architecture.Facts.Manifest {
    /// Scans `Package.swift` source for target names, product names and
    /// package-dependency URLs.
    ///
    /// The scan is line-based: a `.target(`/`.executableTarget(` opener
    /// marks the next captured `name:` as a target name; inside the
    /// `products:` array a captured `name:` is a product name; every
    /// `url:` capture is a package-dependency URL.
    public static func scan(_ source: Swift.String) -> Self {
        var targets: [Swift.String] = []
        var products: [Swift.String] = []
        var urls: [Swift.String] = []
        var inProducts = false
        var productsDepth = 0
        var awaitingTargetName = false
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            if trimmed.hasPrefix("products:") {
                inProducts = true
                productsDepth = 0
            }
            if inProducts {
                productsDepth += line.count { $0 == "[" } - line.count { $0 == "]" }
                if productsDepth <= 0, line.contains("]") { inProducts = false }
            }
            if trimmed.hasPrefix(".target(") || trimmed.hasPrefix(".executableTarget(") {
                awaitingTargetName = true
            }
            if trimmed.hasPrefix(".testTarget(") {
                awaitingTargetName = false
            }
            if let url = capture(after: "url: \"", in: line) {
                urls.append(url)
            }
            if let name = capture(after: "name: \"", in: line) {
                if inProducts {
                    if !products.contains(name) { products.append(name) }
                } else if awaitingTargetName {
                    if !targets.contains(name) { targets.append(name) }
                    awaitingTargetName = false
                }
            }
        }
        return .init(targets: targets, products: products, dependencyURLs: urls)
    }

    private static func capture(
        after prefix: Swift.String,
        in line: Swift.Substring
    ) -> Swift.String? {
        guard let range = line.firstRange(of: prefix) else { return nil }
        let rest = line[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return Swift.String(rest[..<end])
    }

    /// Reduces a Git URL to its `organization/name` coordinate.
    public static func coordinate(url: Swift.String) -> Swift.String? {
        let stripped = url.hasSuffix(".git") ? Swift.String(url.dropLast(4)) : url
        let components = stripped.split(separator: "/")
        guard let name = components.last, let organization = components.dropLast().last else {
            return nil
        }
        return "\(organization)/\(name)"
    }
}
