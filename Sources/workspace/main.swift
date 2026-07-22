import Darwin
import Foundation

do {
    let command = try Workspace.Command.parse(Array(CommandLine.arguments.dropFirst()))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
    let configuration = try Workspace.Configuration.load(at: root)
    switch command {
    case .sync(let dry):
        try Workspace.Sync(root: root, configuration: configuration).run(dry: dry)
    case .doctor:
        try Workspace.Doctor(root: root, configuration: configuration).run()
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
