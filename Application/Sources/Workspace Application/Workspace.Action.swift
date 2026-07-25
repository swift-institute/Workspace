public import Git_Foundation

extension Workspace {
    public enum Action: Equatable, Sendable {
        case clone
        case current
        case update(Git.Object.ID)
        case skip(Swift.String)
        case fail(Swift.String)
    }
}

extension Workspace.Action {
    public var text: Swift.String {
        switch self {
        case .clone: "clone"
        case .current: "current"
        case .update: "fast-forward"
        case .skip(let reason): "skip — \(reason)"
        case .fail(let reason): "conflict — \(reason)"
        }
    }

    public var fatal: Bool {
        if case .fail = self { true } else { false }
    }
}
