public import File_System
private import WorkspaceArchitectureCandidates
private import WorkspaceArchitectureFacts
private import WorkspaceArchitectureGraph
private import WorkspaceArchitectureIndex
public import WorkspaceArchitectureModel
private import WorkspaceArchitectureValidation

#if canImport(Darwin)
    private import Darwin
#elseif canImport(Glibc)
    private import Glibc
#elseif canImport(Musl)
    private import Musl
#endif

extension Workspace.Architecture {
    /// The thin composition root behind `workspace architecture validate`.
    ///
    /// It composes derivation, graph construction, index generation and
    /// validation; it owns no model logic of its own.
    public enum CLI {}
}

extension Workspace.Architecture.CLI {
    /// Runs `workspace architecture validate` from `path`.
    ///
    /// Ascends from `path` to the nearest directory holding
    /// `Workspace.json`, derives the model, regenerates the index twice
    /// and requires identical digests, then validates Class I plus the
    /// derived contradiction checks. Returns the process exit status:
    /// `0` when validation passes, `1` when violations remain.
    public static func validate(
        path: Swift.String,
        report: (Swift.String) -> Swift.Void = { Swift.print($0) }
    ) throws(Error) -> Swift.Int32 {
        let root = try checkout(containing: path)
        let derived: Workspace.Architecture.Facts
        do throws(Workspace.Architecture.Facts.Error) {
            derived = try .derive(at: root)
        } catch {
            throw .derivation("\(error)")
        }
        let graph = Workspace.Architecture.Graph(
            facts: derived.facts,
            edges: derived.edges
        )

        let first = Workspace.Architecture.Index.generate(facts: derived.facts, graph: graph)
        let second = Workspace.Architecture.Index.generate(facts: derived.facts, graph: graph)
        guard first.digest == second.digest else {
            throw .unstableIndex(first: "\(first.digest)", second: "\(second.digest)")
        }

        let validator = Workspace.Architecture.Validator()
        let outcome = validator.validate(
            facts: derived.facts,
            graph: graph,
            today: today()
        )
        let candidates = Workspace.Architecture.CandidateDetector().detect(in: derived.facts)

        report("architecture: \(derived.facts.count) package roots, \(derived.edges.count) edges")
        report("architecture: index digest \(first.digest) (regenerated twice, identical)")
        if let cycle = graph.cycle() {
            report("architecture: dependency cycle \(cycle.map(\.description).joined(separator: " -> "))")
        }
        for violation in outcome.violations {
            report("architecture: violation \(violation)")
        }
        for candidate in candidates {
            report(
                "architecture: advisory candidate '\(candidate.stem)' — "
                    + candidate.owners.map(\.description).joined(separator: ", ")
            )
        }
        report(
            outcome.passes
                ? "architecture: PASS"
                : "architecture: FAIL — \(outcome.violations.count) violations"
        )
        return outcome.passes ? 0 : 1
    }

    /// Ascends from `path` to the nearest directory containing
    /// `Workspace.json`.
    internal static func checkout(containing path: Swift.String) throws(Error) -> File.Directory {
        var current = path
        while true {
            do throws(File.Path.Error) {
                let directory = try File.Directory(validating: current)
                do throws(Either<File.System.Read.Full.Error, Never>) {
                    _ = try directory[file: "Workspace.json"].read.full { (span) in span.count }
                    return directory
                } catch {
                    // No readable inventory here; keep ascending.
                }
            } catch {
                // Not a directory; keep ascending.
            }
            guard let separator = current.lastIndex(of: "/"), separator != current.startIndex
            else {
                throw .noWorkspaceCheckout(searchedFrom: path)
            }
            current = Swift.String(current[..<separator])
        }
    }

    /// Today's UTC calendar day, without Foundation.
    internal static func today() -> Workspace.Architecture.Exemption.Expiry {
        let seconds = time(nil)
        var days = Swift.Int(seconds) / 86_400
        // Civil-from-days (Howard Hinnant's algorithm), epoch 1970-01-01.
        days += 719_468
        let era = (days >= 0 ? days : days - 146_096) / 146_097
        let dayOfEra = days - era * 146_097
        let yearOfEra =
            (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let year = yearOfEra + era * 400
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        let month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        let civilYear = month <= 2 ? year + 1 : year
        let text =
            zeroPadded(civilYear, to: 4) + "-" + zeroPadded(month, to: 2) + "-"
            + zeroPadded(day, to: 2)
        // The canonical form above is valid by construction.
        return try! .init(rawValue: text)
    }

    private static func zeroPadded(_ value: Swift.Int, to width: Swift.Int) -> Swift.String {
        var text = Swift.String(value)
        while text.count < width { text = "0" + text }
        return text
    }
}
