public import File_System

extension Workspace.Lint {
    /// What a single-package invocation resolved to.
    ///
    /// The inner-loop path takes no arguments: standing anywhere inside
    /// a package, `institute package lint` finds the package root by
    /// walking up. That convenience is also where the capability is
    /// most exposed, because it is the invocation people make casually
    /// from wherever they happen to be — so resolution failures are
    /// stated, never absorbed.
    public struct Target: Equatable, Sendable {
        /// The package root: the nearest enclosing directory holding a
        /// `Package.swift`.
        public let package: File.Directory

        /// The file the caller named, when they named one.
        ///
        /// Passing a file path straight to the engine is one of the
        /// three silent-zero invocations, so a file is never forwarded.
        /// The enclosing package is linted whole and the diagnostics are
        /// narrowed afterwards.
        public let file: File.Path?
    }
}

extension Workspace.Lint.Target {
    /// Resolves `path` to the package root that encloses it.
    ///
    /// Walking up rather than requiring an argument is what makes the
    /// fast path fast to *use*; it also costs nothing, because it reads
    /// no inventory, enumerates no organisation, and touches no
    /// directory outside the ancestry of `path`.
    ///
    /// - Throws: ``Workspace/Error`` when no enclosing package root
    ///   exists. Reported rather than degraded: linting "nothing in
    ///   particular" is how a run comes back clean from the wrong
    ///   directory.
    public static func resolve(
        _ path: Swift.String
    ) throws(Workspace.Error) -> Self {
        let validated: File.Path
        do throws(File.Path.Error) {
            validated = try File.Path(path)
        } catch {
            throw .configuration("invalid path \(path): \(error)")
        }

        let canonical: File.Path
        do throws(File.System.Canonical.Error) {
            canonical = try File.System.Canonical.resolve(validated)
        } catch {
            throw .configuration("cannot resolve \(path): \(error)")
        }

        let start: File.Directory
        let file: File.Path?
        if File(canonical).stat.isDirectory {
            start = File.Directory(canonical)
            file = nil
        } else if File(canonical).stat.isFile {
            guard let parent = File.Directory(canonical).parent else {
                throw .configuration("\(path) has no enclosing directory")
            }
            start = parent
            file = canonical
        } else {
            throw .configuration("\(path) is neither a file nor a directory")
        }

        var candidate: File.Directory? = start
        while let current = candidate {
            if current[file: "Package.swift"].stat.isFile {
                return .init(package: current, file: file)
            }
            candidate = current.parent
        }
        throw .configuration(
            "no Package.swift in \(start) or any parent directory; "
                + "swift-linter is configured per package root, so there is nothing here to lint"
        )
    }

    /// The consumer configuration the engine activates on.
    ///
    /// Its presence is CI's activation signal — present means run,
    /// absent means a cheap no-op — and it is also the rule
    /// configuration and an input to CI's tier classifier. Absent, the
    /// engine falls back to a zero-rules configuration and exits clean
    /// having loaded nothing.
    public var configuration: File {
        package[file: "Lint.swift"]
    }

    /// Whether this package participates in linting at all.
    public var isConfigured: Swift.Bool {
        configuration.stat.isFile
    }
}
