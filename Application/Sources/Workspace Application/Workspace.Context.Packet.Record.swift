extension Workspace.Context.Packet {
    struct Record: Equatable, Sendable {
        let key: Workspace.Context.Packet.Key
        let title: Swift.String
        let state: Swift.String
        let type: Swift.String
        let stateReason: Swift.String?
        let url: Swift.String
        let body: Swift.String
        let assignees: [Swift.String]
        let labels: [Swift.String]
        let parent: Swift.String?
        let children: [Swift.String]
        let comments: [Workspace.Context.Packet.Record.Comment]
        let divergences: [Swift.String]
        let diagnostics: [Swift.String]
    }
}

extension Workspace.Context.Packet.Record {
    struct Comment: Equatable, Sendable {
        let url: Swift.String
        let issue: Workspace.Context.Packet.Key
        let author: Swift.String
        let body: Swift.String
    }
}
