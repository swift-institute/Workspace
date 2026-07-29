import Foundation
import Testing

@testable import Workspace_Application

extension Workspace.Fanout {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Workspace.Fanout.Test.Unit {
    /// Work whose completion order is the reverse of its input order: the
    /// first item takes the longest. Any implementation that returned
    /// results as they landed would return this reversed.
    private static func staggered(_ item: Swift.Int, of total: Swift.Int) -> Swift.Int {
        Thread.sleep(forTimeInterval: Double(total - item) * 0.005)
        return item
    }

    @Test
    func `results come back in input order however the work completes`() async {
        let items = Array(0..<24)

        let results = await Workspace.Fanout(jobs: 24).map(items) { item in
            Self.staggered(item, of: 24)
        }

        #expect(results == items)
    }

    @Test
    func `every item is measured, and none twice, when the bound is below the population`() async {
        let items = Array(0..<200)

        let results = await Workspace.Fanout(jobs: 4).map(items) { $0 * 2 }

        #expect(results == items.map { $0 * 2 })
    }

    @Test
    func `completion is reported once per item, counting up to the population`() async {
        let counts = Workspace.Fanout.Test.Unit.Counts()

        _ = await Workspace.Fanout(jobs: 6).map(
            Array(0..<50),
            completed: { counts.record($0) }
        ) { $0 }

        #expect(counts.observed == Array(1...50))
    }

    @Test
    func `an empty population runs nothing and reports nothing`() async {
        let counts = Workspace.Fanout.Test.Unit.Counts()

        let results = await Workspace.Fanout().map(
            [Swift.Int](),
            completed: { counts.record($0) }
        ) { $0 }

        #expect(results.isEmpty)
        #expect(counts.observed.isEmpty)
    }

    @Test
    func `the bound is at least one, whatever it is asked for`() {
        #expect(Workspace.Fanout(jobs: 0).jobs == 1)
        #expect(Workspace.Fanout(jobs: -8).jobs == 1)
        #expect(Workspace.Fanout().jobs >= 1)
    }

    /// The running counts a fan-out reported, in the order it reported
    /// them.
    final class Counts: Sendable {
        private nonisolated(unsafe) var storage = [Swift.Int]()
        private let lock = NSLock()

        func record(_ count: Swift.Int) {
            lock.lock()
            defer { lock.unlock() }
            storage.append(count)
        }

        var observed: [Swift.Int] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }
}
