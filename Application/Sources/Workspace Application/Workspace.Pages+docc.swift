internal import File_System

extension Workspace.Pages {
    /// Every `.docc` directory reachable from `root`, excluding any path
    /// with a `.git`, `.build`, or `.swiftpm` component — derivation rule 4
    /// of issue #82. The only rule in this instrument that reads a
    /// checkout; callers apply it only to a `.canonical` repository.
    ///
    /// Returned paths are repository-relative with POSIX separators, in no
    /// particular order — the caller sorts.
    static func doccPaths(at root: File.Directory) -> [Swift.String] {
        var results = [Swift.String]()
        walk(root, relative: [], into: &results)
        return results
    }

    private static let excludedComponents: Swift.Set<Swift.String> = [".git", ".build", ".swiftpm"]

    private static func walk(
        _ directory: File.Directory,
        relative: [Swift.String],
        into results: inout [Swift.String]
    ) {
        let entries: [File.Directory.Entry]
        do throws(File.Directory.Contents.Error) {
            entries = try File.Directory.Contents.list(at: directory)
        } catch {
            // Unreadable subtree: recorded as an empty contribution, never
            // a crash — the caller's `present` accounting is about pages,
            // not about filesystem permissions.
            return
        }

        for entry in entries where entry.type == .directory {
            guard let name = Swift.String(entry.name), !excludedComponents.contains(name) else {
                continue
            }
            let path = relative + [name]
            if name.hasSuffix(".docc") {
                results.append(path.joined(separator: "/"))
            }
            guard let subpath = entry.pathIfValid else { continue }
            walk(File.Directory(subpath), relative: path, into: &results)
        }
    }
}
