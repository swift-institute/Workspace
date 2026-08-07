public import File_System
public import JSON

extension Workspace.Selection {
    /// The local, ignored delta over the committed selection.
    ///
    /// It is a *delta* rather than a replacement document, for two reasons.
    /// The committed `Selection.json` stays the authority: every effective
    /// selection is the committed list plus a named departure from it, which
    /// is exactly what `institute doctor` reports. And a replacement would
    /// freeze a machine at the policy of the day it was written — a package
    /// added to the committed selection later would silently never arrive,
    /// which is the coordination hazard this mechanism exists to remove,
    /// reintroduced in a quieter form.
    ///
    /// The document is strict in the same way ``Workspace/Selection`` is:
    /// exactly the keys `version`, `add` and `remove`, no others, none
    /// omitted. A typo in a key name must fail the command rather than
    /// become an override that silently does less than it says.
    public struct Override: Equatable, Sendable, JSON.Serializable {
        public let version: Swift.Int
        public let add: [Workspace.Repository.Key]
        public let remove: [Workspace.Repository.Key]

        public init(
            version: Swift.Int,
            add: [Workspace.Repository.Key],
            remove: [Workspace.Repository.Key]
        ) {
            self.version = version
            self.add = add
            self.remove = remove
        }
    }
}

extension Workspace.Selection.Override {
    /// The name the override is read from, beside the committed selection.
    ///
    /// It is listed in the repository's `.gitignore`, so writing one never
    /// appears in `git status` and can never be committed by a `git add .`.
    public static let file: File.Path.Component = "Selection.local.json"

    /// ``file`` as it is spelled in diagnostics.
    public static var filename: Swift.String { file.string }

    /// Loads the local override, or `nil` when the checkout has none.
    ///
    /// Absence and unreadability are distinguished deliberately. A file that
    /// is not there is a valid state — the committed selection is in effect.
    /// A file that is there but cannot be read or decoded fails the command.
    /// Collapsing the two, as a `try?` would, is how a malformed override
    /// becomes a silently different checkout.
    public static func load(at root: File.Directory) throws(Workspace.Error) -> Self? {
        let file = root[file: Self.file]
        guard file.stat.exists else { return nil }

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
            throw .configuration("cannot read \(file): \(error)")
        }

        let override: Self
        do throws(JSON.Error) {
            override = try .init(
                jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self)
            )
        } catch {
            throw .configuration("cannot decode \(file): \(error)")
        }
        return try override.validated()
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "add": value.add.json,
            "remove": value.remove.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let members = json.object else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        var object = [Swift.String: JSON]()
        for member in members {
            guard object.updateValue(member.value, forKey: member.key) == nil else {
                throw .typeMismatch(
                    expected: "unique \(filename) keys",
                    got: "duplicate \(member.key)"
                )
            }
        }
        let expected: Set<Swift.String> = ["version", "add", "remove"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "\(filename) keys version, add and remove",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let add = object["add"] else { throw .missingKey("add") }
        guard let remove = object["remove"] else { throw .missingKey("remove") }
        return try .init(
            version: Swift.Int(json: version),
            add: [Workspace.Repository.Key](json: add),
            remove: [Workspace.Repository.Key](json: remove)
        )
    }
}
