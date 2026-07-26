public import File_System
public import Xcode_Workspace

extension Workspace {
    public enum Xcode {}
}

extension Workspace.Xcode {
    public static func document(
        _ repositories: [Workspace.Repository]
    ) -> Xcode_Workspace.Xcode.Workspace {
        Xcode_Workspace.Xcode.Workspace(
            references: [
                .init(location: .group("Application"))
            ]
                + repositories.map {
                    .init(location: .group("Packages/\($0.name)"))
                }
        )
    }

    public static func render(_ repositories: [Workspace.Repository]) -> Swift.String {
        document(repositories).xml
    }

    public static func path(at root: File.Directory) -> File {
        root[directory: "institute.xcworkspace"][file: "contents.xcworkspacedata"]
    }

    public static func contents(at root: File.Directory) -> Swift.String? {
        do throws(File.System.Read.Full.Error) {
            return try path(at: root).read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            return nil
        }
    }

    public static func current(_ repositories: [Workspace.Repository], at root: File.Directory) -> Bool {
        contents(at: root) == render(repositories)
    }

    public static func write(
        _ repositories: [Workspace.Repository],
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
