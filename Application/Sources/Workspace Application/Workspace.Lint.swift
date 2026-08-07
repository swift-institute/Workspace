public import File_System

extension Workspace {
    /// Reproducible local swift-linter, running exactly what CI runs.
    ///
    /// swift-linter is a third-party tool published by
    /// `swift-foundations/swift-linter`. Workspace owns only the
    /// installation boundary, the invocation, and the measurement
    /// discipline around it — never the rules, the severities, or the
    /// exit policy, all of which come from the same binaries and the
    /// same consumer `Lint.swift` that CI consumes.
    ///
    /// ## Why parity is mechanical rather than aspirational
    ///
    /// CI installs the dispatcher and the prebuilt standard runner from
    /// the rolling `ci-binaries` release, verifies them against that
    /// release's `SHA256SUMS`, and invokes
    /// `swift-linter <package-root> --exit-policy strict` with
    /// `SWIFT_LINTER_RUNNER` pointing at the runner. This type does the
    /// same three things with the platform-matched assets from the same
    /// release. The release publishes a **composite digest** over the
    /// engine and rule-pack revisions it was built from, identical
    /// across platforms; that digest is the parity token, and
    /// ``Workspace/Lint/divergence()`` compares the installed one
    /// against the one CI consumes.
    ///
    /// ## Why a run can never report clean without measuring
    ///
    /// The engine ships rule-pack-agnostic: without a reachable
    /// configuration, zero rules fire. Three invocations of the
    /// dispatcher produce exit zero with no output whatsoever — a
    /// directory holding Swift source but no `Lint.swift`, a *file* path
    /// rather than a package root, and an empty directory. Exit status
    /// therefore attests that a process ran, never that it was
    /// configured.
    ///
    /// The first of those three is why a package with no `Lint.swift` is
    /// not sent to the dispatcher at all but to the prebuilt runner with
    /// an explicit ``Workspace/Lint/Bundle`` — see
    /// ``Workspace/Lint/measure(_:using:default:)``. The other two remain
    /// silent zeros, and remain caught below.
    ///
    /// The engine's own always-on summary line is the positive control,
    /// and it is the only one available. Every run through this type is
    /// adjudicated by ``Workspace/Lint/Summary`` and reports
    /// ``Workspace/Lint/Measurement/Verdict/unmeasured(reason:)``
    /// unless a summary line was emitted carrying a non-zero active-rule
    /// count and a non-zero linted-file count.
    public struct Lint: Sendable {
        /// The directory holding the materialized organization roots and
        /// the shared `.workspace` tooling state.
        ///
        /// Rooted at the hierarchy rather than at a Workspace checkout,
        /// because the inner-loop invocation happens inside a package —
        /// where no checkout is in scope, and requiring one would be the
        /// ceremony this mode exists to avoid.
        public let hierarchy: File.Directory

        /// Where install fetches assets from.
        ///
        /// Defaults to the release CI downloads from, and is not exposed
        /// on the command line — a developer who could repoint it could
        /// install binaries CI never gated on, which is the parity
        /// property this capability exists to hold. It is injectable so
        /// the verification gates can be driven against a tampered
        /// asset: a checksum check that has never been made to fail is
        /// an assertion, not a control.
        public let origin: Swift.String

        public init(
            hierarchy: File.Directory,
            origin: Swift.String = Workspace.Lint.downloadBase
        ) {
            self.hierarchy = hierarchy
            self.origin = origin
        }

        public init(
            root: Workspace.Root,
            origin: Swift.String = Workspace.Lint.downloadBase
        ) {
            self.hierarchy = root.hierarchy
            self.origin = origin
        }
    }
}

extension Workspace.Lint {
    /// Finds the hierarchy by walking up from `path`.
    ///
    /// The installed binaries live beside the organization roots, so a
    /// package anywhere in the tree can reach them by ascending to the
    /// first directory carrying an installed manifest. No inventory is
    /// read and no organisation is enumerated — the walk touches only
    /// the ancestry of `path`.
    ///
    /// - Throws: ``Workspace/Error`` naming the whole ascent when no
    ///   installation is found. A capability that silently fell back to
    ///   some other hierarchy would lint against binaries the caller did
    ///   not install.
    public static func resolve(from path: Swift.String) throws(Workspace.Error) -> Self {
        let validated: File.Path
        do throws(File.Path.Error) {
            validated = try File.Path(path)
        } catch {
            throw .configuration("invalid path \(path): \(error)")
        }
        let canonical: File.Path
        do throws(File.System.Canonical.Error) {
            canonical = try File.System.Canonical.resolve(validated)
        } catch {
            throw .configuration("cannot resolve \(path): \(error)")
        }

        var candidate: File.Directory? =
            File(canonical).stat.isDirectory
            ? File.Directory(canonical)
            : File.Directory(canonical).parent
        while let current = candidate {
            let lint = Self(hierarchy: current)
            if lint.manifestFile.stat.isFile {
                return lint
            }
            candidate = current.parent
        }
        throw .configuration(
            "no installed swift-linter found in \(path) or any parent directory; "
                + "run `institute lint install` from the workspace checkout"
        )
    }

    /// The installation `path` resolves to, or `nil` when the ascent
    /// reaches the filesystem root without finding one.
    ///
    /// The non-throwing half of ``resolve(from:)``, and the reason
    /// `install` and `--fix` can no longer disagree about which
    /// installation they mean. `install` used to derive its target from
    /// the *current working directory's* parent while `--fix` ascended
    /// from the linted package, so an install run from anywhere other
    /// than the linted package's own hierarchy created or refreshed a
    /// different tree and reported success. On 2026-08-03 that put four
    /// installed trees at four depths on one machine at three different
    /// digests, and a wave lane reinstalled eight times without once
    /// touching the tree its lint run was refusing on.
    ///
    /// A path that cannot be resolved is not an error here: an install
    /// into a hierarchy that has none yet is the first install, and it
    /// still has to work.
    public static func existing(from path: Swift.String) -> Self? {
        try? Self.resolve(from: path)
    }
}

extension Workspace.Lint {
    /// The repository publishing the linter binaries CI consumes.
    public static let repository = "swift-foundations/swift-linter"

    /// The rolling, non-semver release tag CI downloads from.
    ///
    /// Deliberately not a version: the release is rebuilt from `main` of
    /// the engine and its rule packs, and the *pin* is the composite
    /// digest recorded in the build manifest, not the tag. An installed
    /// tree is addressed by that digest, so a republish installs beside
    /// the previous one rather than over it.
    public static let release = "ci-binaries"

    public static let downloadBase =
        "https://github.com/\(Self.repository)/releases/download/\(Self.release)"

    /// The environment variable CI sets to provision the prebuilt
    /// standard runner, and the reason a bundle consumer lints in
    /// seconds instead of paying a per-invocation rule-pack compile.
    ///
    /// Workspace sets this itself, on the child process only. A
    /// developer's shell profile is never written: a per-developer
    /// environment variable is machine-specific by construction, and
    /// Workspace owning it is what makes the setup identical for
    /// everyone.
    static let runnerVariable = "SWIFT_LINTER_RUNNER"

    /// The exit policy CI passes. Findings of `error` severity fail the
    /// run; `warning` findings are reported and never fail it.
    ///
    /// Not configurable here. A local capability that could soften the
    /// policy would be a machine for producing local-versus-CI
    /// disagreements.
    static let exitPolicy = "strict"

    /// The environment channel carrying the exit policy to a dispatched
    /// executable.
    ///
    /// The dispatcher exports this itself from its `--exit-policy` flag,
    /// so the configured path never sets it here. The unconfigured path
    /// has no dispatcher in front of it — it spawns the prebuilt runner
    /// directly — and the runner reads only this channel, so Workspace
    /// exports it. Both land at the same terminal inside the engine,
    /// which is what keeps the two paths' exit semantics identical.
    static let policyVariable = "SWIFT_LINTER_EXIT_POLICY"
}

extension Workspace.Lint {
    /// Generated state: the installed build manifest, and nothing else.
    public var state: File.Directory {
        hierarchy[directory: ".workspace"][directory: "lint"]
    }

    /// Installed third-party tooling, shared with `institute navigation`.
    public var tools: File.Directory {
        hierarchy[directory: ".workspace"][directory: "tools"][directory: "swift-linter"]
    }

    /// The record of which build is installed — the local half of the
    /// parity comparison.
    public var manifestFile: File {
        state[file: "MANIFEST.txt"]
    }

    /// The digest-addressed install directory for `manifest`.
    ///
    /// Addressing by digest rather than by tag is what makes a republish
    /// a new install rather than an overwrite, and what lets
    /// ``diagnostics()`` state which build a stale checkout is holding.
    public func installation(
        for manifest: Manifest
    ) throws(Workspace.Error) -> File.Directory {
        let component: File.Path.Component
        do throws(File.Path.Component.Error) {
            component = try File.Path.Component(manifest.digest)
        } catch {
            throw .configuration("invalid linter digest \(manifest.digest): \(error)")
        }
        return tools[directory: component]
    }

    /// The dispatcher CLI — the executable CI invokes.
    public func executable(
        for manifest: Manifest
    ) throws(Workspace.Error) -> File {
        try installation(for: manifest)[file: "swift-linter"]
    }

    /// The prebuilt standard runner provisioned on ``runnerVariable``.
    public func runner(
        for manifest: Manifest
    ) throws(Workspace.Error) -> File {
        try installation(for: manifest)[file: "swift-linter-runner"]
    }
}

extension Workspace.Lint {
    /// The published asset names for the platform this build runs on.
    ///
    /// The Linux assets carry no suffix because CI's own container is
    /// the reference platform; every other platform's assets are
    /// suffixed. An unsupported platform fails here rather than falling
    /// back to the unsuffixed names, which would install a Linux binary
    /// on macOS and fail later with something unrecognisable.
    public enum Asset {
        #if os(macOS) && arch(arm64)
            /// The platform token this build installs for.
            public static let platform = "macos-arm64"
            static let suffix = "-macos-arm64"
        #elseif os(Linux) && arch(x86_64)
            public static let platform = "linux-x86_64"
            static let suffix = ""
        #else
            #error(
                "swift-linter publishes no asset for this platform; add it to the ci-binaries release before installing here"
            )
        #endif

        /// The dispatcher CLI asset.
        public static let executable = "swift-linter\(suffix)"

        /// The prebuilt standard runner asset.
        public static let runner = "swift-linter-runner\(suffix)"

        /// The checksum file covering both binaries and the manifest.
        public static let checksums = "SHA256SUMS\(suffix)"

        /// The build manifest, carrying the composite digest.
        ///
        /// The suffix falls before the extension, so this name cannot be
        /// derived by appending to the unsuffixed one.
        public static let manifest =
            suffix.isEmpty ? "MANIFEST.txt" : "MANIFEST\(suffix).txt"

        /// The manifest CI consumes, whatever platform this is.
        ///
        /// The parity comparison is always against the Linux build:
        /// that is the one the gating job installs.
        public static let ciManifest = "MANIFEST.txt"
    }
}

extension Workspace.Lint {
    /// Validates a runtime file name into a path component.
    ///
    /// Asset names arrive as strings because they are also URL
    /// components. Validating them here keeps a name that is not a
    /// single path component — a traversal, most of all — from reaching
    /// the filesystem.
    static func component(_ name: Swift.String) throws(Workspace.Error) -> File.Path.Component {
        do throws(File.Path.Component.Error) {
            return try File.Path.Component(name)
        } catch {
            throw .configuration("invalid asset name \(name): \(error)")
        }
    }
}
