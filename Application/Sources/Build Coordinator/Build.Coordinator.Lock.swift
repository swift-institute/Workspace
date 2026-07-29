internal import File_System
private import POSIX_Kernel_Lock
internal import Process

extension Build.Coordinator {
    /// Runs one external command while holding the machine-wide coordination
    /// lock, and maps its termination onto an exit status.
    ///
    /// One key — `swiftpm-build-coordinator` — is the whole point. SwiftPM at
    /// a package root and `xcodebuild` over the generated workspace are
    /// different tools contending for the same machine: the shared manifest
    /// and repository caches, the toolchain's module cache, and the source
    /// trees themselves. A second key would be a second machine-wide
    /// invariant, and two of those do not compose — each would be correct
    /// about its own population and blind to the other's.
    ///
    /// The source trees are why this matters *more* for a workspace build
    /// than for a package build, not less. `swift build` compiles a package's
    /// dependencies from pinned remote checkouts under its own `.build`, so a
    /// concurrent edit elsewhere in the hierarchy cannot reach it. A workspace
    /// build compiles every selected package *from the working copy*, so any
    /// coordinated write anywhere in the selection is inside its blast radius.
    /// That has already happened once (issue #7): a whole-workspace build
    /// failed with `type 'Workspace' has no member 'Lint'` because a
    /// concurrent session wrote those sources mid-build. Holding the lock
    /// across the compilation is what makes that unreachable through
    /// coordinated paths.
    ///
    /// Written as one operation both entry points call, rather than as a lock
    /// value each acquires for itself, because the ordering is the part that
    /// has to be identical: acquire, spawn, clean up generated state, release,
    /// and fold a lost release into the operation's own failure instead of
    /// replacing it. Two copies of that sequence would be two chances to drift
    /// in key, in mode, or in what happens on the failure path.
    ///
    /// - Parameters:
    ///   - invocation: The argument vector, run through `/usr/bin/env`.
    ///   - directory: The child's working directory.
    ///   - description: How the operation is named in failure messages.
    ///   - cleanup: Removes any state the caller generated for this run. Runs
    ///     after the child exits and before the lock is released, and on every
    ///     failure path including a failure to acquire. Returns the error to
    ///     report, having folded in anything its own removal hit.
    func coordinated(
        _ invocation: [Swift.String],
        in directory: Swift.String,
        describing description: Swift.String,
        cleanup: (Build.Error?) -> Build.Error?
    ) throws(Build.Error) -> Swift.Int32 {
        let path: File.Path
        do throws(File.Path.Error) {
            path = try File.Path.Temporary.deterministic(
                prefix: "swift-institute-",
                key: "swiftpm-build-coordinator",
                suffix: ".lock"
            )
        } catch {
            let message = "cannot construct the SwiftPM coordination lock path: \(error)"
            throw cleanup(.filesystem(message)) ?? .filesystem(message)
        }

        let lock: File.Descriptor
        do {
            lock = try File.Descriptor.open(
                path,
                mode: .readWrite,
                options: [.create, .execClose]
            )
        } catch {
            let message = "cannot open SwiftPM coordination lock \(path): \(error)"
            throw cleanup(.filesystem(message)) ?? .filesystem(message)
        }
        do throws(POSIX.Kernel.Lock.Error) {
            try POSIX.Kernel.Lock.lock(
                lock.kernelDescriptor,
                range: .file,
                kind: .exclusive
            )
        } catch {
            let message = "cannot acquire SwiftPM coordination lock \(path): \(error)"
            throw cleanup(.filesystem(message)) ?? .filesystem(message)
        }

        var output: Process.Output?
        var failure: Build.Error?
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: invocation,
                    workingDirectory: directory
                )
            )
        } catch {
            failure = .process("cannot execute \(description): \(error)")
        }

        failure = cleanup(failure)

        do throws(POSIX.Kernel.Lock.Error) {
            try POSIX.Kernel.Lock.unlock(lock.kernelDescriptor, range: .file)
        } catch {
            let message = "cannot release SwiftPM coordination lock \(path): \(error)"
            failure = failure.map { .filesystem("\($0); additionally, \(message)") }
                ?? .filesystem(message)
        }

        if let failure {
            throw failure
        }
        guard let output else {
            throw .process("\(description) produced neither output nor an error")
        }

        switch output.status {
        case .exited(let code):
            return code
        case .signaled(let signal):
            throw .process("\(description) terminated by signal \(signal)")
        case .stopped(let signal):
            throw .process("\(description) stopped by signal \(signal)")
        }
    }
}
