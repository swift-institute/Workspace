private import File_System

extension Workspace.Conversion {
    /// `institute conversion seal`: reads the page inventory of issue #82
    /// and the materialized checkouts, and emits a receipt with the cohort
    /// and pages sealed at their pre-conversion revisions — every `post…`
    /// field `nil`, `evaluation` `nil`.
    ///
    /// `pages` and `blob` are injected with real defaults, exactly the
    /// ``Workspace/Coherence/Run`` pattern, so a test can substitute a
    /// fake page population and blob resolver without a real Git history.
    ///
    /// Only `.readme` and `.docc` pages of a `.canonical` cohort repository
    /// that the inventory records as `present` are sealed —
    /// `.organizationProfile` pages attribute to `<organization>/.github`,
    /// a coordinate no cohort repository materializes, so this instrument
    /// has nothing to digest for them and never invents one. A sealed
    /// page's `disposition` is `.unmeasured`: nothing has converted yet,
    /// and `.unmeasured` is this schema's recorded-outcome case for
    /// exactly that state, never an omission.
    public struct Seal: Sendable {
        public let root: Workspace.Root
        public let selection: Workspace.Selection.Resolved
        let pages:
            @Sendable (Workspace.Root, Workspace.Selection.Resolved) async -> Workspace.Pages.Inventory
        let head: @Sendable (Workspace.Root, Workspace.Repository) throws(Workspace.Error) -> Swift.String
        let blob:
            @Sendable (Workspace.Root, Workspace.Repository, Swift.String) throws(Workspace.Error) ->
                Swift.String

        init(
            root: Workspace.Root,
            selection: Workspace.Selection.Resolved,
            pages: @escaping @Sendable (
                Workspace.Root, Workspace.Selection.Resolved
            ) async -> Workspace.Pages.Inventory = Self.realPages,
            head: @escaping @Sendable (Workspace.Root, Workspace.Repository) throws(Workspace.Error) ->
                Swift.String = Self.realHead,
            blob: @escaping @Sendable (
                Workspace.Root, Workspace.Repository, Swift.String
            ) throws(Workspace.Error) -> Swift.String = Self.realBlob
        ) {
            self.root = root
            self.selection = selection
            self.pages = pages
            self.head = head
            self.blob = blob
        }
    }
}

extension Workspace.Conversion.Seal {
    static func realPages(
        _ root: Workspace.Root,
        _ selection: Workspace.Selection.Resolved
    ) async -> Workspace.Pages.Inventory {
        await Workspace.Pages.enumerate(root: root, selection: selection)
    }

    static func realHead(
        _ root: Workspace.Root,
        _ repository: Workspace.Repository
    ) throws(Workspace.Error) -> Swift.String {
        let location = try root.materialization(for: repository)
        let output = try Workspace.Doctor.spawn(
            "git",
            arguments: ["-C", location.description, "rev-parse", "HEAD"]
        )
        return Self.line(output)
    }

    static func realBlob(
        _ root: Workspace.Root,
        _ repository: Workspace.Repository,
        _ path: Swift.String
    ) throws(Workspace.Error) -> Swift.String {
        let location = try root.materialization(for: repository)
        let output = try Workspace.Doctor.spawn(
            "git",
            arguments: ["-C", location.description, "rev-parse", "HEAD:\(path)"]
        )
        return Self.line(output)
    }

    /// The same "first line, trimmed" reduction
    /// ``Workspace/Pages/enumerate(root:selection:git:fanout:)`` applies to
    /// a `git rev-parse` result.
    private static func line(_ value: Swift.String) -> Swift.String {
        value.split(separator: "\n").first.map(Swift.String.init) ?? value
    }
}

extension Workspace.Conversion.Seal {
    public func run() async throws(Workspace.Error) -> Workspace.Conversion.Receipt {
        let first = await pages(root, selection)
        let second = await pages(root, selection)
        guard first.canonical == second.canonical else {
            throw .configuration(
                "conversion seal: the page inventory changed while sealing; re-run once the "
                    + "checkout is stable"
            )
        }
        guard first.isFullyCanonical else {
            let counts = first.nonCanonicalCounts.sorted { $0.key < $1.key }
                .map { "\($1) \($0)" }.joined(separator: ", ")
            throw .configuration(
                "conversion seal: every cohort repository must be .canonical; found \(counts)"
            )
        }

        let byIdentity = Swift.Dictionary(
            uniqueKeysWithValues: selection.repositories.map { ("\($0.organization)/\($0.name)", $0) }
        )

        var cohort: [Workspace.Conversion.Repository] = []
        var sealedPages: [Workspace.Conversion.Page] = []

        for repositoryPages in first.repositories {
            let identity = "\(repositoryPages.organization)/\(repositoryPages.name)"
            guard let repository = byIdentity[identity] else {
                throw .configuration(
                    "conversion seal: page inventory names \(identity), which is outside the "
                        + "resolved selection"
                )
            }
            guard let coordinate = Workspace.Repository.Key(identity: identity) else {
                throw .configuration("conversion seal: \(identity) is not a valid repository coordinate")
            }

            let preConversionHead = try head(root, repository)
            cohort.append(
                .init(
                    coordinate: coordinate,
                    layer: repositoryPages.layer,
                    cloneURL: repository.url,
                    preConversionHead: preConversionHead
                )
            )

            for page in repositoryPages.pages where page.present && page.kind != .organizationProfile {
                let preConversionBlob = try blob(root, repository, page.path)
                sealedPages.append(
                    .init(
                        coordinate: coordinate,
                        kind: page.kind,
                        path: page.path,
                        preConversionBlob: preConversionBlob,
                        disposition: .unmeasured
                    )
                )
            }
        }

        let instrument = Workspace.Conversion.Instrument(
            workspaceCommit: first.instrument.workspaceCommit,
            workspaceJsonBlob: first.instrument.workspaceJsonBlob,
            selection: first.instrument.selection,
            pageInventoryDigest: first.digest
        )

        return Workspace.Conversion.Receipt(
            instrument: instrument,
            cohort: cohort,
            pages: sealedPages,
            driftChecks: []
        )
    }
}
