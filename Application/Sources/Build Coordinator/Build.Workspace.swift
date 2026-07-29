extension Build {
    /// One `xcodebuild` operation over a generated Xcode workspace bundle.
    ///
    /// Deliberately *not* a case of ``Build/Action``. An action names a
    /// SwiftPM verb, renders `["swift", …]`, and is meaningless without a
    /// `Package.swift` — its runner guards on exactly that. This names an
    /// `xcodebuild` verb, renders `["xcodebuild", …]`, and its subject is a
    /// workspace bundle, which has no package root at all. Folding the two
    /// together would make both the command and the package-root guard
    /// conditional on the case, which is how one type quietly becomes two.
    ///
    /// The two share a runner and a lock, not a shape.
    public struct Workspace: Sendable, Equatable {
        /// The workspace bundle — a path ending in `.xcworkspace`.
        public var bundle: Swift.String

        /// The shared scheme to act on.
        public var scheme: Swift.String

        /// What to do with it.
        public var operation: Operation

        /// Where Xcode writes its build state. `nil` uses Xcode's own
        /// default location, which is shared across every workspace on the
        /// machine.
        public var derivedDataPath: Swift.String?

        /// The `-destination` specifier.
        public var destination: Swift.String

        public init(
            bundle: Swift.String,
            scheme: Swift.String,
            operation: Operation = .build,
            derivedDataPath: Swift.String? = nil,
            destination: Swift.String = "platform=macOS"
        ) {
            self.bundle = bundle
            self.scheme = scheme
            self.operation = operation
            self.derivedDataPath = derivedDataPath
            self.destination = destination
        }
    }
}

extension Build.Workspace {
    public enum Operation: Swift.String, CaseIterable, Sendable {
        case build
        /// Enumerates the workspace's schemes and resolved packages without
        /// compiling. The cheapest way to see what the graph resolved to.
        case list
    }
}

extension Build.Workspace {
    /// The argument vector, including the coordinator-owned options.
    ///
    /// `jobs` is accepted and deliberately not forwarded.
    ///
    /// `Build.Coordinator.jobs` is SwiftPM's `-j`, and `xcodebuild` schedules
    /// the merged graph across the machine on its own — measured, it chose
    /// `-j8` on this 8-core host without being told. Forwarding a SwiftPM job
    /// count would substitute a second opinion for the one the tool already
    /// formed, and a caller who constructed a `Coordinator` with a small
    /// explicit `jobs:` would throttle the one thing this operation exists
    /// for. Pass `-jobs` through `arguments` to override — a caller's explicit
    /// choice about xcodebuild, rather than a value inherited from the SwiftPM
    /// path.
    ///
    /// - Note: `arguments` reaches this type intact from an API caller, but
    ///   the `workspace` CLI's `--argument` cannot carry a dash-prefixed
    ///   value: the parser reads the next token as an option and reports a
    ///   missing value. Build settings (`CONFIGURATION=Release`) pass through
    ///   fine; flags like `-jobs 2` are API-only today.
    func invocation(
        jobs: Swift.Int,
        arguments: [Swift.String]
    ) throws(Build.Error) -> [Swift.String] {
        // Trailing separators trimmed first: whether a rendered directory
        // path carries one is the filesystem layer's business, and a guard
        // that silently depends on the answer would reject a correct bundle.
        var name = Swift.Substring(bundle)
        while name.hasSuffix("/") { name = name.dropLast() }
        guard name.hasSuffix(".xcworkspace") else {
            throw .configuration("not an Xcode workspace bundle: \(bundle)")
        }
        guard !scheme.isEmpty else {
            throw .configuration("an xcodebuild operation requires a scheme")
        }
        for argument in arguments where Self.isCoordinatorOwned(argument) {
            throw .configuration(
                "xcodebuild argument \(argument) is owned by the build coordinator"
            )
        }

        var invocation = [
            "xcodebuild",
            "-workspace", bundle,
            "-scheme", scheme,
            "-destination", destination
        ]
        if let derivedDataPath {
            invocation += ["-derivedDataPath", derivedDataPath]
        }
        // Xcode's macro-trust gate cannot be answered without the GUI, so any
        // headless build whose graph reaches a macro package stops on it.
        // Measured on the five-package proof selection, same graph both ways:
        // without these flags the build exits 65 with `Macro "…" must be
        // enabled before it can be used` for swift-witnesses,
        // swift-optic-primitives and swift-dual; with them it exits 0.
        invocation += ["-skipMacroValidation", "-skipPackagePluginValidation"]
        // `swift build` compiles the native slice only. `xcodebuild` builds
        // every architecture in the destination unless told otherwise, so
        // without this the workspace path silently compiles an extra slice
        // nobody asked for — and reports failures in it that the SwiftPM
        // path can never see.
        invocation += ["ONLY_ACTIVE_ARCH=YES"]
        invocation += [operation.rawValue]
        invocation += arguments
        return invocation
    }

    /// Options this type sets itself, and which a caller therefore may not
    /// also pass — a second `-scheme` or `-derivedDataPath` would silently
    /// win or silently lose depending on `xcodebuild`'s argument order.
    private static func isCoordinatorOwned(_ argument: Swift.String) -> Swift.Bool {
        [
            "-workspace",
            "-project",
            "-scheme",
            "-derivedDataPath",
            "-destination"
        ].contains { option in
            argument == option || argument.hasPrefix("\(option)=")
        }
    }
}
