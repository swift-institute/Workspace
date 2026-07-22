public import File_System
public import Git_Foundation
public import Package_Manager
private import Process

extension Workspace {
    public struct Doctor: Sendable {
        public let root: File.Directory
        public let configuration: Configuration
        public let git: Git.Client
        public let packages: Package.Manager

        public init(
            root: File.Directory,
            configuration: Configuration,
            git: Git.Client = .init(),
            packages: Package.Manager = .init()
        ) {
            self.root = root
            self.configuration = configuration
            self.git = git
            self.packages = packages
        }

        public func run() throws(Workspace.Error) {
            var errors = [Swift.String]()
            var warnings = [Swift.String]()

            let swift = try tool("swift", arguments: ["--version"])
            if !swift.contains(configuration.swift) {
                errors.append("Swift \(configuration.swift) is required; found \(swift)")
            }
            let xcode = try tool("xcodebuild", arguments: ["-version"])
            if !xcode.contains("Xcode \(configuration.xcode)") {
                errors.append("Xcode \(configuration.xcode) is required; found \(xcode)")
            }
            if !Xcode.current(configuration.repositories, at: root) {
                errors.append("institute.xcworkspace does not match Workspace.json")
            }

            let directory = root[directory: "Packages"]
            for repository in configuration.repositories {
                let path = try path(for: repository, in: directory)
                guard (try? git.repository(at: path.description)) == true else {
                    errors.append("\(repository.name): missing or not a Git repository")
                    continue
                }

                let remote = try execute { () throws(Git.Client.Error) -> Swift.String in
                    try git.remote("origin", at: path.description)
                }
                if remote != repository.url {
                    errors.append("\(repository.name): wrong origin \(remote)")
                }
                let upstream = try execute { () throws(Git.Client.Error) -> Swift.String in
                    try git.upstream("main", at: path.description)
                }
                if upstream != "origin/main" {
                    errors.append("\(repository.name): local main does not track origin/main")
                }
                if try !execute({ () throws(Git.Client.Error) -> [Git.Status.Entry] in
                    try git.status(at: path.description)
                }).isEmpty {
                    warnings.append("\(repository.name): worktree is dirty; sync will not update it")
                }
                let branch = try execute { () throws(Git.Client.Error) -> Swift.String in
                    try git.branch(at: path.description)
                }
                if branch != "main" {
                    warnings.append(
                        "\(repository.name): current branch is \(branch.isEmpty ? "detached" : branch); sync will not switch it"
                    )
                }
                if upstream == "origin/main" {
                    let ahead = try execute { () throws(Git.Client.Error) -> Int in
                        try git.count("origin/main..main", at: path.description)
                    }
                    let behind = try execute { () throws(Git.Client.Error) -> Int in
                        try git.count("main..origin/main", at: path.description)
                    }
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
                throw .repository(
                    "doctor found \(errors.count) error(s) and \(warnings.count) warning(s)"
                )
            }
            print("Doctor passed with \(warnings.count) warning(s).")
        }

        private func package(at repository: File.Directory) throws(Workspace.Error) -> Swift.String {
            do throws(Package.Manager.Error) {
                return try packages.manifest(at: repository.description).name.underlying
            } catch {
                throw .configuration("cannot evaluate manifest at \(repository): \(error)")
            }
        }

        private func tool(
            _ executable: Swift.String,
            arguments: [Swift.String]
        ) throws(Workspace.Error) -> Swift.String {
            let output: Process.Output
            do throws(Process.Error) {
                output = try Process.Spawn.run(
                    .init(
                        executable: "/usr/bin/env",
                        arguments: [executable] + arguments,
                        stdout: .pipe,
                        stderr: .pipe
                    )
                )
            } catch {
                throw .process("cannot run \(executable): \(error)")
            }
            guard output.status == .exited(code: 0) else {
                let diagnostic = Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
                throw .process("\(executable) failed: \(diagnostic)")
            }
            return Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
        }

        private func path(
            for repository: Repository,
            in packages: File.Directory
        ) throws(Workspace.Error) -> File.Directory {
            do throws(File.Path.Component.Error) {
                return packages[directory: try File.Path.Component(repository.name)]
            } catch {
                throw .configuration("invalid repository name \(repository.name): \(error)")
            }
        }

        private func execute<Result>(
            _ operation: () throws(Git.Client.Error) -> Result
        ) throws(Workspace.Error) -> Result {
            do throws(Git.Client.Error) {
                return try operation()
            } catch {
                throw .process("Git operation failed: \(error)")
            }
        }
    }
}
