public import File_System
import JSON

extension Workspace.Configuration {
    public struct Document: Equatable, Sendable {
        public let configuration: Workspace.Configuration
        public let bytes: [Byte]

        internal init(
            configuration: Workspace.Configuration,
            bytes: [Byte]
        ) {
            self.configuration = configuration
            self.bytes = bytes
        }
    }
}

extension Workspace.Configuration.Document {
    public static func load(at root: File.Directory) throws(Workspace.Error) -> Self {
        let file = root[file: "Institute.json"]
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

        let configuration: Workspace.Configuration
        do throws(JSON.Error) {
            configuration = try .init(
                jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self)
            )
        } catch {
            throw .configuration("cannot decode \(file): \(error)")
        }

        return try .init(
            configuration: configuration.validated(),
            bytes: bytes
        )
    }
}
