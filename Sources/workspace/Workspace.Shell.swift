public import Foundation

extension Workspace {
    public enum Shell {
        public static func run(_ arguments: [String], at directory: URL? = nil) throws(Workspace.Error) -> Result {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = arguments
            process.currentDirectoryURL = directory
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                throw .process("cannot run \(arguments.joined(separator: " ")): \(error)")
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)
            return .init(code: process.terminationStatus, text: output)
        }
    }
}
