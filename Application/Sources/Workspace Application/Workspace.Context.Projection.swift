public import File_System

extension Workspace.Context {
    /// What one `context install` actually projected.
    ///
    /// The install used to report only that it had verified something, and
    /// verifying an empty set printed exactly what verifying a full one did
    /// — so a contributor whose hierarchy carried no skill root was told
    /// `installed and verified` and received nothing (issue #58). A count
    /// and its sources are the smallest report that cannot say that.
    public struct Projection: Equatable, Sendable {
        /// The canonical skill roots that were present and read.
        public let sources: [File.Directory]
        /// The skill names projected into the account, sorted.
        public let skills: [Swift.String]

        public init(sources: [File.Directory], skills: [Swift.String]) {
            self.sources = sources
            self.skills = skills
        }
    }
}

extension Workspace.Context.Projection {
    /// A one-line report naming the count and the roots it came from.
    public var summary: Swift.String {
        let roots = sources.map { "\($0)" }.joined(separator: ", ")
        return "context: installed and verified — \(skills.count) skill(s) "
            + "from \(sources.count) root(s): \(roots)"
    }
}
