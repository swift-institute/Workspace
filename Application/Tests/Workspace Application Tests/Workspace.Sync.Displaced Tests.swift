import Testing

@testable import Workspace_Application

/// Remote-identity comparison for displaced-checkout detection.
///
/// These exist because the first version of the displaced check used `==` on
/// the raw remote strings, and a live control proved it never fired: it planned
/// a duplicate clone over the very checkout it had been written to catch. The
/// displaced copy had been cloned over SSH while the inventory carried HTTPS.
@Suite
struct `Workspace Sync Displaced Tests` {

    @Test
    func `SSH and HTTPS forms of the same repository compare equal`() {
        // The exact pair that defeated the first implementation.
        #expect(
            Workspace.Sync.sameRepository(
                "git@github.com:swift-foundations/swift-json.git",
                "https://github.com/swift-foundations/swift-json.git"
            )
        )
    }

    @Test
    func `trailing .git and trailing slash do not affect identity`() {
        #expect(
            Workspace.Sync.sameRepository(
                "https://github.com/swift-foundations/swift-json",
                "https://github.com/swift-foundations/swift-json.git"
            )
        )
        #expect(
            Workspace.Sync.sameRepository(
                "https://github.com/swift-foundations/swift-json/",
                "https://github.com/swift-foundations/swift-json.git"
            )
        )
    }

    @Test
    func `ssh scheme form compares equal to scp form`() {
        #expect(
            Workspace.Sync.sameRepository(
                "ssh://git@github.com/swift-foundations/swift-json.git",
                "git@github.com:swift-foundations/swift-json.git"
            )
        )
    }

    /// The negative control. Normalization that answers "yes" too readily is
    /// worse than the `==` it replaced: this comparison gates a REFUSAL, so a
    /// false positive blocks a legitimate clone.
    @Test
    func `different repositories, owners, and hosts compare unequal`() {
        #expect(
            !Workspace.Sync.sameRepository(
                "https://github.com/swift-foundations/swift-json.git",
                "https://github.com/swift-foundations/swift-json-feed.git"
            )
        )
        #expect(
            !Workspace.Sync.sameRepository(
                "https://github.com/swift-foundations/swift-json.git",
                "https://github.com/swift-primitives/swift-json.git"
            )
        )
        #expect(
            !Workspace.Sync.sameRepository(
                "https://github.com/swift-foundations/swift-json.git",
                "https://gitlab.com/swift-foundations/swift-json.git"
            )
        )
    }

    @Test
    func `case differences in host and owner do not defeat identity`() {
        #expect(
            Workspace.Sync.sameRepository(
                "https://GitHub.com/Swift-Foundations/swift-json.git",
                "https://github.com/swift-foundations/swift-json.git"
            )
        )
    }
}
