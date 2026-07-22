public import File_System
public import Xcode_Workspace

extension Workspace {
    public enum Xcode {
        public static func document(
            _ repositories: [Repository]
        ) -> Xcode_Workspace.Xcode.Workspace {
            Xcode_Workspace.Xcode.Workspace(
                references: [
                    .init(location: .group("Application"))
                ] + repositories.map {
                    .init(location: .group("Packages/\($0.name)"))
                }
            )
        }

        public static func render(_ repositories: [Repository]) -> Swift.String {
            document(repositories).xml
        }

        public static func path(at root: File.Directory) -> File {
            root[directory: "institute.xcworkspace"][file: "contents.xcworkspacedata"]
        }

        public static func current(_ repositories: [Repository], at root: File.Directory) -> Bool {
            let location = path(at: root)
            guard let contents = try? location.read.full({ bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in 0..<bytes.count {
                    storage.append(bytes[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }) else {
                return false
            }
            return contents == render(repositories)
        }

        public static func write(
            _ repositories: [Repository],
            at root: File.Directory
        ) throws(Workspace.Error) {
            let bundle = root[directory: "institute.xcworkspace"]
            do throws(Xcode_Workspace.Xcode.Workspace.Error) {
                try document(repositories).write(to: bundle.description)
            } catch {
                throw .filesystem("cannot write \(bundle): \(error)")
            }
        }
    }
}
