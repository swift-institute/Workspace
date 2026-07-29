extension Workspace.Doctor {
    /// Where a run says what it is doing, while it is doing it.
    ///
    /// `doctor` at full roster is minutes of work whose only output was the
    /// report, printed after the last check had completed. On the path
    /// contributors are told to walk before every pull request, silence for
    /// minutes reads as a hang — and the honest consequence of a command
    /// that looks hung is that people stop running it, which costs the
    /// signal the checks exist to provide (issue #49).
    ///
    /// Progress is a report of the run, never a measurement of the
    /// checkout. It states only what has already been decided elsewhere,
    /// it cannot fail, and nothing it emits participates in a check's
    /// outcome or in the run's exit status. The ``Workspace/Doctor/Report``
    /// remains the sole authority on what was found.
    public struct Progress: Sendable {
        public let write: @Sendable (Swift.String) -> Void

        public init(_ write: @escaping @Sendable (Swift.String) -> Void) {
            self.write = write
        }
    }
}

extension Workspace.Doctor.Progress {
    /// Discards every line.
    ///
    /// The default, so that constructing a ``Workspace/Doctor`` never
    /// writes to a stream its caller did not ask for. The one production
    /// caller — the `doctor` command — passes ``standardOutput``.
    public static let silent = Self { _ in }

    /// Writes each line to standard output, prefixed `doctor: `.
    ///
    /// The prefix is load-bearing rather than decorative. The report's own
    /// lines begin a check's name at column zero and its findings are the
    /// indented lines beneath, and `roster-currency.yml` reads the report
    /// exactly that way — `grep -m1 '^inventory-currency: '` for the
    /// verdict, then `awk` for the indented block under it. A progress line
    /// that began a check name at column zero would be read as that check's
    /// result. Multi-line messages are prefixed line by line for the same
    /// reason: ``Workspace/Selection/Origin`` renders a second, indented
    /// line when a local override withholds packages.
    public static let standardOutput = Self { message in
        for line in message.split(separator: "\n", omittingEmptySubsequences: false) {
            print("doctor: \(line)")
        }
    }
}

extension Workspace.Doctor.Progress {
    /// How many times a fan-out reports its own progress, at most.
    ///
    /// Enough that a contributor can see movement within seconds of a
    /// check starting; few enough that the run does not bury its own
    /// report under per-item chatter.
    static let updates = 20

    /// A completion sink for a fan-out of `total` items, reporting
    /// `label completed/total` at most ``updates`` times plus the last
    /// item.
    ///
    /// The final item always reports, so a check's fan-out always ends on
    /// a line stating the population it actually covered — a fan-out that
    /// went quiet short of its total is visible rather than inferred.
    func steps(_ label: Swift.String, of total: Swift.Int) -> @Sendable (Swift.Int) -> Void {
        let write = self.write
        let interval = Swift.max(1, (total + Self.updates - 1) / Self.updates)
        return { completed in
            guard completed == total || completed.isMultiple(of: interval) else { return }
            write("\(label) \(completed)/\(total)")
        }
    }
}
