public import File_System
public import JSON

extension Workspace.Composition {
    /// The set of compositions active on this machine, persisted at the
    /// checkout root under `.workspace/compositions.json`.
    ///
    /// This is per-machine, transient state — which local redirections happen
    /// to be applied *here, now* — so it lives in a git-ignored directory and
    /// is never shared. It is not the composition itself; the composition is
    /// the rewritten manifest. This is only the ledger that lets ``restore``
    /// put a manifest back byte-for-byte and lets ``verify`` know what to look
    /// for. A missing file is an empty ledger, not an error.
    public struct State: Swift.Equatable, Swift.Sendable, JSON.Serializable {
        /// The active composition records, in insertion order.
        public let records: [Record]

        public init(records: [Record] = []) {
            self.records = records
        }
    }
}

extension Workspace.Composition.State {
    /// The schema version written to the ledger. Bumped only on a
    /// breaking shape change; a mismatch is refused during decoding.
    ///
    /// The ledger lives at `<checkout>/.workspace/compositions.json`; those
    /// two path components are fixed valid names, spelled as literals at
    /// each subscript so they construct `File.Path.Component` directly.
    internal static let version: Swift.Int = 1

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": Self.version.json,
            "compositions": value.records.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        let number = try Swift.Int(json: version)
        guard number == Self.version else {
            throw .typeMismatch(
                expected: "composition ledger version \(Self.version)",
                got: Swift.String(number)
            )
        }
        guard let compositions = object["compositions"] else {
            throw .missingKey("compositions")
        }
        return try Self(records: [Workspace.Composition.Record](json: compositions))
    }
}

extension Workspace.Composition.State {
    /// Loads the ledger at `checkout`, returning an empty ledger when the file is
    /// absent — the ordinary state of a workspace with no active composition.
    public static func load(at checkout: File.Directory) throws(Workspace.Error) -> Self {
        let file = checkout[directory: ".workspace"][file: "compositions.json"]
        guard file.stat.exists else { return .init() }

        let bytes: [Byte]
        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try file.read.full { span in
                var storage = [Byte]()
                storage.reserveCapacity(span.count)
                for index in span.indices {
                    storage.append(span[index])
                }
                return storage
            }
        } catch {
            throw .composition("cannot read the composition ledger \(file): \(error)")
        }

        do throws(JSON.Error) {
            return try .init(jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self))
        } catch {
            throw .composition("cannot decode the composition ledger \(file): \(error)")
        }
    }

    /// Writes the ledger under `checkout`, creating `.workspace/` if needed.
    public func save(at checkout: File.Directory) throws(Workspace.Error) {
        let container = checkout[directory: ".workspace"]
        do throws(File.System.Create.Directory.Error) {
            try container.create.recursive()
        } catch {
            throw .composition("cannot create \(container): \(error)")
        }

        let file = container[file: "compositions.json"]
        do throws(File.System.Write.Atomic.Error) {
            try file.write.atomic(jsonString(pretty: true, sortKeys: true) + "\n")
        } catch {
            throw .composition("cannot write the composition ledger \(file): \(error)")
        }
    }

    /// The record redirecting `consumer`'s `dependency`, if one is active.
    public func record(
        consumer: Swift.String,
        dependency: Swift.String
    ) -> Workspace.Composition.Record? {
        records.first { $0.consumer == consumer && $0.dependency == dependency }
    }

    /// This ledger with `record` added.
    public func adding(_ record: Workspace.Composition.Record) -> Self {
        .init(records: records + [record])
    }

    /// This ledger with the record redirecting `consumer`'s `dependency`
    /// removed. A no-op when no such record is present.
    public func removing(consumer: Swift.String, dependency: Swift.String) -> Self {
        .init(
            records: records.filter {
                !($0.consumer == consumer && $0.dependency == dependency)
            }
        )
    }
}
