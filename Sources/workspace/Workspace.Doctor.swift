public import Foundation

extension Workspace {
    public struct Doctor {
        public let root: URL
        public let configuration: Configuration

        public init(root: URL, configuration: Configuration) {
            self.root = root
            self.configuration = configuration
        }

        public func run() throws(Workspace.Error) {
            var errors = [String]()
            var warnings = [String]()

            let swift = try Shell.run(["swift", "--version"])
            if swift.code != 0 || !swift.text.contains(configuration.swift) {
                errors.append("Swift \(configuration.swift) is required; found \(swift.text.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            let xcode = try Shell.run(["xcodebuild", "-version"])
            if xcode.code != 0 || !xcode.text.contains("Xcode \(configuration.xcode)") {
                errors.append(
                    "Xcode \(configuration.xcode) is required; found \(xcode.text.trimmingCharacters(in: .whitespacesAndNewlines))"
                )
            }
            if !Xcode.current(configuration.repositories, at: root) {
                errors.append("institute.xcworkspace does not match Workspace.json")
            }

            let packages = root.appending(path: "Packages")
            for repository in configuration.repositories {
                let path = packages.appending(path: repository.name)
                guard Git.exists(at: path) else {
                    errors.append("\(repository.name): missing or not a Git repository")
                    continue
                }
                let remote = try Git.value(["remote", "get-url", "origin"], at: path)
                if remote != repository.url {
                    errors.append("\(repository.name): wrong origin \(remote)")
                }
                let upstream = try Git.upstream(at: path)
                if upstream != "origin/main" {
                    errors.append("\(repository.name): local main does not track origin/main")
                }
                if try !Git.clean(at: path) {
                    warnings.append("\(repository.name): worktree is dirty; sync will not update it")
                }
                let branch = try Git.branch(at: path)
                if branch != "main" {
                    warnings.append("\(repository.name): current branch is \(branch.isEmpty ? "detached" : branch); sync will not switch it")
                }
                if upstream == "origin/main" {
                    let ahead = try Git.count("origin/main..main", at: path)
                    let behind = try Git.count("main..origin/main", at: path)
                    if ahead > 0 || behind > 0 {
                        errors.append(
                            "\(repository.name): local main is not synchronized with the last fetched origin/main (ahead \(ahead), behind \(behind))"
                        )
                    }
                }
                let identity = try package(at: path)
                if identity != repository.name {
                    errors.append("\(repository.name): manifest identity is \(identity)")
                }
            }

            for warning in warnings { print("warning: \(warning)") }
            for error in errors { print("error: \(error)") }
            guard errors.isEmpty else {
                throw .repository("doctor found \(errors.count) error(s) and \(warnings.count) warning(s)")
            }
            print("Doctor passed with \(warnings.count) warning(s).")
        }

        private func package(at repository: URL) throws(Workspace.Error) -> String {
            let manifest = repository.appending(path: "Package.swift")
            let text: String
            do {
                text = try String(contentsOf: manifest, encoding: .utf8)
            } catch {
                throw .filesystem("cannot read \(manifest.path): \(error)")
            }
            for line in text.split(separator: "\n") {
                let value = line.trimmingCharacters(in: .whitespaces)
                guard value.hasPrefix("name:") else { continue }
                let parts = value.split(separator: "\"")
                if parts.count >= 2 { return String(parts[1]) }
            }
            throw .configuration("cannot determine package identity from \(manifest.path)")
        }
    }
}
