extension Workspace.Dependency {
    /// The complete result of measuring one inventory subject.
    struct Measurement: Sendable {
        let subject: Subject
        let manifests: [Manifest]
        let edges: [Pending.Edge]
        let exclusions: [Exclusion]
    }
}
