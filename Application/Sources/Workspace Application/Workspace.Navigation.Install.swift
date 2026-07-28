private import File_System
private import Git_Foundation
private import Process

extension Workspace.Navigation {
    /// Installs the pinned cclsp source, builds it with its frozen Bun lockfile,
    /// and atomically writes generated MCP and LSP configuration.
    public func install() throws(Workspace.Error) {
        try root.preflight(tools, under: root.hierarchy)
        try root.preflight(state, under: root.hierarchy)
        try create(tools)
        try create(state)
        try root.preflight(source, under: root.hierarchy)
        try installSource()

        let sourceFindings = try sourceDiagnostics()
        guard sourceFindings.isEmpty else {
            throw .configuration(
                "refusing to build divergent cclsp source:\n"
                    + sourceFindings.joined(separator: "\n")
            )
        }
        try requireNode()
        try run(
            "bun",
            arguments: ["install", "--frozen-lockfile"],
            at: source
        )
        try run(
            "bun",
            arguments: ["run", "build"],
            at: source
        )
        guard executable.stat.isFile else {
            throw .process("cclsp build did not produce \(executable)")
        }
        guard workspaceExecutable.stat.isFile else {
            throw .configuration(
                "Workspace executable is missing at \(workspaceExecutable); "
                    + "bootstrap Application before installing navigation"
            )
        }

        try write(renderedConfiguration(), to: configurationFile)
        try write(renderedDescriptor(), to: descriptorFile)

        let findings = try diagnostics()
        guard findings.isEmpty else {
            throw .configuration(findings.joined(separator: "\n"))
        }
    }

    /// Reports drift in the installed source, build product, or generated
    /// configuration without changing it.
    public func diagnostics() throws(Workspace.Error) -> [Swift.String] {
        try root.preflight(source, under: root.hierarchy)
        var findings = try sourceDiagnostics()
        guard File(source.path).stat.isDirectory else {
            return findings
        }

        try run("bun", arguments: ["--version"], at: source)
        try requireNode()
        _ = try Self.sourceKitLSP()

        if !executable.stat.isFile {
            findings.append("missing cclsp build product: \(executable)")
        }
        if !workspaceExecutable.stat.isFile {
            findings.append("missing Workspace executable: \(workspaceExecutable)")
        }
        try compare(
            configurationFile,
            with: renderedConfiguration(),
            label: "cclsp configuration",
            findings: &findings
        )
        try compare(
            descriptorFile,
            with: renderedDescriptor(),
            label: "MCP descriptor",
            findings: &findings
        )
        return findings
    }

    private func sourceDiagnostics() throws(Workspace.Error) -> [Swift.String] {
        var findings = [Swift.String]()
        guard File(source.path).stat.isDirectory else {
            return ["missing pinned cclsp source: \(source)"]
        }

        do throws(Git.Client.Error) {
            guard try client.repository(at: source.description) else {
                findings.append("cclsp source is not a Git repository: \(source)")
                return findings
            }
            let top = try client.top(at: source.description)
            guard top == source.description else {
                findings.append("cclsp source is nested inside another repository: \(source)")
                return findings
            }
            let remote = try client.remote("origin", at: source.description)
            if remote != Self.repository {
                findings.append("cclsp origin is \(remote), expected \(Self.repository)")
            }
            let branch = try client.branch(at: source.description)
            if branch != Self.installedBranch {
                findings.append(
                    "cclsp branch is \(branch), expected \(Self.installedBranch)"
                )
            }
            let head = try client.head(at: source.description)
            if head.rawValue != Self.revision {
                findings.append("cclsp HEAD is \(head.rawValue), expected \(Self.revision)")
            }
            if !(try client.status(at: source.description)).isEmpty {
                findings.append("cclsp source worktree is dirty: \(source)")
            }
        } catch {
            throw .process("cannot inspect installed cclsp source: \(error)")
        }
        return findings
    }
}

extension Workspace.Navigation {
    private func installSource() throws(Workspace.Error) {
        if File(source.path).stat.exists {
            guard File(source.path).stat.isDirectory else {
                throw .filesystem("refusing to replace non-directory cclsp path: \(source)")
            }
            return
        }

        let parent = tools[directory: "cclsp"]
        try root.preflight(parent, under: root.hierarchy)
        try create(parent)

        let temporaryPath: File.Path
        do throws(File.Path.Temporary.Error) {
            temporaryPath = try File.Path.Temporary.sibling(
                of: source.path,
                prefix: ".workspace-cclsp-",
                suffix: ".clone"
            )
        } catch {
            throw .filesystem("cannot allocate a cclsp clone path: \(error)")
        }
        let temporary = File.Directory(temporaryPath)
        try root.preflight(temporary, under: root.hierarchy)
        defer {
            do throws(File.System.Delete.Error) {
                try temporary.delete.recursive()
            } catch {}
        }

        guard let revision = Git.Object.ID(rawValue: Self.revision) else {
            throw .repository("invalid pinned cclsp revision \(Self.revision)")
        }
        let installedReference: Git.Ref.Name
        do throws(Git.Ref.Name.Error) {
            installedReference = try Git.Ref.Name(
                "refs/heads/\(Self.installedBranch)"
            )
        } catch {
            throw .repository("invalid installed cclsp reference: \(error)")
        }

        do throws(Git.Client.Error) {
            try client.clone(
                Self.repository,
                branch: Self.branch,
                to: temporary.description
            )
            try client.fetch(
                "origin",
                object: revision,
                into: installedReference,
                at: temporary.description
            )
            try client.switch(Self.installedBranch, at: temporary.description)
            let head = try client.head(at: temporary.description)
            guard head.rawValue == Self.revision else {
                throw .object(
                    "cloned \(Self.branch) at \(head.rawValue), expected \(Self.revision)"
                )
            }
        } catch {
            throw .process("cannot clone the pinned cclsp source: \(error)")
        }

        try root.preflight(source, under: root.hierarchy)
        do throws(File.System.Move.Error) {
            try temporary.move.to(source)
        } catch {
            throw .filesystem("cannot install cclsp source at \(source): \(error)")
        }
    }

    private func create(_ directory: File.Directory) throws(Workspace.Error) {
        do throws(File.System.Create.Directory.Error) {
            try directory.create.recursive()
        } catch {
            throw .filesystem("cannot create \(directory): \(error)")
        }
    }

    private func run(
        _ executable: Swift.String,
        arguments: [Swift.String],
        at directory: File.Directory
    ) throws(Workspace.Error) {
        _ = try output(executable, arguments: arguments, at: directory)
    }

    private func output(
        _ executable: Swift.String,
        arguments: [Swift.String],
        at directory: File.Directory
    ) throws(Workspace.Error) -> Swift.String {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: [executable] + arguments,
                    stdout: .pipe,
                    stderr: .pipe,
                    workingDirectory: directory.description
                )
            )
        } catch {
            throw .process("cannot run \(executable) at \(directory): \(error)")
        }
        guard output.status == .exited(code: 0) else {
            let diagnostic = Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
            throw .process(
                "\(executable) \(arguments.joined(separator: " ")) failed at \(directory): "
                    + diagnostic
            )
        }
        return Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
    }

    private func requireNode() throws(Workspace.Error) {
        let version = Workspace.Doctor.line(
            try output("node", arguments: ["--version"], at: source)
        )
        let numeric = version.hasPrefix("v") ? version.dropFirst() : version[...]
        guard
            let component = numeric.split(separator: ".").first,
            let major = Swift.Int(component)
        else {
            throw .configuration("cannot parse Node version: \(version)")
        }
        guard major >= 18 else {
            throw .configuration("cclsp requires Node 18 or newer; found \(version)")
        }
    }

    private func write(
        _ contents: Swift.String,
        to file: File
    ) throws(Workspace.Error) {
        do throws(File.System.Write.Atomic.Error) {
            try file.write.atomic(contents)
        } catch {
            throw .filesystem("cannot write \(file): \(error)")
        }
        do throws(File.System.Metadata.Permissions.Error) {
            try File.System.Metadata.Permissions.set(.defaultFile, at: file.path)
        } catch {
            throw .filesystem("cannot set generated file permissions for \(file): \(error)")
        }
    }

    private func compare(
        _ file: File,
        with expected: Swift.String,
        label: Swift.String,
        findings: inout [Swift.String]
    ) throws(Workspace.Error) {
        guard file.stat.isFile else {
            findings.append("missing \(label): \(file)")
            return
        }
        let actual: Swift.String
        do throws(Either<File.System.Read.Full.Error, Never>) {
            actual = try file.read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            throw .filesystem("cannot read \(file): \(error)")
        }
        if actual != expected {
            findings.append("\(label) differs from generated state: \(file)")
        }
    }
}
