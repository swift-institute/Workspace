public import Async_Fanout
internal import Kernel_System
internal import Kernel_Thread

extension Workspace {
    /// Bounded concurrent evaluation of independent work.
    ///
    /// The mechanism is owned by swift-async as ``Async/Fanout``; this
    /// application binds it to its own name and supplies the sole
    /// Institute-specific residue below: the online processor-count
    /// default, read through the kernel.
    public typealias Fanout = Async.Fanout
}

extension Async.Fanout {
    /// The online processor count.
    ///
    /// Read from the machine rather than fixed, so a fan-out neither
    /// under-uses a large host nor oversubscribes a small one.
    public static var processors: Swift.Int {
        Swift.Int(Kernel.Thread.Count(System.Processor.count))
    }

    /// Every fan-out in this application spawns a child process per item —
    /// `git`, `swift package dump-package`, the linter runner — so an
    /// unspecified bound defaults to the online processor count.
    public init(jobs: Swift.Int? = nil) {
        self.init(jobs: jobs ?? Self.processors)
    }
}
