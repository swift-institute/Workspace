extension Workspace.Lint.Ledger {
    /// A supplied exact-head successful CI coordinate for one repository.
    public struct Verification: Equatable, Sendable {
        public let repository: Workspace.Repository.Key
        public let revision: Swift.String
        public let url: Swift.String

        public init?(
            repository: Workspace.Repository.Key,
            revision: Swift.String,
            url: Swift.String
        ) {
            guard revision.count == 40, revision.allSatisfy(\.isHexDigit) else { return nil }
            let prefix = "https://github.com/\(repository.identity)/actions/runs/"
            guard url.hasPrefix(prefix) else { return nil }
            let run = url.dropFirst(prefix.count)
            guard !run.isEmpty, run.allSatisfy(\.isNumber) else { return nil }
            self.repository = repository
            self.revision = revision.lowercased()
            self.url = url
        }

        /// Parses `owner/repository@<40-hex-sha>=<actions-run-url>`.
        public init?(argument: Swift.String) {
            let assignment = argument.split(
                separator: "=",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard assignment.count == 2 else { return nil }
            let coordinate = assignment[0].split(
                separator: "@",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard
                coordinate.count == 2,
                let repository = Workspace.Repository.Key(identity: Swift.String(coordinate[0]))
            else { return nil }
            self.init(
                repository: repository,
                revision: Swift.String(coordinate[1]),
                url: Swift.String(assignment[1])
            )
        }
    }
}
