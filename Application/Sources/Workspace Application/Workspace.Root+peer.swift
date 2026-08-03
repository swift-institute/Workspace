internal import File_System

extension Workspace.Root {
    /// The entry root that holds this hierarchy and its peer institutes —
    /// the hierarchy's parent, when one exists.
    var entry: File.Directory? { hierarchy.parent }

    /// The materialized root of `peer` — the entry sibling carrying the
    /// peer's name, preflighted for containment.
    ///
    /// The location is a convention, not a machine path: peer roots sit
    /// beside this hierarchy root under one entry directory, each named
    /// after its institute, exactly as this hierarchy root holds the
    /// materialized organization roots beside the checkout. The directory
    /// may not exist yet — adoption is opt-in per checkout — but an
    /// existing peer root must be a real, non-symlink directory physically
    /// contained by the entry.
    func peer(_ peer: Workspace.Peer) throws(Workspace.Error) -> File.Directory {
        guard let entry else {
            throw .configuration(
                "the hierarchy \(hierarchy) has no entry parent to hold peer \(peer.name)"
            )
        }
        guard peer.name != ".", peer.name != ".." else {
            throw .configuration(
                "invalid peer name \(peer.name): traversal is forbidden"
            )
        }
        let component: File.Path.Component
        do throws(File.Path.Component.Error) {
            component = try File.Path.Component(peer.name)
        } catch {
            throw .configuration("invalid peer name \(peer.name): \(error)")
        }
        let directory = entry[directory: component]
        try preflight(directory, under: entry)
        return directory
    }
}
