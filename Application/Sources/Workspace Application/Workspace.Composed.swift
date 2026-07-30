public import File_System
private import Package_Manager

extension Workspace {
    /// The pure-SwiftPM composed-root build path — Phase 2 of the
    /// ecosystem coherence instrument (``Coherence``, issue #81).
    ///
    /// ``Xcode/Build`` merges the selection into one `xcodebuild` graph,
    /// which forces macOS. Per the standing cross-platform mandate
    /// (macOS-only tooling is a blocker), this is the mandate-required
    /// end state: a synthetic root package generated from the selected
    /// manifests — its `.package(path:)` dependencies spanning every
    /// selected repository that declares a library product — built with
    /// `swift build` through ``Build/Coordinator``. No Xcode, no
    /// workspace bundle, so it runs identically on Ubuntu.
    ///
    /// This is the shape `BUILD-AND-GRAPH-FINDINGS.md`'s umbrella-root
    /// experiment documents, grown into a supported capability: generated
    /// fresh from the current selection immediately before every build
    /// (never a persisted artifact a later run could find stale), and
    /// sharing the coherence receipt's population-control contract with
    /// ``Xcode/Scheme`` — so a receipt from either build path is directly
    /// comparable.
    ///
    /// - Important: Only a *library* product can be named in another
    ///   target's `dependencies:` — SwiftPM does not allow a regular
    ///   target to depend on an executable or plugin product. A
    ///   repository whose manifest declares no library product
    ///   therefore has no way into the composed graph through this
    ///   mechanism, and its targets are excluded from
    ///   ``Composed/Root/expectedTargetCount(in:)`` accordingly — an
    ///   explicitly scoped limitation of product-dependency composition
    ///   itself, not a silently absorbed one. Every Institute package is
    ///   a library today, so this excludes nothing in practice; a future
    ///   executable-only inventory entry would be visible in the
    ///   receipt as a smaller `expectedTargetCount` than the xcodebuild
    ///   path's, not as a silent gap.
    ///
    /// - Important: Package identity for a `.package(path:)` dependency
    ///   is resolved by SwiftPM from the dependency's own materialized
    ///   directory, not declared by this generator. Every selected
    ///   repository's directory is named for its inventory `name`
    ///   (``Layout``), so this generator addresses each repository's
    ///   products as `package: repository.name` — which matches SwiftPM's
    ///   own resolution for every repository in the inventory today. A
    ///   repository whose resolved identity ever diverges from its
    ///   directory name is a real `graph`-stage resolution failure,
    ///   reported honestly through the coherence receipt rather than
    ///   guessed around; de-risking that at full-roster scale is the
    ///   open question the composed-root issue itself names.
    public enum Composed {}
}

extension Workspace.Composed {
    /// One selected repository's contribution to the composed root: its
    /// path-dependency reference and resolved identity, the library
    /// products it exposes (the only products a synthetic target may
    /// depend on), and the buildable-target count — regular and
    /// executable targets, the same filter ``Xcode/Scheme/buildables``
    /// applies, so the two build paths' target counts are computed the
    /// same way even where their reachable populations differ.
    public struct Manifest: Equatable, Sendable {
        /// The workspace-relative reference — `../<layout reference>`,
        /// the same spelling ``Xcode/Scheme`` uses. Never absolute.
        public let reference: Swift.String
        /// The path-dependency identity SwiftPM resolves for this
        /// repository — its materialized directory name.
        public let package: Swift.String
        /// Library product names only; executable and plugin products
        /// are not addressable from another target's dependencies.
        public let libraryProducts: [Swift.String]
        /// Regular and executable targets; test, plugin, binary, system,
        /// and macro targets are excluded, exactly as
        /// ``Xcode/Scheme/buildables`` excludes them.
        public let buildableTargetCount: Swift.Int

        public init(
            reference: Swift.String,
            package: Swift.String,
            libraryProducts: [Swift.String],
            buildableTargetCount: Swift.Int
        ) {
            self.reference = reference
            self.package = package
            self.libraryProducts = libraryProducts
            self.buildableTargetCount = buildableTargetCount
        }
    }
}

extension Workspace.Composed {
    /// Reads every selected repository's manifest once, in inventory
    /// order.
    ///
    /// One evaluation per repository produces both the product list and
    /// the target count together — the manifest-load cost the
    /// composed-root issue names as an open risk at full-roster scale is
    /// paid once per repository here, not once per (build path ×
    /// repository); a second, separately-shaped read of the same
    /// manifests would double it for no new information.
    ///
    /// A repository with no `Package.swift` (a specification or document
    /// repository) contributes nothing and is skipped, as
    /// ``Xcode/Scheme/buildables`` skips it for the same reason. A
    /// repository whose manifest fails to evaluate is an error, never a
    /// silent omission — skipping it would understate the composed
    /// graph while still reporting a count, exactly the failure the
    /// population control exists to catch.
    public static func manifests(
        for repositories: [Workspace.Repository],
        at root: Workspace.Root,
        packages: Package.Manager = .init()
    ) throws(Workspace.Error) -> [Manifest] {
        var manifests = [Manifest]()
        for repository in repositories {
            let directory = try Workspace.Layout.directory(for: repository, at: root.hierarchy)
            guard directory[file: "Package.swift"].stat.exists else { continue }
            let evaluation: Package.Manifest.Evaluation
            do throws(Package.Manager.Error) {
                evaluation = try packages.evaluation(at: directory.description)
            } catch {
                throw .configuration(
                    "cannot evaluate the manifest of \(repository.name) at \(directory): \(error)"
                )
            }
            let libraries: [Swift.String] = evaluation.products.compactMap { product in
                guard case .library = product.kind else { return nil }
                return product.name.underlying
            }
            var buildableCount = 0
            for target in evaluation.targets {
                switch target.kind {
                case .regular, .executable: buildableCount += 1
                case .test, .plugin, .binary, .system, .macro: continue
                }
            }
            manifests.append(
                .init(
                    reference: "../\(Workspace.Layout.reference(for: repository))",
                    package: repository.name,
                    libraryProducts: libraries,
                    buildableTargetCount: buildableCount
                )
            )
        }
        return manifests
    }
}
