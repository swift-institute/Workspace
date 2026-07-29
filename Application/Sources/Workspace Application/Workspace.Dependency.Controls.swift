extension Workspace.Dependency {
    /// Runtime positive and negative controls executed before the population.
    public struct Controls: Equatable, Sendable {
        public let positive: Swift.Bool
        public let negative: Swift.Bool

        public init(positive: Swift.Bool, negative: Swift.Bool) {
            self.positive = positive
            self.negative = negative
        }

        public var passed: Swift.Bool { positive && negative }
    }
}
