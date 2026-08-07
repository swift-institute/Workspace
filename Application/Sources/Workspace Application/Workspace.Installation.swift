private import Environment
public import File_System

extension Workspace {
    /// The account-local installation of the Workspace command.
    ///
    /// The executable is copied out of SwiftPM's generated build state so a
    /// later package clean cannot break the command. A relative symbolic link
    /// in `.local/bin` exposes that copy without recording the account's
    /// absolute path.
    public struct Installation: Sendable {
        public let source: File
        public let home: File.Directory
        public let command: File
        public let executable: File

        private let environmentPath: Swift.String

        /// Resolves the running executable and the invoking account's home.
        ///
        /// - Throws: ``Workspace/Error`` when `HOME`, `PATH`, or the running
        ///   executable cannot be resolved.
        public init() throws(Workspace.Error) {
            guard let value = Environment.read("HOME"), !value.isEmpty else {
                throw .configuration(
                    "HOME is not available, so the account-local command cannot be installed"
                )
            }
            guard let environmentPath = Environment.read("PATH") else {
                throw .configuration(
                    "PATH is not available, so command discovery cannot be verified"
                )
            }

            let home: File.Directory
            do throws(Paths.Path.Error) {
                home = try File.Directory(validating: value)
            } catch {
                throw .configuration("HOME is not a usable path \(value): \(error)")
            }

            try self.init(
                source: Self.runningExecutable(searching: environmentPath),
                home: home,
                environmentPath: environmentPath
            )
        }

        /// Creates an installation against explicit filesystem inputs.
        ///
        /// This initializer is the fixture boundary. Production resolves the
        /// same inputs from the running process through ``init()``.
        internal init(
            source: File,
            home: File.Directory,
            environmentPath: Swift.String
        ) throws(Workspace.Error) {
            self.source = try Self.regularFile(resolving: source)
            self.home = home
            self.environmentPath = environmentPath

            let local = home[directory: ".local"]
            let root =
                local[directory: "share"][directory: "swift-institute"][directory: "institute"]
            self.command = local[directory: "bin"][file: "institute"]
            self.executable = root[directory: "bin"][file: "institute"]
        }
    }
}

extension Workspace.Installation {
    /// Installs or refreshes the account-local Workspace command.
    ///
    /// A prior installation is replaced only when its receipt and launcher
    /// prove that this installer owns it. Existing unmanaged files, directories,
    /// and symbolic links are rejected before any mutation.
    public func install() throws(Workspace.Error) {
        guard commandDirectoryIsOnPath else {
            throw .configuration(
                """
                \(commandDirectory) is not on PATH, so installing there would not expose \
                `institute`. Add it to the current shell first:
                  export PATH="$HOME/.local/bin:$PATH"
                then run the bootstrap command again.
                """
            )
        }

        let conflicts = try conflicts()
        guard conflicts.isEmpty else {
            throw .filesystem(conflicts.joined(separator: "\n"))
        }

        for directory in directoriesToCreate {
            do throws(File.System.Create.Directory.Error) {
                try directory.create.recursive()
            } catch {
                throw .filesystem("cannot create \(directory): \(error)")
            }
        }

        if try metadata(at: receipt.path) == nil {
            do throws(File.System.Write.Atomic.Error) {
                try receipt.write.atomic(Self.receipt)
            } catch {
                throw .filesystem("cannot write installation receipt \(receipt): \(error)")
            }
            do throws(File.System.Metadata.Permissions.Error) {
                try File.System.Metadata.Permissions.set(.defaultFile, at: receipt.path)
            } catch {
                throw .filesystem("cannot set installation receipt permissions: \(error)")
            }
        }

        try placeExecutable()

        if try metadata(at: command.path) == nil {
            do throws(File.System.Link.Symbolic.Error) {
                try File.System.Link.Symbolic.create(
                    at: command.path,
                    pointingTo: Self.commandTarget
                )
            } catch {
                throw .filesystem("cannot create Workspace command link \(command): \(error)")
            }
        }

        let findings = try diagnostics()
        guard findings.isEmpty else {
            throw .filesystem(findings.joined(separator: "\n"))
        }
    }
}

extension Workspace.Installation {
    private static let receipt =
        """
        managed-by=institute install
        version=1
        """

    /// Relative from `$HOME/.local/bin/institute` to the managed executable.
    private static let commandTarget =
        File.Path("../share/swift-institute/institute/bin/institute")

    private var local: File.Directory {
        home[directory: ".local"]
    }

    private var commandDirectory: File.Directory {
        local[directory: "bin"]
    }

    private var share: File.Directory {
        local[directory: "share"]
    }

    private var institute: File.Directory {
        share[directory: "swift-institute"]
    }

    private var root: File.Directory {
        institute[directory: "institute"]
    }

    private var executableDirectory: File.Directory {
        root[directory: "bin"]
    }

    private var receipt: File {
        root[file: "INSTALLATION"]
    }

    private var directories: [File.Directory] {
        [home, local, commandDirectory, share, institute, root, executableDirectory]
    }

    private var directoriesToCreate: [File.Directory] {
        Array(directories.dropFirst())
    }

    private var commandDirectoryIsOnPath: Swift.Bool {
        for value in environmentPath.split(
            separator: ":",
            omittingEmptySubsequences: false
        ) where !value.isEmpty {
            let directory: File.Directory
            do throws(Paths.Path.Error) {
                directory = try File.Directory(validating: Swift.String(value))
            } catch {
                continue
            }
            if directory == commandDirectory {
                return true
            }
        }
        return false
    }
}

extension Workspace.Installation {
    private func conflicts() throws(Workspace.Error) -> [Swift.String] {
        var findings = [Swift.String]()
        for directory in directories {
            guard let info = try metadata(at: directory.path) else { continue }
            guard info.type == .directory else {
                findings.append(
                    "refusing to replace non-directory installation path: \(directory)"
                )
                continue
            }
        }

        let rootExists = try metadata(at: root.path) != nil
        let receiptInfo = try metadata(at: receipt.path)
        var managed = false
        if rootExists {
            guard let receiptInfo else {
                findings.append(
                    "refusing to adopt unmanaged installation directory without a receipt: \(root)"
                )
                return findings
            }
            guard receiptInfo.type == .regular else {
                findings.append(
                    "refusing to replace non-file installation receipt: \(receipt)"
                )
                return findings
            }
            guard try read(receipt) == Self.receipt else {
                findings.append(
                    "refusing to replace divergent installation receipt: \(receipt)"
                )
                return findings
            }
            managed = true
        }

        if let info = try metadata(at: executable.path), info.type != .regular {
            findings.append(
                "refusing to replace non-file managed executable: \(executable)"
            )
        }

        if let info = try metadata(at: command.path) {
            guard managed else {
                findings.append(
                    "refusing to replace unmanaged Workspace command: \(command)"
                )
                return findings
            }
            guard info.type == .symbolicLink else {
                findings.append(
                    "refusing to replace non-link Workspace command: \(command)"
                )
                return findings
            }
            guard try target(of: command.path) == Self.commandTarget else {
                findings.append(
                    "refusing to replace divergent Workspace command link: \(command)"
                )
                return findings
            }
        }

        return findings
    }

    private func diagnostics() throws(Workspace.Error) -> [Swift.String] {
        var findings = [Swift.String]()
        if !commandDirectoryIsOnPath {
            findings.append("Workspace command directory is not on PATH: \(commandDirectory)")
        }
        for directory in directories {
            guard let info = try metadata(at: directory.path) else {
                findings.append("missing installation directory: \(directory)")
                continue
            }
            guard info.type == .directory else {
                findings.append("installation path is not a directory: \(directory)")
                continue
            }
        }
        guard
            let receiptInfo = try metadata(at: receipt.path),
            receiptInfo.type == .regular,
            try read(receipt) == Self.receipt
        else {
            findings.append("missing or divergent installation receipt: \(receipt)")
            return findings
        }
        guard
            let executableInfo = try metadata(at: executable.path),
            executableInfo.type == .regular
        else {
            findings.append("missing managed Workspace executable: \(executable)")
            return findings
        }
        do throws(File.System.Metadata.Permissions.Error) {
            if try File.System.Metadata.Permissions(at: executable.path) != .executable {
                findings.append("managed Workspace executable is not executable: \(executable)")
            }
        } catch {
            throw .filesystem("cannot inspect Workspace executable permissions: \(error)")
        }
        guard
            let commandInfo = try metadata(at: command.path),
            commandInfo.type == .symbolicLink,
            try target(of: command.path) == Self.commandTarget
        else {
            findings.append("missing or divergent Workspace command link: \(command)")
            return findings
        }
        do throws(File.System.Canonical.Error) {
            let resolvedCommand = try File.System.Canonical.resolve(command.path)
            let resolvedExecutable = try File.System.Canonical.resolve(executable.path)
            if resolvedCommand != resolvedExecutable {
                findings.append("Workspace command does not resolve to \(executable)")
            }
        } catch {
            throw .filesystem("cannot resolve installed Workspace command \(command): \(error)")
        }
        return findings
    }
}

extension Workspace.Installation {
    private func placeExecutable() throws(Workspace.Error) {
        let stagingPath: File.Path
        do throws(File.Path.Temporary.Error) {
            stagingPath = try File.Path.Temporary.sibling(
                of: executable.path,
                prefix: ".workspace-",
                suffix: ".install"
            )
        } catch {
            throw .filesystem("cannot allocate an installation path beside \(executable): \(error)")
        }
        let staging = File(stagingPath)
        defer {
            do throws(File.System.Delete.Error) {
                if staging.stat.exists {
                    try staging.delete()
                }
            } catch {}
        }

        do throws(File.System.Copy.Error) {
            try source.copy.to(staging)
        } catch {
            throw .filesystem("cannot stage the Workspace executable: \(error)")
        }
        do throws(File.System.Metadata.Permissions.Error) {
            try File.System.Metadata.Permissions.set(.executable, at: staging.path)
        } catch {
            throw .filesystem("cannot make the staged Workspace executable executable: \(error)")
        }
        do throws(File.System.Move.Error) {
            try staging.move.to(
                executable,
                options: .init(overwrite: true)
            )
        } catch {
            throw .filesystem("cannot install the Workspace executable at \(executable): \(error)")
        }
    }

    private static func runningExecutable(
        searching environmentPath: Swift.String
    ) throws(Workspace.Error) -> File {
        guard let argument = CommandLine.arguments.first, !argument.isEmpty else {
            throw .configuration("the running Workspace executable has no command path")
        }

        if argument.contains("/") {
            let path: File.Path
            do throws(Paths.Path.Error) {
                path = try File.Path(argument)
            } catch {
                throw .configuration("the running Workspace command path is invalid: \(error)")
            }
            return try regularFile(resolving: File(path))
        }

        let component: File.Path.Component
        do throws(File.Path.Component.Error) {
            component = try File.Path.Component(argument)
        } catch {
            throw .configuration("the running Workspace command name is invalid: \(error)")
        }
        for value in environmentPath.split(
            separator: ":",
            omittingEmptySubsequences: false
        ) where !value.isEmpty {
            let directory: File.Directory
            do throws(Paths.Path.Error) {
                directory = try File.Directory(validating: Swift.String(value))
            } catch {
                continue
            }
            let candidate = directory[file: component]
            do {
                return try regularFile(resolving: candidate)
            } catch {}
        }
        throw .configuration(
            "cannot resolve the running Workspace executable named \(argument) through PATH"
        )
    }

    private static func regularFile(
        resolving file: File
    ) throws(Workspace.Error) -> File {
        let path: File.Path
        do throws(File.System.Canonical.Error) {
            path = try File.System.Canonical.resolve(file.path)
        } catch {
            throw .configuration("cannot resolve the Workspace executable \(file): \(error)")
        }
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try File.System.Stat.info(at: path, followSymlinks: false)
        } catch {
            throw .configuration("cannot inspect the Workspace executable \(path): \(error)")
        }
        guard info.type == .regular else {
            throw .configuration("Workspace executable is not a regular file: \(path)")
        }
        return File(path)
    }

    private func metadata(
        at path: File.Path
    ) throws(Workspace.Error) -> File.System.Metadata.Info? {
        do throws(Kernel.File.Stats.Error) {
            return try File.System.Stat.info(at: path, followSymlinks: false)
        } catch {
            if case .platform(let platform) = error, platform.code.isNotFound {
                return nil
            }
            throw .filesystem("cannot inspect \(path): \(error)")
        }
    }

    private func read(_ file: File) throws(Workspace.Error) -> Swift.String {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try file.read.full { bytes in
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
    }

    private func target(of path: File.Path) throws(Workspace.Error) -> File.Path {
        do throws(File.System.Link.Read.Target.Error) {
            return try File.System.Link.Read.Target.target(of: path)
        } catch {
            throw .filesystem("cannot read symbolic link \(path): \(error)")
        }
    }
}
