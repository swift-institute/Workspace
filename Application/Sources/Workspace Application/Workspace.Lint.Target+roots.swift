public import File_System
public import Package_Manager

extension Workspace.Lint.Target {
    /// The SwiftPM target roots this package declares.
    ///
    /// Compliance linting is scoped to these roots. A standalone `Scripts`,
    /// `Experiments`, or `Research` directory, and a test tree absent from the
    /// manifest, therefore cannot enter the scan merely because it sits below
    /// the package directory. An explicit target `path:` still wins, including
    /// `.`: membership is a manifest fact rather than a directory-name policy.
    ///
    /// Binary targets contribute no Swift source root. Every other SwiftPM
    /// target kind follows its declared path or SwiftPM's conventional root:
    /// `Tests/<name>` for tests, `Plugins/<name>` for plugins, and
    /// `Sources/<name>` for the remaining kinds.
    public func roots(
        using packages: Package.Manager = .init()
    ) throws(Workspace.Error) -> [File.Directory] {
        let evaluation: Package.Manifest.Evaluation
        do throws(Package.Manager.Error) {
            evaluation = try packages.evaluation(at: package.description)
        } catch {
            throw .configuration(
                "cannot evaluate the manifest at \(package) for lint target roots: \(error)"
            )
        }
        return try Self.roots(evaluation.targets, at: package)
    }

    /// Pure target-root projection used by the manifest-backed operation and
    /// its controls.
    static func roots(
        _ targets: [Package.Manifest.Target],
        at package: File.Directory
    ) throws(Workspace.Error) -> [File.Directory] {
        var roots = [File.Directory]()
        var seen = Swift.Set<File.Path>()
        for target in targets {
            guard let root = try Self.root(target, at: package) else { continue }
            if seen.insert(root.path).inserted {
                roots.append(root)
            }
        }
        return roots
    }

    /// Resolves one manifest target to its target root.
    private static func root(
        _ target: Package.Manifest.Target,
        at package: File.Directory
    ) throws(Workspace.Error) -> File.Directory? {
        if target.kind == .binary { return nil }

        if let declared = target.path {
            let path: File.Path
            do throws(File.Path.Error) {
                path = try File.Path(declared)
            } catch {
                throw .configuration(
                    "invalid path for lint target \(target.name.underlying): \(declared): \(error)"
                )
            }
            guard path.isRelative else {
                throw .configuration(
                    "lint target \(target.name.underlying) declares an absolute path: \(declared)"
                )
            }
            var root = package.path
            for component in path.components {
                switch component.string {
                case ".":
                    continue
                case "..":
                    throw .configuration(
                        "lint target \(target.name.underlying) escapes its package: \(declared)"
                    )
                default:
                    root = root / component
                }
            }
            return File.Directory(root)
        }

        let parent: File.Path
        switch target.kind {
        case .test:
            parent = "Tests"
        case .plugin:
            parent = "Plugins"
        case .regular, .executable, .system, .macro:
            parent = "Sources"
        case .binary:
            return nil
        }

        let name: File.Path.Component
        do throws(File.Path.Component.Error) {
            name = try File.Path.Component(target.name.underlying)
        } catch {
            throw .configuration(
                "invalid directory name for lint target \(target.name.underlying): \(error)"
            )
        }
        return File.Directory(package.path / parent / name)
    }
}
