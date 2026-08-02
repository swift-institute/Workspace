extension Workspace.Lint.Ledger {
    /// A supplied terminal disposition for one advisory rule class.
    ///
    /// The Issue coordinate is the exact technical owner. The ledger does not
    /// parse that Issue's prose or copy its record grammar.
    public struct Disposition: Equatable, Sendable {
        public let rule: Swift.String
        public let state: State
        public let issue: Workspace.Context.Packet.Key

        public init(
            rule: Swift.String,
            state: State,
            issue: Workspace.Context.Packet.Key
        ) {
            self.rule = rule
            self.state = state
            self.issue = issue
        }

        /// Parses `rule=state@owner/repository#N`.
        public init?(argument: Swift.String) {
            let assignment = argument.split(
                separator: "=",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard assignment.count == 2, !assignment[0].isEmpty else { return nil }
            let value = assignment[1].split(
                separator: "@",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard
                value.count == 2,
                let state = State(rawValue: Swift.String(value[0])),
                let issue = Workspace.Context.Packet.Key(argument: Swift.String(value[1]))
            else { return nil }
            self.init(rule: Swift.String(assignment[0]), state: state, issue: issue)
        }
    }
}
