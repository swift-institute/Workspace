extension Workspace.Context.Packet {
    /// The packet's read-only boundary. Tests provide a fixed record, while the
    /// command uses the GitHub-backed implementation below.
    struct Client: Sendable {
        let record: @Sendable (Workspace.Context.Packet.Key, [Swift.String]) async
            -> Workspace.Context.Packet.Fetch<Workspace.Context.Packet.Record>
    }
}
