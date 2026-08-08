private import File_System
public import Package_Manager
// `Package.Resolution`, `Package.Manifest`, and `Package.Dependency` are
// extension members declared in SPM_Standard. Under MemberImportVisibility the
// re-export via Package_Manager does not surface them for nested-type naming
// when Package_Primitives.Package is also in scope, so import it directly.
internal import SPM_Standard

extension Workspace {
    /// Local-development composition: redirecting a workspace consumer's
    /// URL-declared dependency to a **local mutable source** at its
    /// org-layout checkout (``Workspace/Layout``), and undoing it.
    ///
    /// The production backend is generated `.package(path:)` composition, chosen
    /// by ADR-001 and since *measured* against Slice 3's failure matrix: the two
    /// sharp mirror failures — a removal that does not restore, and a
    /// non-reproducible local-green/remote-impossible state — are absent by
    /// construction here. What remains, and what this type is built around, is
    /// the one hazard the path backend does introduce: a composed manifest
    /// carries a **machine-local absolute path**. That is a virtue, not a bug,
    /// as long as it stays local — off-machine it fails *loudly* at resolution
    /// rather than silently substituting a wrong source — so the path is written
    /// absolute deliberately, ``compose`` warns that the manifest must not be
    /// committed, and ``restore`` returns the declared clause byte-for-byte.
    ///
    /// Both the consumer and the dependency are workspace repositories named in
    /// `Institute.json` and checked out at their org-layout locations. Multi-root contexts,
    /// arbitrary consumers, Xcode, worktrees, and traits are out of scope per
    /// ADR-001's Limits.
    public struct Composition: Swift.Sendable {
        public let root: Workspace.Root
        public let configuration: Configuration
        public let packages: Package.Manager

        public init(
            root: Workspace.Root,
            configuration: Configuration,
            packages: Package.Manager = .init()
        ) {
            self.root = root
            self.configuration = configuration
            self.packages = packages
        }
    }
}

extension Workspace.Composition {
    /// Redirects `consumer`'s `dependency` to its local org-layout
    /// checkout by rewriting the consumer manifest's `.package(url:)` clause
    /// to a `.package(path:)` clause, recording the reversal in the ledger.
    public func compose(
        consumer: Swift.String,
        dependency: Swift.String
    ) throws(Workspace.Error) {
        guard consumer != dependency else {
            throw .composition("a package cannot compose itself")
        }
        let consumerRepository = try require(consumer)
        let dependencyRepository = try require(dependency)

        let state = try State.load(at: root.checkout)
        guard state.record(consumer: consumer, dependency: dependency) == nil else {
            throw .composition(
                "\(consumer) already composes \(dependency); restore it before composing again"
            )
        }

        let dependencyDirectory = try directory(for: dependencyRepository)
        guard File(dependencyDirectory.path).stat.isDirectory else {
            throw .composition(
                """
                \(dependency) is not checked out at \
                \(Workspace.Layout.reference(for: dependencyRepository)); \
                run `institute sync` first
                """
            )
        }

        let manifest = try manifestFile(for: consumerRepository)
        let source = try read(manifest)

        let rewrite: Package.Manifest.Redirection.Rewrite
        do throws(Package.Manifest.Redirection.Error) {
            rewrite = try Package.Manifest.Redirection.redirect(
                source,
                dependency: dependencyRepository.url,
                to: dependencyDirectory.description
            )
        } catch {
            throw .composition(
                "\(consumer) does not declare \(dependency) by URL; nothing to compose"
            )
        }
        try write(rewrite.source, to: manifest)

        let record = Record(
            consumer: consumer,
            dependency: dependency,
            declared: rewrite.declared,
            planned: rewrite.planned
        )
        try state.adding(record).save(at: root.checkout)

        report(composed: record, manifest: manifest)
    }

    /// Restores `consumer`'s manifest to its declared `.package(url:)` clause
    /// **byte-for-byte**, drops the ledger entry, and runs a resolve-free
    /// structural check on the result (see ``structuralCheck(restored:identity:consumer:dependency:)``).
    /// Never touches the dependency worktree, so a developer's unpushed local
    /// commit is preserved. The full remote-reproducibility resolve is
    /// **not** performed here — it is handed to the developer as an explicit
    /// next step through their build coordinator.
    public func restore(
        consumer: Swift.String,
        dependency: Swift.String
    ) throws(Workspace.Error) {
        let consumerRepository = try require(consumer)

        let state = try State.load(at: root.checkout)
        guard let record = state.record(consumer: consumer, dependency: dependency) else {
            throw .composition(
                "no active composition for \(consumer) → \(dependency); nothing to restore"
            )
        }

        let manifest = try manifestFile(for: consumerRepository)
        let source = try read(manifest)
        let restored: Swift.String
        do throws(Package.Manifest.Redirection.Error) {
            restored = try Package.Manifest.Redirection.restore(
                source,
                planned: record.planned,
                declared: record.declared
            )
        } catch {
            throw .composition(
                """
                the composed clause for \(dependency) is not present in \(consumer)'s manifest; \
                it may have been hand-edited or already restored — refusing to guess
                """
            )
        }
        try write(restored, to: manifest)
        try state.removing(consumer: consumer, dependency: dependency).save(at: root.checkout)

        guard let url = Package.Manifest.Clause.declaredURL(in: record.declared) else {
            throw .composition(
                "the recorded declared clause for \(dependency) is not url-form; ledger is corrupt"
            )
        }
        try structuralCheck(
            restored: restored,
            identity: Package.Manifest.Clause.identity(ofURL: url),
            consumer: consumer,
            dependency: dependency
        )

        report(restored: record, manifest: manifest)
    }

    /// Reports the **effective compiled source** of `dependency` in
    /// `consumer` — read from SwiftPM's own resolved state, never inferred
    /// from the manifest or a mirror map — and flags any disagreement with
    /// the ledger.
    public func verify(
        consumer: Swift.String,
        dependency: Swift.String
    ) throws(Workspace.Error) {
        let consumerRepository = try require(consumer)
        let dependencyRepository = try require(dependency)
        let consumerDirectory = try directory(for: consumerRepository)
        let identity = Package.Manifest.Clause.identity(ofURL: dependencyRepository.url)

        let resolution: Package.Resolution
        do throws(Package.Manager.Error) {
            resolution = try packages.resolution(at: consumerDirectory.description)
        } catch {
            throw .composition(
                """
                no resolved state for \(consumer) (\(error)); build it through the coordinator \
                first, then re-run verify
                """
            )
        }

        let match = resolution.dependencies.first { dependencyRecord in
            dependencyRecord.reference.name == dependency
                || dependencyRecord.reference.name == identity
        }
        guard let resolved = match else {
            throw .composition(
                "\(consumer)'s resolved state does not include \(dependency); has it been resolved?"
            )
        }

        let effective = packages.materialized.source(
            of: resolved,
            at: consumerDirectory.description
        )
        let ledger = try State.load(at: root.checkout)
        let composed = ledger.record(consumer: consumer, dependency: dependency) != nil

        report(
            verifying: dependency,
            in: consumer,
            composed: composed,
            state: resolved.state,
            effective: effective
        )
    }

    private func require(_ name: Swift.String) throws(Workspace.Error) -> Workspace.Repository {
        guard let repository = configuration.repositories.first(where: { $0.name == name }) else {
            throw .composition("\(name) is not a workspace repository (absent from Institute.json)")
        }
        return repository
    }

    private func directory(
        for repository: Workspace.Repository
    ) throws(Workspace.Error) -> File.Directory {
        try root.materialization(for: repository)
    }

    private func manifestFile(
        for repository: Workspace.Repository
    ) throws(Workspace.Error) -> File {
        let file = try directory(for: repository)[file: "Package.swift"]
        guard file.stat.exists else {
            throw .composition(
                """
                \(repository.name) has no Package.swift at \
                \(Workspace.Layout.reference(for: repository)); run `institute sync` first
                """
            )
        }
        return file
    }

    private func read(_ file: File) throws(Workspace.Error) -> Swift.String {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try file.read.full { span in
                var storage = [Byte]()
                storage.reserveCapacity(span.count)
                for index in span.indices {
                    storage.append(span[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            throw .composition("cannot read \(file): \(error)")
        }
    }

    private func write(_ source: Swift.String, to file: File) throws(Workspace.Error) {
        do throws(File.System.Write.Atomic.Error) {
            try file.write.atomic(source)
        } catch {
            throw .composition("cannot write \(file): \(error)")
        }
    }

    /// Evaluates the restored manifest in isolation — a fresh temporary
    /// directory with no `.build`, no ledger, and none of the consumer's warm
    /// resolution — via `dump-package`, which reads the manifest **without
    /// resolving**.
    ///
    /// This is a resolve-free *structural* check, and its scope is stated
    /// exactly so callers do not over-read it: it confirms the restored
    /// manifest evaluates, declares the dependency by URL again, and leaked
    /// no machine-local path. It is **not** a remote-reproducibility
    /// guarantee. For the path backend that is the right and sufficient
    /// residual check — the spike proved the two failures a resolve would
    /// otherwise catch (sticky removal; local-green/remote-impossible) are
    /// absent by construction — but the full resolve is not skipped, only
    /// handed to the developer as an explicit coordinator step by ``restore``.
    /// This never invokes the coordinator itself.
    private func structuralCheck(
        restored source: Swift.String,
        identity: Swift.String,
        consumer: Swift.String,
        dependency: Swift.String
    ) throws(Workspace.Error) {
        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: root.checkout.path,
                prefix: ".workspace-verify-\(consumer)-",
                suffix: ""
            )
        } catch {
            throw .composition("cannot allocate an isolated evaluation path: \(error)")
        }
        let isolated = File.Directory(path)
        try root.preflight(isolated, under: root.hierarchy)
        do throws(File.System.Create.Directory.Error) {
            try isolated.create.recursive()
        } catch {
            throw .composition("cannot create isolated evaluation directory \(isolated): \(error)")
        }
        try root.preflight(isolated, under: root.hierarchy)
        // The discard is deliberate: this is best-effort cleanup of a
        // temporary directory, and a failure to remove it must not mask
        // the structural check's own result. `do/catch` rather than `try?`
        // so the discard is local and visible per [API-ERR-001]; the error
        // type is named so the catch stays typed per [IMPL-075].
        defer {
            do throws(File.System.Delete.Error) {
                try isolated.delete.recursive()
            } catch {}
        }

        do throws(File.System.Write.Atomic.Error) {
            try isolated[file: "Package.swift"].write.atomic(source)
        } catch {
            throw .composition("structural check: cannot stage the manifest for evaluation: \(error)")
        }

        let manifest: Package.Manifest
        do throws(Package.Manager.Error) {
            manifest = try packages.manifest(at: isolated.description)
        } catch {
            throw .composition(
                "structural check: the restored \(consumer) manifest does not evaluate: \(error)"
            )
        }

        let declared = manifest.dependencies.first { $0.name.underlying == identity }
        guard let declaration = declared else {
            throw .composition(
                "structural check: restored \(consumer) manifest no longer declares \(dependency) — restoration is wrong"
            )
        }
        guard case .url = declaration.source else {
            throw .composition(
                "structural check: \(dependency) is still a local path in \(consumer) after restore — composition was not removed"
            )
        }
    }

    private func report(composed record: Record, manifest: File) {
        print("Composed \(record.consumer) → \(record.dependency) (local development source).")
        print("  manifest: \(manifest)")
        print("  now: \(record.planned)")
        print("  was: \(record.declared)")
        print("")
        print("  ⚠️  This manifest now carries a machine-local absolute path.")
        print("      Do NOT commit or push it — it resolves only on this machine.")
        print("      Run `institute restore --consumer \(record.consumer) --dependency \(record.dependency)` before pushing.")
        print("      Build through the coordinator; then `institute verify` to confirm the effective source.")
    }

    private func report(restored record: Record, manifest: File) {
        print("Restored \(record.consumer) → canonical source for \(record.dependency).")
        print("  manifest: \(manifest) (declared clause restored byte-for-byte)")
        print("  \(record.dependency)'s local checkout and any unpushed commit are untouched.")
        print("")
        print("  Structural check (resolve-free): the restored manifest evaluates, \(record.dependency)")
        print("  is declared by URL again, and no local path leaked. This does NOT resolve")
        print("  dependencies and is NOT a remote-reproducibility guarantee.")
        print("")
        print("  Next (you): run a full resolve/build through your build coordinator to confirm")
        print("  \(record.dependency) resolves from its canonical remote — the reproducibility check")
        print("  this tool does not perform. Then `institute verify` to read the effective source.")
    }

    private func report(
        verifying dependency: Swift.String,
        in consumer: Swift.String,
        composed: Swift.Bool,
        state: Package.Resolution.Dependency.State,
        effective: Swift.String
    ) {
        print("Effective source of \(dependency) in \(consumer):")
        print("  ledger: \(composed ? "composed (local development source active)" : "no active composition")")
        switch state {
        case .sourceControlCheckout(let checkout):
            print("  resolved: source-control checkout @ \(checkout.revision)")
        case .fileSystem:
            print("  resolved: local file-system source")
        case .edited:
            print("  resolved: edited working copy")
        }
        print("  compiled tree: \(effective)")
        print("  (read from the last resolve's workspace-state.json — not a fresh resolve)")

        let isLocal: Swift.Bool
        switch state {
        case .fileSystem, .edited: isLocal = true
        case .sourceControlCheckout: isLocal = false
        }
        if composed != isLocal {
            print("")
            print("  ⚠️  Ledger and resolved state disagree. The last resolve predates the")
            print("      current ledger — re-resolve through your build coordinator and verify again.")
        }
    }
}
