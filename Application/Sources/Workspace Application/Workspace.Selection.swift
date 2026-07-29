public import File_System
public import JSON

extension Workspace {
    public struct Selection: Equatable, Sendable, JSON.Serializable {
        public let version: Int
        public let repositories: [Repository.Key]

        public init(version: Int, repositories: [Repository.Key]) {
            self.version = version
            self.repositories = repositories
        }
    }
}

extension Workspace.Selection {
    /// The committed policy document: the public default checkout.
    ///
    /// It is tracked, and it is the authority for what a fresh clone opens.
    /// A developer changing only their own checkout writes
    /// ``Workspace/Selection/Override`` instead, which is ignored.
    public static let file: File.Path.Component = "Selection.json"

    /// ``file`` as it is spelled in diagnostics.
    public static var filename: Swift.String { file.string }

    public static func load(at root: File.Directory) throws(Workspace.Error) -> Self {
        let file = root[file: Self.file]
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

        let selection: Self
        do throws(JSON.Error) {
            selection = try .init(
                jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self)
            )
        } catch {
            throw .configuration("cannot decode \(file): \(error)")
        }
        return try selection.validated()
    }

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": value.version.json,
            "repositories": value.repositories.json,
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
                    expected: "unique Selection keys",
                    got: "duplicate \(member.key)"
                )
            }
        }
        let expected: Set<Swift.String> = ["version", "repositories"]
        let actual = Set(object.keys)
        guard actual == expected else {
            throw .typeMismatch(
                expected: "Selection keys version and repositories",
                got: actual.sorted().joined(separator: ", ")
            )
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        guard let repositories = object["repositories"] else {
            throw .missingKey("repositories")
        }
        return try .init(
            version: Int(json: version),
            repositories: [Workspace.Repository.Key](json: repositories)
        )
    }
}
