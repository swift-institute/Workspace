private import Environment
public import File_System
private import Skill_Validation

extension Workspace {
    /// Installs and verifies the checkout-root agent context.
    public struct Context: Sendable {
        public let root: Workspace.Root
        public let entry: File.Directory
        public let home: File.Directory

        /// Creates context management for the entry root containing Swift Institute.
        ///
        /// Skill projections are installed under the invoking account's home
        /// directory, read from `HOME` at install time. That destination is what
        /// makes a projection reachable from every checkout root a session may
        /// start in; a per-checkout destination is reachable only from the one
        /// root that contains it.
        ///
        /// - Parameter root: The Workspace checkout whose parent hierarchy belongs
        ///   to Swift Institute.
        /// - Throws: ``Workspace/Error`` when the checkout has no containing entry
        ///   root, or when `HOME` is unset or is not a usable path.
        public init(root: Workspace.Root) throws(Workspace.Error) {
            guard let value = Environment.read("HOME"), !value.isEmpty else {
                throw .configuration(
                    "HOME is not available, so the account-wide skill destination cannot be resolved"
                )
            }
            let home: File.Directory
            do throws(Paths.Path.Error) {
                home = try File.Directory(validating: value)
            } catch {
                throw .configuration("HOME is not a usable path \(value): \(error)")
            }
            try self.init(root: root, home: home)
        }

        /// Creates context management against an explicit account root.
        ///
        /// - Parameters:
        ///   - root: The Workspace checkout whose parent hierarchy belongs to Swift Institute.
        ///   - home: The account root owning `.claude/skills` and `.agents/skills`.
        /// - Throws: ``Workspace/Error`` when the checkout has no containing entry root.
        internal init(root: Workspace.Root, home: File.Directory) throws(Workspace.Error) {
            guard let entry = root.hierarchy.parent else {
                throw .configuration(
                    "the Swift Institute hierarchy has no containing context root"
                )
            }
            self.root = root
            self.entry = entry
            self.home = home
        }
    }
}

extension Workspace.Context {
    /// Installs generated documents and account-wide skill projections.
    ///
    /// Existing unmanaged files, directories, and symbolic links are rejected
    /// before any mutation. Generated documents may be refreshed in place.
    @discardableResult
    public func install() throws(Workspace.Error) -> Projection {
        let documents = try documents()
        let resolved = try resolvedSources()
        guard !resolved.isEmpty else {
            throw .configuration(
                """
                no canonical skill root resolved, so there is nothing to install. \
                Looked for:
                \(sources.map { "  \($0)" }.joined(separator: "\n"))
                Clone the public https://github.com/swift-institute/Skills into \
                \(entry[directory: "swift-institute"][directory: "Skills"]) and run this again.
                """
            )
        }
        let links = try links()
        let retiredLinks = try retiredManagedLinks(expecting: links)
        let replacedDocuments = try managedDocumentsReplacedByLinks(links)
        let conflicts = try conflicts(documents: documents, links: links)
        guard conflicts.isEmpty else {
            throw .filesystem(conflicts.joined(separator: "\n"))
        }

        for directory in directories {
            do throws(File.System.Create.Directory.Error) {
                try directory.create.recursive()
            } catch {
                throw .filesystem("cannot create \(directory): \(error)")
            }
        }
        for document in documents {
            let expected = try read(document.source)
            if try contents(of: document.target) != expected {
                do throws(File.System.Write.Atomic.Error) {
                    try document.target.write.atomic(expected)
                } catch {
                    throw .filesystem("cannot write \(document.target): \(error)")
                }
            }
            do throws(File.System.Metadata.Permissions.Error) {
                try File.System.Metadata.Permissions.set(
                    .defaultFile,
                    at: document.target.path
                )
            } catch {
                throw .filesystem(
                    "cannot set generated document permissions for \(document.target): \(error)"
                )
            }
        }
        for path in retiredLinks {
            do throws(File.System.Delete.Error) {
                try File(path).delete()
            } catch {
                throw .filesystem("cannot remove retired context link \(path): \(error)")
            }
        }
        for path in replacedDocuments {
            do throws(File.System.Delete.Error) {
                try File(path).delete()
            } catch {
                throw .filesystem("cannot replace generated context document \(path): \(error)")
            }
        }
        for link in links where try metadata(at: link.path) == nil {
            do throws(File.System.Link.Symbolic.Error) {
                try File.System.Link.Symbolic.create(
                    at: link.path,
                    pointingTo: link.target
                )
            } catch {
                throw .filesystem("cannot create symbolic link \(link.path): \(error)")
            }
        }

        let diagnostics = try diagnostics(
            documents: documents,
            links: links
        )
        guard diagnostics.isEmpty else {
            throw .filesystem(diagnostics.joined(separator: "\n"))
        }

        return .init(
            sources: resolved,
            skills: try projected().keys.sorted()
        )
    }

    /// Reports every missing or divergent generated document and skill projection.
    ///
    /// - Returns: An empty array when the installed context matches its canonical
    ///   templates and skill sources.
    /// - Throws: ``Workspace/Error`` when canonical context state cannot be read.
    public func diagnostics() throws(Workspace.Error) -> [Swift.String] {
        var findings = try diagnostics(documents: documents(), links: links())
        // A hierarchy carrying no skill root projects nothing, and an empty
        // set of projections is otherwise indistinguishable from a complete
        // one — the shape of the defect at issue #58.
        if try resolvedSources().isEmpty {
            findings.insert(
                "no canonical skill root resolved, so no skill is projected; looked for:\n"
                    + sources.map { "  \($0)" }.joined(separator: "\n"),
                at: 0
            )
        }
        return findings
    }
}

extension Workspace.Context {
    private static let marker =
        "<!-- Generated by `institute context install`; edit the canonical template in Workspace/Context. -->"

    private var templates: File.Directory {
        root.checkout[directory: "Context"]
    }

    /// The account-wide agent configuration root.
    ///
    /// Deliberately not `entry[directory: ".claude"]`. A projection under a
    /// checkout root loads only for a session that starts inside that root, and
    /// the Institute hierarchy has several roots a session legitimately starts
    /// in. This one is reachable from all of them.
    private var claude: File.Directory {
        home[directory: ".claude"]
    }

    private var agents: File.Directory {
        home[directory: ".agents"]
    }

    /// The checkout-local Codex projection installed before account-wide
    /// discovery was supported. It is retained only as a migration source.
    private var legacyAgents: File.Directory {
        entry[directory: ".agents"]
    }

    private var skills: File.Directory {
        claude[directory: "skills"]
    }

    private var directories: [File.Directory] {
        [claude, skills, agents]
    }

    private func documents() throws(Workspace.Error) -> [Document] {
        [
            .init(
                source: templates[file: "AGENTS.md"],
                target: entry[file: "AGENTS.md"],
                marker: Self.marker
            ),
        ]
    }

    private func links() throws(Workspace.Error) -> [Link] {
        [
            .init(path: agents.path / "skills", target: skills.path),
            .init(
                path: entry[file: "CLAUDE.md"].path,
                target: relativeAgentDocumentPath
            ),
        ] + (try projections())
    }

    /// The generated Claude entry point follows the platform-neutral document
    /// by a relative link so the hierarchy remains movable between machines.
    private var relativeAgentDocumentPath: File.Path {
        File.Path("AGENTS.md")
    }

    /// Every canonical skill root that is actually present.
    ///
    /// Reported rather than merely counted: a run that resolved two roots
    /// and a run that resolved all four both "succeed", and only naming
    /// them tells the difference.
    private func resolvedSources() throws(Workspace.Error) -> [File.Directory] {
        var present = [File.Directory]()
        for source in sources {
            guard let info = try metadata(at: source.path) else { continue }
            guard info.type == .directory else {
                throw .configuration(
                    "canonical skill source is not a directory: \(source)"
                )
            }
            present.append(source)
        }
        return present
    }

    private func projections() throws(Workspace.Error) -> [Link] {
        let projected = try projected()
        return projected.keys.sorted().compactMap { projected[$0] }
    }

    /// Every skill this hierarchy projects, keyed by skill name.
    private func projected() throws(Workspace.Error) -> [Swift.String: Link] {
        var projected = [Swift.String: Link]()
        for source in sources {
            // A source root is optional because the hierarchy is. The public
            // Skills repository is what every contributor clones; the remaining
            // roots are separate repositories only some accounts carry.
            // Requiring all four made the whole installation fail for anyone
            // holding fewer, which is every contributor.
            guard let info = try metadata(at: source.path) else { continue }
            guard info.type == .directory else {
                throw .configuration(
                    "canonical skill source is not a directory: \(source)"
                )
            }

            let entries: [File.Directory.Entry]
            do throws(File.Directory.Contents.Error) {
                entries = try File.Directory.Contents.list(at: source)
            } catch {
                throw .filesystem("cannot enumerate \(source): \(error)")
            }

            for entry in entries where entry.type == .directory {
                guard let name = Swift.String(entry.name), let path = entry.pathIfValid else {
                    throw .configuration(
                        "canonical skill source contains an undecodable entry: \(entry.name)"
                    )
                }
                let directory = File.Directory(path)
                let document = directory[file: "SKILL.md"]
                guard document.stat.exists else { continue }
                let documentSource = try read(document)

                do throws(Skill.Error) {
                    _ = try Skill.Document(
                        source: documentSource,
                        expectedName: name
                    )
                } catch {
                    throw .configuration(
                        "invalid canonical skill \(name): \(error)"
                    )
                }

                let component: File.Path.Component
                do throws(File.Path.Component.Error) {
                    component = try entry.name.asPathComponent()
                } catch {
                    throw .configuration("invalid skill name \(name): \(error)")
                }
                // The projection is absolute because its directory no longer sits
                // in the hierarchy it points into. A relative target would have to
                // encode how deep the checkout sits below the account root, which
                // differs per machine and is not expressible when the checkout is
                // not below it at all. `path` is already physical: the checkout it
                // descends from was canonically resolved by `Workspace.Root`.
                let link = Link(path: skills.path / component, target: path)
                if let existing = projected.updateValue(link, forKey: name) {
                    throw .configuration(
                        "duplicate canonical skill \(name): \(existing.target) and \(path)"
                    )
                }
            }
        }

        return projected
    }

    /// Every canonical skill root this hierarchy may carry, present or not.
    ///
    /// The list is complete rather than filtered so that a projection whose
    /// source repository has since gone away is still recognized as this
    /// installer's own and retired, instead of lingering as an unowned link.
    private var sources: [File.Directory] {
        [
            entry[directory: "swift-institute"][directory: "Skills"],
            entry[directory: "swift-institute"][directory: "Internal"][directory: "Skills"],
            entry[directory: "swift-institute"][directory: "Engagement"][directory: "Skills"],
            entry[directory: "rule-institute"][directory: "Skills"],
        ]
    }

    private func retiredManagedLinks(
        expecting links: [Link]
    ) throws(Workspace.Error) -> [File.Path] {
        var retired = try staleManagedSkillLinks(expecting: links)
        let legacy = legacyAgents.path / "skills"
        if
            let info = try metadata(at: legacy),
            info.type == .symbolicLink,
            try target(of: legacy) == skills.path
        {
            retired.append(legacy)
        }
        return retired.sorted { "\($0)" < "\($1)" }
    }

    private func staleManagedSkillLinks(
        expecting links: [Link]
    ) throws(Workspace.Error) -> [File.Path] {
        guard
            let info = try metadata(at: skills.path),
            info.type == .directory
        else {
            return []
        }

        let entries: [File.Directory.Entry]
        do throws(File.Directory.Contents.Error) {
            entries = try File.Directory.Contents.list(at: skills)
        } catch {
            throw .filesystem("cannot enumerate installed skill projections: \(error)")
        }

        let expected = Set(links.map(\.path))
        let prefixes = sources.map { "\($0.path)/" }
        var stale = [File.Path]()
        for entry in entries where entry.type == .symbolicLink {
            guard let path = entry.pathIfValid, !expected.contains(path) else {
                continue
            }
            guard let name = Swift.String(entry.name) else {
                continue
            }
            let installedTarget = try target(of: path)
            guard prefixes.contains(where: { "\(installedTarget)" == "\($0)\(name)" }) else {
                continue
            }
            stale.append(path)
        }
        return stale
    }

    /// A generated regular `CLAUDE.md` from the previous installer is safe to
    /// replace with the link that now owns the same entry point.
    private func managedDocumentsReplacedByLinks(
        _ links: [Link]
    ) throws(Workspace.Error) -> [File.Path] {
        var paths = [File.Path]()
        for link in links where link.path == entry[file: "CLAUDE.md"].path {
            guard
                let info = try metadata(at: link.path),
                info.type == .regular
            else {
                continue
            }
            let document = try read(File(link.path))
            if document.hasPrefix(Self.marker) {
                paths.append(link.path)
            }
        }
        return paths
    }
}

extension Workspace.Context {
    private func conflicts(
        documents: [Document],
        links: [Link]
    ) throws(Workspace.Error) -> [Swift.String] {
        var findings = [Swift.String]()
        for directory in directories {
            guard let info = try metadata(at: directory.path) else { continue }
            guard info.type == .directory else {
                findings.append(
                    "refusing to replace non-directory context path: \(directory)"
                )
                continue
            }
        }
        for document in documents {
            guard let info = try metadata(at: document.target.path) else { continue }
            guard info.type == .regular else {
                findings.append(
                    "refusing to replace non-file context document: \(document.target)"
                )
                continue
            }
            let actual = try read(document.target)
            let expected = try read(document.source)
            guard actual != expected else { continue }
            guard let marker = document.marker, actual.hasPrefix(marker) else {
                findings.append(
                    "refusing to replace unmanaged context document: \(document.target)"
                )
                continue
            }
        }
        for link in links {
            guard let info = try metadata(at: link.path) else { continue }
            if
                link.path == entry[file: "CLAUDE.md"].path,
                info.type == .regular,
                try read(File(link.path)).hasPrefix(Self.marker)
            {
                continue
            }
            guard info.type == .symbolicLink else {
                findings.append(
                    "refusing to replace non-link context path: \(link.path)"
                )
                continue
            }
            guard try target(of: link.path) == link.target else {
                findings.append(
                    "refusing to replace divergent context link: \(link.path)"
                )
                continue
            }
        }
        let legacy = legacyAgents.path / "skills"
        if let info = try metadata(at: legacy) {
            guard info.type == .symbolicLink else {
                findings.append(
                    "refusing to replace non-link retired context path: \(legacy)"
                )
                return findings
            }
            guard try target(of: legacy) == skills.path else {
                findings.append(
                    "refusing to replace divergent retired context link: \(legacy)"
                )
                return findings
            }
        }
        return findings
    }

    private func diagnostics(
        documents: [Document],
        links: [Link]
    ) throws(Workspace.Error) -> [Swift.String] {
        var findings = [Swift.String]()
        for path in try retiredManagedLinks(expecting: links) {
            findings.append("retired context link remains installed: \(path)")
        }
        let legacy = legacyAgents.path / "skills"
        if let info = try metadata(at: legacy) {
            if info.type != .symbolicLink {
                findings.append("retired context path is not a symbolic link: \(legacy)")
            } else if try target(of: legacy) != skills.path {
                findings.append("retired context link has the wrong target: \(legacy)")
            }
        }
        for directory in directories {
            guard let info = try metadata(at: directory.path) else {
                findings.append("missing context directory: \(directory)")
                continue
            }
            guard info.type == .directory else {
                findings.append("context path is not a directory: \(directory)")
                continue
            }
        }
        for document in documents {
            guard let info = try metadata(at: document.target.path) else {
                findings.append("missing context document: \(document.target)")
                continue
            }
            guard info.type == .regular else {
                findings.append("context document is not a regular file: \(document.target)")
                continue
            }
            guard try read(document.target) == read(document.source) else {
                findings.append("context document differs from its template: \(document.target)")
                continue
            }
        }
        for link in links {
            guard let info = try metadata(at: link.path) else {
                findings.append("missing context link: \(link.path)")
                continue
            }
            guard info.type == .symbolicLink else {
                findings.append("context link is not a symbolic link: \(link.path)")
                continue
            }
            guard try target(of: link.path) == link.target else {
                findings.append("context link has the wrong target: \(link.path)")
                continue
            }
        }
        return findings
    }
}

extension Workspace.Context {
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

    private func contents(of file: File) throws(Workspace.Error) -> Swift.String? {
        guard let info = try metadata(at: file.path), info.type == .regular else {
            return nil
        }
        return try read(file)
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
