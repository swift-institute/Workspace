private import File_System
private import POSIX_Kernel_Lock
private import Process

extension Build {
    /// Runs SwiftPM operations with one owned interface and isolated evidence builds.
    public struct Coordinator: Sendable {
        public let jobs: Swift.Int

        public init(jobs: Swift.Int = 3) {
            self.jobs = jobs
        }
    }
}

extension Build.Coordinator {
    /// Runs one operation at a Swift package root.
    ///
    /// A fresh build or test uses a unique scratch directory and removes that
    /// generated state afterward. It never mutates `Package.resolved`.
    public func run(
        _ action: Build.Action,
        at path: Swift.String,
        fresh: Swift.Bool = false,
        arguments: [Swift.String] = []
    ) throws(Build.Error) -> Swift.Int32 {
        let candidate: File.Directory
        do throws(File.Path.Error) {
            candidate = try File.Directory(validating: path)
        } catch {
            throw .configuration("invalid package path \(path): \(error)")
        }
        guard candidate[file: "Package.swift"].stat.exists else {
            throw .configuration("no Package.swift at \(candidate)")
        }
        let package: File.Directory
        do throws(File.System.Canonical.Error) {
            package = File.Directory(try File.System.Canonical.resolve(candidate.path))
        } catch {
            throw .filesystem("cannot resolve package path \(candidate): \(error)")
        }
        guard jobs > 0 else {
            throw .configuration("jobs must be greater than zero")
        }
        guard !fresh || action.acceptsFreshScratch else {
            throw .configuration("--fresh is valid only with package build or test")
        }

        _ = try action.invocation(
            jobs: jobs,
            scratchPath: nil,
            arguments: arguments
        )
        let scratch = try freshScratch(for: action, package: package, enabled: fresh)
        let invocation = try action.invocation(
            jobs: jobs,
            scratchPath: scratch?.description,
            arguments: arguments
        )

        let lockPath: File.Path
        do throws(File.Path.Error) {
            lockPath = try File.Path.Temporary.deterministic(
                prefix: "swift-institute-",
                key: "swiftpm-build-coordinator",
                suffix: ".lock"
            )
        } catch {
            try remove(scratch, after: nil)
            throw .filesystem("cannot construct the SwiftPM coordination lock path: \(error)")
        }

        let lock: File.Descriptor
        do {
            lock = try File.Descriptor.open(
                lockPath,
                mode: .readWrite,
                options: [.create, .execClose]
            )
        } catch {
            try remove(scratch, after: nil)
            throw .filesystem("cannot open SwiftPM coordination lock \(lockPath): \(error)")
        }
        do throws(POSIX.Kernel.Lock.Error) {
            try POSIX.Kernel.Lock.lock(
                lock.kernelDescriptor,
                range: .file,
                kind: .exclusive
            )
        } catch {
            try remove(scratch, after: nil)
            throw .filesystem("cannot acquire SwiftPM coordination lock \(lockPath): \(error)")
        }

        var output: Process.Output?
        var failure: Build.Error?
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: invocation,
                    workingDirectory: package.description
                )
            )
        } catch {
            failure = .process("cannot execute \(action.rawValue) at \(package): \(error)")
        }

        do {
            try remove(scratch, after: failure)
        } catch {
            failure = error
        }
        do throws(POSIX.Kernel.Lock.Error) {
            try POSIX.Kernel.Lock.unlock(
                lock.kernelDescriptor,
                range: .file
            )
        } catch {
            let message = "cannot release SwiftPM coordination lock \(lockPath): \(error)"
            failure = failure.map {
                .filesystem("\($0); additionally, \(message)")
            } ?? .filesystem(message)
        }

        if let failure {
            throw failure
        }
        guard let output else {
            throw .process("\(action.rawValue) produced neither output nor an error")
        }

        switch output.status {
        case .exited(let code):
            return code
        case .signaled(let signal):
            throw .process("\(action.rawValue) terminated by signal \(signal)")
        case .stopped(let signal):
            throw .process("\(action.rawValue) stopped by signal \(signal)")
        }
    }

    private func remove(
        _ scratch: File.Directory?,
        after failure: Build.Error?
    ) throws(Build.Error) {
        guard let scratch else { return }
        do throws(File.System.Delete.Error) {
            try scratch.delete.recursive()
        } catch {
            let message = "cannot remove fresh build state \(scratch): \(error)"
            throw failure.map {
                .filesystem("\($0); additionally, \(message)")
            } ?? .filesystem(message)
        }
    }

    private func freshScratch(
        for action: Build.Action,
        package: File.Directory,
        enabled: Swift.Bool
    ) throws(Build.Error) -> File.Directory? {
        guard enabled else { return nil }

        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: package.path,
                prefix: ".workspace-\(action.rawValue)-",
                suffix: ""
            )
        } catch {
            throw .filesystem("cannot allocate fresh build state beside \(package): \(error)")
        }

        let directory = File.Directory(path)
        do throws(File.System.Create.Directory.Error) {
            try directory.create.recursive()
        } catch {
            throw .filesystem("cannot create fresh build state \(directory): \(error)")
        }
        return directory
    }
}
