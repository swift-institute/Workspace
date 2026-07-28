internal import File_System

extension Workspace.Root {
    /// The active sibling-layout location of `repository`.
    func materialization(
        for repository: Workspace.Repository
    ) throws(Workspace.Error) -> File.Directory {
        let directory = try Workspace.Layout.directory(for: repository, at: hierarchy)
        try preflight(directory, under: hierarchy)
        return directory
    }

    /// The superseded in-checkout location of `repository`.
    func legacy(
        for repository: Workspace.Repository
    ) throws(Workspace.Error) -> File.Directory {
        let directory = try Workspace.Layout.directory(for: repository, at: checkout)
        try preflight(directory, under: checkout)
        return directory
    }

    /// Proves that every currently-existing prefix of `target` is a real
    /// directory physically contained by `base`.
    ///
    /// This is a snapshot of a mutable filesystem namespace, not an object
    /// capability. A concurrent process can rename or replace a checked prefix
    /// after this method returns. Security against that race requires
    /// descriptor-relative no-follow operations from the filesystem owner.
    func preflight(
        _ target: File.Directory,
        under base: File.Directory
    ) throws(Workspace.Error) {
        try Self.preflight(target, under: base)
    }

    /// ``preflight(_:under:)`` without a resolved root.
    ///
    /// The check reads only its two arguments. Exposing it statically
    /// lets the lint capability — which is rooted at a hierarchy
    /// directory rather than at a Workspace checkout — apply the same
    /// containment discipline instead of a second, weaker copy of it.
    static func preflight(
        _ target: File.Directory,
        under base: File.Directory
    ) throws(Workspace.Error) {
        let baseComponents = Array(base.path.components)
        let targetComponents = Array(target.path.components)
        guard
            targetComponents.count >= baseComponents.count,
            targetComponents.prefix(baseComponents.count).elementsEqual(baseComponents)
        else {
            throw .filesystem("\(target) is outside the declared hierarchy \(base)")
        }

        var prefix = base
        var future = false
        for component in targetComponents.dropFirst(baseComponents.count) {
            guard component.string != ".", component.string != ".." else {
                throw .configuration("layout path contains traversal component \(component)")
            }
            prefix = prefix[directory: component]
            guard !future else { continue }

            let info: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                info = try File.System.Stat.info(at: prefix.path, followSymlinks: false)
            } catch {
                let inspection = error
                let resolution: Result<File.Path, File.System.Canonical.Error>
                do throws(File.System.Canonical.Error) {
                    resolution = .success(try File.System.Canonical.resolve(prefix.path))
                } catch {
                    resolution = .failure(error)
                }
                switch resolution {
                case .success:
                    throw .filesystem(
                        "cannot inspect existing materialization prefix \(prefix): \(inspection)"
                    )
                case .failure(let error):
                    if error.isNotFound {
                        future = true
                        continue
                    }
                    throw .filesystem(
                        "cannot resolve materialization prefix \(prefix): \(error)"
                    )
                }
            }

            guard info.type != .symbolicLink else {
                throw .filesystem("materialization prefix is a symbolic link: \(prefix)")
            }
            guard info.type == .directory else {
                throw .filesystem("materialization prefix is not a directory: \(prefix)")
            }

            let canonical: File.Path
            do throws(File.System.Canonical.Error) {
                canonical = try File.System.Canonical.resolve(prefix.path)
            } catch {
                throw .filesystem(
                    "materialization prefix changed during inspection \(prefix): \(error)"
                )
            }
            guard Self.contains(canonical, within: base.path) else {
                throw .filesystem(
                    "materialization prefix resolves outside \(base): \(prefix) -> \(canonical)"
                )
            }
        }
    }

    private static func contains(
        _ candidate: File.Path,
        within base: File.Path
    ) -> Bool {
        let baseComponents = Array(base.components)
        let candidateComponents = Array(candidate.components)
        return candidateComponents.count >= baseComponents.count
            && candidateComponents.prefix(baseComponents.count).elementsEqual(baseComponents)
    }
}
