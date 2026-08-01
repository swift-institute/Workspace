public import File_System

extension Workspace.Lint.Shadow {
    /// One package's whole contribution to the gate.
    ///
    /// Whole-package, not per-file: the reference a file-local guard
    /// cannot see is by definition in a *different* file from the
    /// declaration, so nothing narrower than the package is a sound unit
    /// of decision.
    public struct Scan: Sendable, Hashable {
        /// The package root, as an absolute path.
        public let package: Swift.String

        /// Declarations of a shadowed name anywhere in `Sources` or
        /// `Tests`, in file order.
        public let declarations: [Site]

        /// Modules the package re-exports.
        public let reexports: Swift.Set<Swift.String>

        /// Modules the package provides — the immediate children of
        /// `Sources` and `Tests`, mangled as the compiler spells them.
        ///
        /// Directory names rather than manifest target names. The two
        /// agree throughout this ecosystem by convention, and reading
        /// them costs one directory listing where `dump-package` costs a
        /// SwiftPM evaluation per package. Where they disagree the module
        /// simply fails to resolve, and an unresolvable re-export is
        /// withheld rather than waved through — so the cheap reading
        /// cannot turn into a silent pass.
        public let modules: Swift.Set<Swift.String>

        public init(
            package: Swift.String,
            declarations: [Site],
            reexports: Swift.Set<Swift.String>,
            modules: Swift.Set<Swift.String>
        ) {
            self.package = package
            self.declarations = declarations
            self.reexports = reexports
            self.modules = modules
        }
    }
}

extension Workspace.Lint.Shadow {
    /// Directories a source walk never descends into.
    static let excluded: Swift.Set<Swift.String> = [
        ".git", ".build", ".swiftpm", "node_modules",
    ]

    /// The two roots the gate reads.
    ///
    /// `Tests` is included deliberately. A test target declaring its own
    /// `Error` shadows for every file in that target, and the fleet's
    /// `--fix` rewrites test sources exactly as it rewrites library ones.
    static let roots = ["Sources", "Tests"]

    /// Scans one package root.
    ///
    /// Reads every Swift file under `Sources` and `Tests` once and
    /// accumulates both tiers' inputs in the same pass. An unreadable
    /// file contributes nothing, which is the one place this gate is
    /// deliberately *not* conservative: a file the process cannot read is
    /// also a file the linter cannot rewrite.
    public static func scan(_ package: File.Directory) -> Scan {
        var declarations = [Site]()
        var reexports = Swift.Set<Swift.String>()
        var modules = Swift.Set<Swift.String>()

        for name in Self.roots {
            guard let component = try? File.Path.Component(name) else { continue }
            let root = package[directory: component]
            guard File(root.path).stat.isDirectory else { continue }
            // Both roots contribute modules. A test-support target is a
            // module like any other and is re-exported like any other —
            // measured against the live hierarchy, `Tests` alone owned 26
            // of the 29 modules that otherwise failed to resolve.
            for entry in Self.entries(of: root) where entry.type == .directory {
                guard let module = Swift.String(entry.name) else { continue }
                modules.insert(Self.mangled(module))
            }
            Self.walk(
                root,
                relative: [name],
                declarations: &declarations,
                reexports: &reexports
            )
        }

        return .init(
            package: package.description,
            declarations: declarations,
            reexports: reexports,
            modules: modules
        )
    }

    /// A target directory name as the compiler spells the module.
    ///
    /// This ecosystem names target directories in prose — `ASCII
    /// Primitives`, `Institute Linter Rule Naming` — and SwiftPM turns
    /// each into a C99 extended identifier by replacing every character
    /// that cannot appear in one. The `import` in an umbrella file
    /// therefore never matches the directory name literally.
    ///
    /// Getting this wrong is not a small inaccuracy. Measured against the
    /// live hierarchy before it was applied, comparing raw directory
    /// names left 201 of 452 packages re-exporting a module that
    /// "resolved to no package" — every one of them an ordinary Institute
    /// module, withheld for a reason that was an artefact of the spelling
    /// rather than a fact about shadowing.
    static func mangled(_ name: Swift.String) -> Swift.String {
        Swift.String(
            name.map { character in
                character.isLetter || character.isNumber || character == "_"
                    ? character
                    : "_"
            }
        )
    }

    static func entries(of directory: File.Directory) -> [File.Directory.Entry] {
        do throws(File.Directory.Contents.Error) {
            return try File.Directory.Contents.list(at: directory)
        } catch {
            return []
        }
    }

    static func walk(
        _ directory: File.Directory,
        relative: [Swift.String],
        declarations: inout [Site],
        reexports: inout Swift.Set<Swift.String>
    ) {
        for entry in Self.entries(of: directory) {
            guard let name = Swift.String(entry.name), !Self.excluded.contains(name) else {
                continue
            }
            guard let path = entry.pathIfValid else { continue }
            switch entry.type {
            case .directory:
                Self.walk(
                    File.Directory(path),
                    relative: relative + [name],
                    declarations: &declarations,
                    reexports: &reexports
                )
            default:
                guard name.hasSuffix(".swift") else { continue }
                guard let source = try? Workspace.Lint.read(File(path)) else { continue }
                let reading = Self.read(
                    source,
                    at: (relative + [name]).joined(separator: "/")
                )
                declarations.append(contentsOf: reading.declarations)
                for module in reading.reexports { reexports.insert(module) }
            }
        }
    }
}

extension Workspace.Lint.Shadow {
    /// A package where PLAT-ARCH-022 is excluded from fix application, and why.
    public struct Exclusion: Sendable, Hashable {
        /// The package root, as an absolute path.
        public let package: Swift.String

        /// Why that rule is excluded, naming the shadowed name and the site.
        public let reason: Swift.String

        public init(package: Swift.String, reason: Swift.String) {
            self.package = package
            self.reason = reason
        }
    }
}

extension Workspace.Lint.Shadow.Exclusion: CustomStringConvertible {
    public var description: Swift.String {
        "EXCLUDED  \(package)\n          \(reason)"
    }
}

extension Workspace.Lint.Shadow {
    /// Tier (a): the package's own declarations.
    ///
    /// The unsafe rule is excluded on the first declaration found, and the
    /// site is named. There is no per-file narrowing here on purpose
    /// — narrowing to the declaring file is precisely the guard that was
    /// measured insufficient.
    public static func exclusion(for scan: Scan) -> Exclusion? {
        guard let site = scan.declarations.first else { return nil }
        let names = Swift.Set(scan.declarations.map(\.name.rawValue)).sorted()
        return .init(
            package: scan.package,
            reason:
                "declares \(names.map { "`\($0)`" }.joined(separator: ", ")) in "
                + "\(scan.declarations.count) place"
                + "\(scan.declarations.count == 1 ? "" : "s"), first at \(site)"
        )
    }
}

extension Workspace.Lint.Shadow {
    /// Both tiers, over a whole population.
    ///
    /// Tier (b) — a package that declares nothing itself but re-exports a
    /// module that carries a shadow — cannot be decided one package at a
    /// time, so it is decided here, over the set the sweep enumerated.
    ///
    /// The resolution is a fixpoint over the re-export graph rather than
    /// a single hop, because `@_exported` composes: an umbrella that
    /// re-exports an umbrella that re-exports a shadow-declaring module
    /// inherits the shadow just as directly. Iterating to stability is
    /// what makes "dependency closure" mean the closure rather than the
    /// first edge of it.
    ///
    /// A re-exported module that resolves to no package in the population
    /// is **withheld**, not waived. That is the asymmetry the whole gate
    /// is built on, and it is load-bearing here: the sizing pass found
    /// two of the shadow-declaring re-export sources (`Dependencies`,
    /// `Testing`) outside the Institute inventory entirely, so treating
    /// "not in the population" as "not a shadow" would wave through
    /// exactly the case that motivated tier (b).
    ///
    /// - Returns: One exclusion per gated package, in the input order,
    ///   so a fleet log reads in the order the sweep enumerated.
    public static func exclusions(across scans: [Scan]) -> [Exclusion] {
        var owner = [Swift.String: Swift.Int]()
        for (index, scan) in scans.enumerated() {
            for module in scan.modules { owner[module] = index }
        }

        // Seed: tier (a). Then close over re-exports until stable.
        var direct = [Exclusion?](repeating: nil, count: scans.count)
        var shadowed = [Swift.Bool](repeating: false, count: scans.count)
        for (index, scan) in scans.enumerated() {
            direct[index] = Self.exclusion(for: scan)
            shadowed[index] = direct[index] != nil
        }

        var inherited = [Swift.String?](repeating: nil, count: scans.count)
        var changed = true
        while changed {
            changed = false
            for (index, scan) in scans.enumerated() where !shadowed[index] {
                for module in scan.reexports.sorted() {
                    guard let source = owner[module] else {
                        shadowed[index] = true
                        inherited[index] =
                            "re-exports `\(module)`, which resolves to no package in the "
                            + "enumerated population, so whether it shadows `Error`, "
                            + "`Sequence`, or `Collection` is not established here"
                        changed = true
                        break
                    }
                    guard shadowed[source] else { continue }
                    shadowed[index] = true
                    inherited[index] =
                        "re-exports `\(module)`, provided by \(scans[source].package), "
                        + "which carries a shadow"
                    changed = true
                    break
                }
            }
        }

        var excluded = [Exclusion]()
        for (index, scan) in scans.enumerated() {
            if let direct = direct[index] {
                excluded.append(direct)
            } else if let reason = inherited[index] {
                excluded.append(.init(package: scan.package, reason: reason))
            }
        }
        return excluded
    }
}
