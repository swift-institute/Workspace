public import Foundation

extension Workspace {
    public enum Git {
        public static func run(_ arguments: [String], at directory: URL? = nil) throws(Workspace.Error) -> Shell.Result {
            try Shell.run(["git"] + arguments, at: directory)
        }

        public static func require(_ arguments: [String], at directory: URL? = nil) throws(Workspace.Error) -> String {
            let result = try run(arguments, at: directory)
            guard result.code == 0 else {
                throw .process("git \(arguments.joined(separator: " ")) failed: \(result.text.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public static func value(_ arguments: [String], at directory: URL) throws(Workspace.Error) -> String {
            try require(["-C", directory.path] + arguments)
        }

        public static func exists(at directory: URL) -> Bool {
            guard let result = try? run(["-C", directory.path, "rev-parse", "--is-inside-work-tree"]) else {
                return false
            }
            return result.code == 0 && result.text.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }

        public static func clean(at directory: URL) throws(Workspace.Error) -> Bool {
            try value(["status", "--porcelain=v1"], at: directory).isEmpty
        }

        public static func branch(at directory: URL) throws(Workspace.Error) -> String {
            try value(["branch", "--show-current"], at: directory)
        }

        public static func upstream(at directory: URL) throws(Workspace.Error) -> String {
            try value(["for-each-ref", "--format=%(upstream:short)", "refs/heads/main"], at: directory)
        }

        public static func count(_ range: String, at directory: URL) throws(Workspace.Error) -> Int {
            let text = try value(["rev-list", "--count", range], at: directory)
            guard let count = Int(text) else {
                throw .repository("invalid revision count for \(range) in \(directory.path)")
            }
            return count
        }
    }
}
