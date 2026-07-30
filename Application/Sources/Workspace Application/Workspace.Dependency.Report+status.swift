extension Workspace.Dependency.Report {
    /// 2 when any input is unmeasured, 1 for measured unsanctioned external
    /// ownership, and 0 for complete Institute/sanctioned evidence.
    public var status: Swift.Int32 {
        guard controls.passed else { return 2 }
        let incompleteStates: Set<Workspace.Dependency.State> = [
            .excluded, .unavailable, .rateLimited, .malformed, .unmeasured,
        ]
        if subjects.contains(where: { incompleteStates.contains($0.state) })
            || manifests.contains(where: { incompleteStates.contains($0.state) })
            || edges.contains(where: { incompleteStates.contains($0.state) })
            || identities.contains(where: { incompleteStates.contains($0.state) })
            || !exclusions.isEmpty
        {
            return 2
        }
        if identities.contains(where: {
            $0.ownership == .personalOwner || $0.ownership == .thirdParty
        }) {
            return 1
        }
        return 0
    }
}
