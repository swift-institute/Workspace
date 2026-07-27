private import Environment
private import POSIX_Kernel_Process
private import Process

extension Workspace.Navigation {
    /// Runs the SourceKit-LSP selected by Xcode with the invoking stdio and
    /// working directory. `TOOLCHAINS` is removed from the child's complete
    /// environment snapshot so cclsp cannot launch a skewed semantic engine.
    public static func serve() throws(Workspace.Error) -> Never {
        let server = try sourceKitLSP()
        var environment = Environment.Snapshot.current()
        environment["TOOLCHAINS"] = nil
        let arguments = [server]
        let variables = environment.values.keys.sorted().map { key in
            "\(key)=\(environment.values[key] ?? "")"
        }

        do {
            try unsafe withCStringArray(arguments) { argumentVector in
                try unsafe withCStringArray(variables) { environmentVector in
                    try unsafe server.withCString { path in
                        try unsafe POSIX.Kernel.Process.Execute.execve(
                            path: path,
                            argv: argumentVector,
                            envp: environmentVector
                        )
                    }
                }
            }
        } catch {
            throw .process("cannot replace navigation launcher with SourceKit-LSP: \(error)")
        }
        throw .process("SourceKit-LSP execution returned without replacing the launcher")
    }

    static func sourceKitLSP() throws(Workspace.Error) -> Swift.String {
        var environment = Environment.Snapshot.current()
        environment["TOOLCHAINS"] = nil
        let developer = Workspace.Doctor.line(
            try spawn(
                "xcode-select",
                arguments: ["--print-path"],
                environment: environment.values
            )
        )
        guard !developer.isEmpty else {
            throw .configuration("xcode-select reported no developer directory")
        }
        let server = Workspace.Doctor.line(
            try spawn(
                "xcrun",
                arguments: ["--find", "sourcekit-lsp"],
                environment: environment.values
            )
        )
        guard !server.isEmpty else {
            throw .configuration("xcrun resolved no sourcekit-lsp")
        }
        guard server.hasPrefix(developer + "/") else {
            throw .configuration(
                "sourcekit-lsp resolves to \(server), outside the selected Xcode at \(developer)"
            )
        }
        return server
    }

    private static func spawn(
        _ executable: Swift.String,
        arguments: [Swift.String],
        environment: [Swift.String: Swift.String]
    ) throws(Workspace.Error) -> Swift.String {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: [executable] + arguments,
                    environment: environment,
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

    /// Holds every C string alive until `body` returns. `execve` does not
    /// return on success, so these allocations exist only on its failure path.
    @unsafe
    private static func withCStringArray<Result>(
        _ values: [Swift.String],
        _ body: (
            UnsafePointer<UnsafePointer<CChar>?>
        ) throws -> Result
    ) throws -> Result {
        var pointers: [UnsafePointer<CChar>?] = unsafe []
        unsafe pointers.reserveCapacity(values.count + 1)

        func descend(_ index: Swift.Int) throws -> Result {
            guard index < values.count else {
                unsafe pointers.append(nil)
                defer { unsafe pointers.removeLast() }
                return try unsafe pointers.withUnsafeBufferPointer { buffer in
                    try unsafe body(buffer.baseAddress!)
                }
            }
            return try unsafe values[index].withCString { pointer in
                unsafe pointers.append(pointer)
                defer { unsafe pointers.removeLast() }
                return try descend(index + 1)
            }
        }

        return try descend(0)
    }
}
