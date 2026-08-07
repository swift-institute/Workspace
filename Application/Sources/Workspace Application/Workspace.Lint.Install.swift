private import File_System
private import Process

extension Workspace.Lint {
    /// Downloads the platform-matched linter binaries, verifies them
    /// against the release's own checksum file, and records which build
    /// is installed.
    ///
    /// The trust anchor is the same one CI relies on: GitHub TLS plus
    /// write control over the release. The checksum verification proves
    /// the bytes that arrived are the bytes the release publishes; it is
    /// not a signature and is not claimed as one.
    ///
    /// Installation is digest-addressed, so re-running after an upstream
    /// republish installs beside the previous build rather than over it,
    /// and the previous build remains intact for a comparison.
    public func install() throws(Workspace.Error) {
        try Workspace.Root.preflight(tools, under: hierarchy)
        try Workspace.Root.preflight(state, under: hierarchy)
        try create(tools)
        try create(state)

        let staging = try stagingDirectory()
        defer {
            do throws(File.System.Delete.Error) {
                try staging.delete.recursive()
            } catch {}
        }

        for asset in [Asset.checksums, Asset.manifest, Asset.executable, Asset.runner] {
            try download(asset, into: staging)
        }

        let expected = try checksums(in: staging)
        for asset in [Asset.manifest, Asset.executable, Asset.runner] {
            guard let digest = expected[asset] else {
                throw .configuration(
                    "\(Asset.checksums) does not cover \(asset); refusing to install an unverified file"
                )
            }
            let actual = try digestOf(staging[file: try Self.component(asset)])
            guard actual == digest else {
                throw .configuration(
                    "checksum mismatch for \(asset): the release records \(digest), "
                        + "the downloaded file hashes to \(actual)"
                )
            }
        }

        let manifest = try Manifest.parse(
            try Self.read(staging[file: try Self.component(Asset.manifest)]),
            label: "downloaded \(Asset.manifest)"
        )

        let destination = try installation(for: manifest)
        try Workspace.Root.preflight(destination, under: hierarchy)
        try create(destination)

        try place(
            staging[file: try Self.component(Asset.executable)],
            at: destination[file: "swift-linter"],
            permissions: .executable
        )
        try place(
            staging[file: try Self.component(Asset.runner)],
            at: destination[file: "swift-linter-runner"],
            permissions: .executable
        )
        try place(
            staging[file: try Self.component(Asset.manifest)],
            at: destination[file: "MANIFEST.txt"],
            permissions: .defaultFile
        )
        try place(
            staging[file: try Self.component(Asset.checksums)],
            at: destination[file: "SHA256SUMS"],
            permissions: .defaultFile
        )
        try place(
            staging[file: try Self.component(Asset.manifest)],
            at: manifestFile,
            permissions: .defaultFile
        )

        let findings = try diagnostics()
        guard findings.isEmpty else {
            throw .configuration(findings.joined(separator: "\n"))
        }
    }

    /// Reports drift in the installed binaries or in their parity with
    /// the build CI consumes, without changing anything.
    ///
    /// Contacts the network, unlike a lint run: this is the operation
    /// whose entire purpose is to compare against CI.
    public func diagnostics() throws(Workspace.Error) -> [Swift.String] {
        guard manifestFile.stat.isFile else {
            return ["swift-linter is not installed; run `institute lint install`"]
        }
        var findings = [Swift.String]()
        let manifest = try installedManifest()

        let executable = try executable(for: manifest)
        let runner = try runner(for: manifest)
        if !executable.stat.isFile {
            findings.append("missing linter dispatcher: \(executable)")
        }
        if !runner.stat.isFile {
            findings.append("missing prebuilt standard runner: \(runner)")
        }
        guard findings.isEmpty else { return findings }

        findings.append(contentsOf: try divergence())
        return findings
    }

    /// Compares the installed build against the one CI consumes.
    ///
    /// The composite digest is identical across platforms for a build
    /// made from the same revisions, so a macOS install and the Linux
    /// build CI downloads compare directly. Build time, toolchain, and
    /// platform legitimately differ and are excluded from the
    /// comparison.
    ///
    /// The macOS asset publishes on a slower cadence than the Linux one,
    /// so a divergence here is an expected transient rather than a
    /// defect — which is exactly why it must be surfaced rather than
    /// discovered later as a local-versus-CI disagreement.
    public func divergence() throws(Workspace.Error) -> [Swift.String] {
        let installed = try installedManifest()
        let published = try Manifest.parse(
            try fetch(Asset.ciManifest),
            label: "published \(Asset.ciManifest)"
        )
        guard installed.digest != published.digest else { return [] }

        var findings = [
            "swift-linter parity: installed digest \(installed.digest) is not the digest CI "
                + "consumes (\(published.digest)); run `institute lint install`"
        ]
        for entry in published.revisions {
            let local = installed.value(for: entry.key)
            if local != entry.value {
                findings.append(
                    "  \(entry.key): installed \(local ?? "absent"), CI \(entry.value)"
                )
            }
        }
        return findings
    }
}

extension Workspace.Lint {
    private func stagingDirectory() throws(Workspace.Error) -> File.Directory {
        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: tools.path,
                prefix: ".workspace-swift-linter-",
                suffix: ".download"
            )
        } catch {
            throw .filesystem("cannot allocate a download path beside \(tools): \(error)")
        }
        let directory = File.Directory(path)
        try Workspace.Root.preflight(directory, under: hierarchy)
        try create(directory)
        return directory
    }

    private func download(
        _ asset: Swift.String,
        into directory: File.Directory
    ) throws(Workspace.Error) {
        _ = try run(
            "curl",
            arguments: [
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--retry", "2",
                "--output", directory[file: try Self.component(asset)].description,
                "\(origin)/\(asset)",
            ]
        )
        guard directory[file: try Self.component(asset)].stat.isFile else {
            throw .process("\(asset) did not download to \(directory)")
        }
    }

    /// One published asset's contents, without installing anything.
    ///
    /// Internal rather than private because the currency check reads the
    /// published manifest through it: separating "this installation is
    /// behind the release" from "the release is behind main" needs the
    /// release, and re-implementing the fetch beside it would be a second
    /// spelling of the same request.
    func fetch(_ asset: Swift.String) throws(Workspace.Error) -> Swift.String {
        try run(
            "curl",
            arguments: [
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--retry", "2",
                "\(origin)/\(asset)",
            ]
        )
    }

    /// The `SHA256SUMS` file as a name → digest map.
    ///
    /// Lines are `<hex>  <name>`, with the name unqualified. A malformed
    /// line is not skipped quietly — a checksum file that fails to cover
    /// an asset makes the install refuse, and silently dropping lines
    /// would turn coverage into a coin toss.
    private func checksums(
        in directory: File.Directory
    ) throws(Workspace.Error) -> [Swift.String: Swift.String] {
        let text = try Self.read(directory[file: try Self.component(Asset.checksums)])
        var digests = [Swift.String: Swift.String]()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count == 2 else {
                throw .configuration("malformed line in \(Asset.checksums): \(line)")
            }
            digests[Swift.String(fields[1])] = Swift.String(fields[0])
        }
        guard !digests.isEmpty else {
            throw .configuration("\(Asset.checksums) is empty; nothing could be verified")
        }
        return digests
    }

    /// The SHA-256 of `file`, as lowercase hexadecimal.
    ///
    /// Spawns the platform digest tool rather than hashing in-process:
    /// the ecosystem publishes no SHA-2 implementation, and CI verifies
    /// the same assets the same way with `sha256sum -c`. The comparison
    /// itself stays here rather than being delegated to the tool's own
    /// `-c` mode, so the failure is this capability's to report.
    private func digestOf(_ file: File) throws(Workspace.Error) -> Swift.String {
        let output = try run("shasum", arguments: ["-a", "256", file.description])
        guard
            let field = output.split(separator: " ", omittingEmptySubsequences: true).first,
            field.count == 64,
            field.allSatisfy(\.isHexDigit)
        else {
            throw .process("cannot read a SHA-256 digest for \(file) out of: \(output)")
        }
        return Swift.String(field).lowercased()
    }

    private func place(
        _ source: File,
        at destination: File,
        permissions: File.System.Metadata.Permissions
    ) throws(Workspace.Error) {
        if destination.stat.exists {
            do throws(File.System.Delete.Error) {
                try destination.delete()
            } catch {
                throw .filesystem("cannot replace \(destination): \(error)")
            }
        }
        do throws(File.System.Copy.Error) {
            try source.copy.to(destination)
        } catch {
            throw .filesystem("cannot install \(destination): \(error)")
        }
        do throws(File.System.Metadata.Permissions.Error) {
            try File.System.Metadata.Permissions.set(permissions, at: destination.path)
        } catch {
            throw .filesystem("cannot set permissions on \(destination): \(error)")
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
            throw .process(
                "\(executable) \(arguments.joined(separator: " ")) failed: \(diagnostic)"
            )
        }
        return Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
    }
}
