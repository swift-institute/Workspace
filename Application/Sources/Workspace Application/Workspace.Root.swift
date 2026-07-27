public import File_System

extension Workspace {
    /// The two filesystem roots that define one Workspace checkout.
    ///
    /// ``checkout`` owns configuration and generated checkout-local state.
    /// ``hierarchy`` is exactly the physical checkout's parent and owns the
    /// materialized organization roots.
    public struct Root: Sendable {
        public let checkout: File.Directory
        public let hierarchy: File.Directory

        /// Resolves `checkout` physically and derives its hierarchy parent.
        ///
        /// No initializer accepts the two roots independently: their
        /// parent-child relationship is the invariant this value carries.
        public init(checkout: File.Directory) throws(Workspace.Error) {
            let path: File.Path
            do throws(File.System.Canonical.Error) {
                path = try File.System.Canonical.resolve(checkout.path)
            } catch {
                throw .configuration("cannot resolve the workspace checkout \(checkout): \(error)")
            }

            let info: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                info = try File.System.Stat.info(at: path, followSymlinks: false)
            } catch {
                throw .configuration("cannot inspect the workspace checkout \(path): \(error)")
            }
            guard info.type == .directory else {
                throw .configuration("workspace checkout is not a directory: \(path)")
            }

            let physical = File.Directory(path)
            guard let hierarchy = physical.parent else {
                throw .configuration("workspace checkout has no hierarchy parent: \(physical)")
            }

            self.checkout = physical
            self.hierarchy = hierarchy
        }
    }
}
