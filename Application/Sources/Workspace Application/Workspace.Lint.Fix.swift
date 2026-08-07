public import File_System
internal import JSON
private import Process

extension Workspace.Lint {
    /// What a `--fix` run does to the files it rewrites.
    ///
    /// Mirrors the engine's own vocabulary exactly, and carries the wire
    /// token the engine reads, because a second spelling of the same two
    /// choices is a second thing to keep in agreement.
    public enum Fix: Swift.String, Sendable, Hashable, CaseIterable {
        /// Rewrite the source files in place.
        case apply

        /// Compute the rewrites and print them as unified diffs, changing
        /// nothing on disk.
        case dryRun = "dry-run"
    }
}

extension Workspace.Lint.Fix {
    /// The engine option that excludes one canonical rule from a fix run.
    ///
    /// This belongs on the linter command line rather than in consumer
    /// configuration: exclusions change only which rewriters apply, never
    /// which rules detect and report violations.
    static let exclusionOption = "--fix-excluding"

    /// The one canonical fixer a standard-library shadow makes unsafe.
    ///
    /// Keep the engine's canonical identifier verbatim. Workspace does not
    /// validate, coalesce, or otherwise reinterpret exclusion identifiers;
    /// duplicate and unknown identifiers remain the engine's contract.
    static let shadowedStandardLibraryQualification = "PLAT-ARCH-022"

    /// The engine arguments for a per-rule fix exclusion.
    ///
    /// One option-value pair is emitted for every supplied identifier. That
    /// preserves the engine's repeated-option semantics exactly.
    ///
    /// Valid only on the dispatcher's command line, and only next to a
    /// command-line `--fix`: the engine refuses the option without one,
    /// and in command-line fix mode it ignores ``exclusionsVariable``
    /// entirely. The runner takes the channel instead — its argument
    /// vector is lint targets and nothing else, so an option there is
    /// read as a path.
    static func exclusionArguments(_ identifiers: [Swift.String]) -> [Swift.String] {
        identifiers.flatMap { [Self.exclusionOption, $0] }
    }

    /// The environment channel carrying per-rule fix exclusions to a
    /// runner-spawned fix run.
    ///
    /// The counterpart of ``exclusionArguments(_:)`` for the process
    /// whose argument vector cannot carry options. Fix mode and target
    /// roots ride environment channels on both spawn paths — the
    /// dispatcher sets ``variable`` too — so it is not the fix mode's own
    /// transport that decides whether this channel is read. The
    /// discriminator is which binary is spawned, equivalently whether a
    /// command-line `--fix` is present: the dispatcher reads exclusions
    /// only from ``exclusionArguments(_:)`` on its command line and
    /// ignores this variable, while the runner has no command line to
    /// carry them and reads only this channel.
    static let exclusionsVariable = "SWIFT_LINTER_FIX_EXCLUDING_RULES"

    /// Encodes per-rule fix exclusions for the engine's channel.
    ///
    /// A JSON array of identifiers, in caller order with duplicates
    /// intact — the same repeated-option semantics
    /// ``exclusionArguments(_:)`` preserves, on the transport the
    /// runner's environment protocol reads.
    static func exclusions(_ identifiers: [Swift.String]) -> Swift.String {
        JSON.array(identifiers.map { .string($0) }).jsonString()
    }

    /// The environment channel the engine reads the mode from.
    ///
    /// Duplicated here rather than imported: Workspace depends on the
    /// linter's *binaries*, never on its library, which is the whole point
    /// of the installation boundary. The channel name is part of the
    /// binaries' command-line contract, and ``Workspace/Lint/supportsFix(_:)``
    /// is what keeps this side from talking to a build that does not
    /// understand it.
    static let variable = "SWIFT_LINTER_FIX"

    /// The environment channel carrying exact SwiftPM target roots to a
    /// fix-capable linter process.
    ///
    /// The linter keeps detection rooted at the package so configuration,
    /// manifests, scripts, and fixtures remain observable. Application is a
    /// separate concern: it receives only this manifest-derived vector and
    /// must not infer membership from directory spelling.
    static let targetsVariable = "SWIFT_LINTER_FIX_TARGETS"

    /// Encodes declared target roots for the linter's fix channel.
    ///
    /// JSON preserves paths containing spaces and makes the boundary's
    /// ordered-vector semantics explicit. The string is part of the binary
    /// contract; Workspace intentionally does not depend on the linter
    /// library just to share this transport type.
    static func targets(_ roots: [File.Directory]) -> Swift.String {
        JSON.array(roots.map { .string($0.description) }).jsonString()
    }
}

extension Workspace.Lint {
    /// Whether the installed binaries understand `--fix`.
    ///
    /// Asked before every fix run, and the reason this capability is safe to
    /// ship ahead of the `ci-binaries` release that carries it. The mode
    /// rides an environment channel, and an older engine does not read that
    /// channel at all: it would lint, report findings, exit zero, and change
    /// nothing — while the caller believed it had applied fixes and was
    /// looking at a report of what remained. A silent no-op that looks like
    /// a successful run is exactly the failure this whole capability's
    /// measurement discipline exists to prevent, so it is refused up front
    /// instead.
    ///
    /// The probe is the dispatcher's own `--help`, which is free, offline,
    /// and cannot be wrong about its own option vocabulary.
    public static func supportsFix(_ installation: Installation) -> Swift.Bool {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: installation.executable.description,
                    arguments: ["--help"],
                    stdout: .pipe,
                    stderr: .pipe
                )
            )
        } catch {
            return false
        }
        let text =
            Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
            + Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
        return text.contains("--fix")
    }
}

extension Workspace.Lint {
    /// What to say when a fix is asked of binaries that cannot perform one.
    ///
    /// Names the remedy rather than the mechanism: the installed build
    /// predates `--fix`, and the fix is to install a newer one, not to
    /// understand environment channels.
    static let fixUnsupported =
        "the installed swift-linter predates --fix and would silently lint instead of "
        + "fixing; run `institute lint install` once the ci-binaries release carries it"
}
