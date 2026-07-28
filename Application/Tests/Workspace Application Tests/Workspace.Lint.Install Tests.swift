import File_System
import Foundation
import Testing

@testable import Workspace_Application

/// The install verification gates, driven end to end against a local
/// origin.
///
/// Both directions are exercised. A checksum check that has only ever
/// been observed passing is an assertion about the code, not evidence
/// about the code — the fleet has already shipped a family of gates that
/// scanned the wrong tree and reported green, and every one of them
/// passed its own fixtures.
@Suite
struct `Workspace Lint Install Tests` {
    struct Origin {
        let base: URL
        let directory: File.Directory
        let hierarchy: File.Directory
        let url: Swift.String

        init() throws {
            base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            // Canonicalized: the platform temporary directory is a
            // symlink, and the install path's containment check resolves
            // physically — a fixture rooted at the symlink would fail
            // the check for a reason that has nothing to do with what
            // these tests measure.
            let root = File.Directory(
                try File.System.Canonical.resolve(try File.Path(base.path))
            )
            directory = root[directory: "release"]
            hierarchy = root[directory: "hierarchy"]
            try directory.create.recursive()
            try hierarchy.create.recursive()
            url = "file://\(directory)"
        }

        func remove() {
            try? FileManager.default.removeItem(at: base)
        }

        /// Publishes a release whose checksum file covers every asset.
        func publish(executable: Swift.String) throws {
            let manifest = """
                digest=abc123def456
                engine=a109ffbd8242dc1d741619a6784064670efa0166
                swift-linter-rules=cc96b6b6d0074e0baa18067e662f200a85ac09d2
                """
            try write(executable, to: Workspace.Lint.Asset.executable)
            try write("runner-bytes", to: Workspace.Lint.Asset.runner)
            try write(manifest, to: Workspace.Lint.Asset.manifest)
            // The CI manifest the parity check compares against.
            try write(manifest, to: Workspace.Lint.Asset.ciManifest)

            var sums = [Swift.String]()
            for asset in [
                Workspace.Lint.Asset.executable,
                Workspace.Lint.Asset.runner,
                Workspace.Lint.Asset.manifest,
            ] {
                sums.append("\(try digest(of: asset))  \(asset)")
            }
            try write(sums.joined(separator: "\n"), to: Workspace.Lint.Asset.checksums)
        }

        /// Replaces an already-published asset without republishing its
        /// checksum — exactly the shape of a corrupted or substituted
        /// download.
        func tamper(_ asset: Swift.String, to contents: Swift.String) throws {
            try write(contents, to: asset)
        }

        func write(_ contents: Swift.String, to name: Swift.String) throws {
            try directory[file: try File.Path.Component(name)].write.atomic(contents)
        }

        func digest(of name: Swift.String) throws -> Swift.String {
            let file = directory[file: try File.Path.Component(name)]
            let output = try Workspace.Doctor.spawn("shasum", arguments: ["-a", "256", "\(file)"])
            return Swift.String(
                output.split(separator: " ", omittingEmptySubsequences: true)[0]
            )
        }
    }

    /// The positive control. Without it, a passing negative control
    /// proves only that install fails — which it would also do if the
    /// origin were unreachable for some unrelated reason.
    @Test
    func `an intact release installs and records its digest`() throws {
        let origin = try Origin()
        defer { origin.remove() }
        try origin.publish(executable: "dispatcher-bytes")

        let lint = Workspace.Lint(hierarchy: origin.hierarchy, origin: origin.url)
        try lint.install()

        #expect(try lint.installedManifest().digest == "abc123def456")
        #expect(try lint.executable(for: lint.installedManifest()).stat.isFile)
        #expect(try lint.runner(for: lint.installedManifest()).stat.isFile)
    }

    /// The negative control, driven through the real install path: a
    /// byte of the dispatcher changes after its checksum was published.
    @Test
    func `a tampered binary fails the checksum gate`() throws {
        let origin = try Origin()
        defer { origin.remove() }
        try origin.publish(executable: "dispatcher-bytes")
        try origin.tamper(Workspace.Lint.Asset.executable, to: "dispatcher-bytez")

        let lint = Workspace.Lint(hierarchy: origin.hierarchy, origin: origin.url)
        #expect(throws: Workspace.Error.self) {
            try lint.install()
        }
        // Nothing is recorded, so a later run reports "not installed"
        // rather than running against a file that failed verification.
        #expect(!lint.manifestFile.stat.isFile)
    }

    /// The manifest is verified too. A substituted manifest would
    /// misreport which build is installed, and the parity check reads
    /// exactly that file.
    @Test
    func `a tampered manifest fails the checksum gate`() throws {
        let origin = try Origin()
        defer { origin.remove() }
        try origin.publish(executable: "dispatcher-bytes")
        try origin.tamper(Workspace.Lint.Asset.manifest, to: "digest=deadbeef")

        let lint = Workspace.Lint(hierarchy: origin.hierarchy, origin: origin.url)
        #expect(throws: Workspace.Error.self) {
            try lint.install()
        }
    }

    /// An asset the checksum file does not mention is refused rather
    /// than installed unverified. Silently skipping it would make
    /// coverage depend on the publisher remembering to list everything.
    @Test
    func `an uncovered asset is refused`() throws {
        let origin = try Origin()
        defer { origin.remove() }
        try origin.publish(executable: "dispatcher-bytes")
        try origin.write(
            "\(try origin.digest(of: Workspace.Lint.Asset.manifest))  "
                + Workspace.Lint.Asset.manifest,
            to: Workspace.Lint.Asset.checksums
        )

        let lint = Workspace.Lint(hierarchy: origin.hierarchy, origin: origin.url)
        #expect(throws: Workspace.Error.self) {
            try lint.install()
        }
    }

    /// The parity gate, made to fire. The installed manifest is edited
    /// to name a build the origin does not publish.
    @Test
    func `divergence from the build CI consumes is reported`() throws {
        let origin = try Origin()
        defer { origin.remove() }
        try origin.publish(executable: "dispatcher-bytes")

        let lint = Workspace.Lint(hierarchy: origin.hierarchy, origin: origin.url)
        try lint.install()
        #expect(try lint.divergence().isEmpty)

        try lint.manifestFile.write.atomic(
            """
            digest=0000000000000000
            engine=0000000000000000000000000000000000000000
            swift-linter-rules=cc96b6b6d0074e0baa18067e662f200a85ac09d2
            """
        )
        let findings = try lint.divergence()
        #expect(!findings.isEmpty)
        #expect(findings.contains { $0.contains("abc123def456") })
        #expect(findings.contains { $0.contains("engine") })
        // The rule pack that did NOT move must not be named, or every
        // divergence report would list every input and say nothing.
        #expect(!findings.contains { $0.contains("swift-linter-rules:") })
    }

    /// The sweep's own version of the UNMEASURED rule, made to fire.
    ///
    /// This is the failure that has actually happened in this fleet: a
    /// validator invoked from the wrong root enumerated its population,
    /// found nothing, and reported green. A sweep that reaches the end
    /// having linted nothing must say so rather than report an empty
    /// ecosystem clean.
    @Test
    func `a sweep that materializes nothing is unmeasured, not clean`() async throws {
        let origin = try Origin()
        defer { origin.remove() }
        try origin.publish(executable: "dispatcher-bytes")

        let checkout = origin.hierarchy[directory: "Workspace"]
        // The async overload is selected inside an async test; the
        // capability itself only ever calls the synchronous one.
        try await checkout.create.recursive()
        let root = try Workspace.Root(checkout: checkout)
        let lint = Workspace.Lint(root: root, origin: origin.url)
        try lint.install()

        let sweep = Workspace.Lint.Sweep(
            lint: lint,
            root: root,
            repositories: [
                .init(
                    name: "swift-absent",
                    url: "https://github.com/swift-primitives/swift-absent.git",
                    organization: "swift-primitives",
                    layer: .primitives
                )
            ]
        )
        await #expect(throws: Workspace.Error.self) {
            _ = try await sweep.run()
        }
    }
}
