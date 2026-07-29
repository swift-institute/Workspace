internal import Kernel_System
internal import Kernel_Thread

extension Workspace {
    /// Bounded concurrent evaluation of independent work.
    ///
    /// Every fan-out in this application spawns a child process per item —
    /// `git`, `swift package dump-package`, the linter runner — so the
    /// bound is not a tuning preference. Unbounded, hundreds of spawns at
    /// once thrash rather than finish sooner; serial, the wait dominates
    /// the wall clock and a command that is working is indistinguishable
    /// from one that has hung.
    ///
    /// Results are returned in input order whatever order the work
    /// completes in, so a caller's report, findings, and short-circuit
    /// choice stay deterministic. Concurrency here changes when work
    /// happens, never what is measured or what is reported.
    public struct Fanout: Sendable {
        /// How many items are in flight at once.
        public let jobs: Swift.Int

        /// The online processor count.
        ///
        /// Read from the machine rather than fixed, so a fan-out neither
        /// under-uses a large host nor oversubscribes a small one.
        public static var processors: Swift.Int {
            Swift.Int(Kernel.Thread.Count(System.Processor.count))
        }

        public init(jobs: Swift.Int? = nil) {
            self.jobs = Swift.max(1, jobs ?? Self.processors)
        }
    }
}

extension Workspace.Fanout {
    /// Runs `work` over `items` with at most ``jobs`` in flight, returning
    /// results in input order.
    ///
    /// `completed` is called once per finished item with the running count,
    /// from the consuming context rather than from the work itself, so it
    /// observes a monotonic sequence and never runs concurrently with
    /// itself. It exists for progress reporting; it must not influence the
    /// result.
    public func map<Item: Sendable, Result: Sendable>(
        _ items: [Item],
        completed: @escaping @Sendable (Swift.Int) -> Void = { _ in },
        _ work: @escaping @Sendable (Item) -> Result
    ) async -> [Result] {
        guard !items.isEmpty else { return [] }
        return await withTaskGroup(of: (offset: Swift.Int, value: Result).self) { group in
            var next = 0
            var finished = 0
            var results = [Result?](repeating: nil, count: items.count)

            while next < items.count, next < jobs {
                let offset = next
                let item = items[offset]
                group.addTask { (offset: offset, value: work(item)) }
                next += 1
            }
            while let outcome = await group.next() {
                results[outcome.offset] = outcome.value
                finished += 1
                completed(finished)
                guard next < items.count else { continue }
                let offset = next
                let item = items[offset]
                group.addTask { (offset: offset, value: work(item)) }
                next += 1
            }
            return results.compactMap { $0 }
        }
    }
}
