extension Workspace.Context.Packet {
    enum Fetch<Value: Sendable>: Sendable {
        case available(Value)
        case unavailable(Swift.String)
        case malformed(Swift.String)
        case unmeasured(Swift.String)
    }
}
