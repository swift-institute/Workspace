public import Foundation

extension Workspace {
    public enum Xcode {
        public static func render(_ repositories: [Repository]) -> String {
            var lines = [
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
                "<Workspace",
                "   version = \"1.0\">",
            ]
            for repository in repositories {
                lines.append("   <FileRef")
                lines.append("      location = \"group:Packages/\(repository.name)\">")
                lines.append("   </FileRef>")
            }
            lines.append("</Workspace>")
            return lines.joined(separator: "\n") + "\n"
        }

        public static func path(at root: URL) -> URL {
            root.appending(path: "institute.xcworkspace/contents.xcworkspacedata")
        }

        public static func current(_ repositories: [Repository], at root: URL) -> Bool {
            let location = path(at: root)
            guard let data = try? Data(contentsOf: location) else { return false }
            return String(decoding: data, as: UTF8.self) == render(repositories)
        }

        public static func write(_ repositories: [Repository], at root: URL) throws(Workspace.Error) {
            let location = path(at: root)
            do {
                try FileManager.default.createDirectory(
                    at: location.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try Data(render(repositories).utf8).write(to: location, options: .atomic)
            } catch {
                throw .filesystem("cannot write \(location.path): \(error)")
            }
        }
    }
}
