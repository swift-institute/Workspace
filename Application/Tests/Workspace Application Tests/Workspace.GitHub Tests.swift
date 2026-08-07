import Byte_Primitives
import Command
import Testing

@testable import Workspace_Application

@Suite
struct `Workspace GitHub Tests` {

    // MARK: - Permission parsing

    @Test
    func `parses a name=level permission`() throws {
        let permission = try Workspace.GitHub.App.Permission(argument: "contents=read")
        #expect(permission.name == "contents")
        #expect(permission.level == "read")
        #expect(permission.field == "permissions[contents]=read")
    }

    @Test(arguments: [
        "contents", "contents=", "=read", "contents=read=write", "Contents=read",
        "contents=READ", "contents-x=read", "contents=read;rm -rf /", "",
    ])
    func `rejects a malformed permission`(argument: Swift.String) {
        // Rejection is what keeps unvalidated text out of both the request
        // payload and the cache file name; a permissive parser here would put
        // it in a path.
        #expect(throws: Workspace.GitHub.App.Error.self) {
            try Workspace.GitHub.App.Permission(argument: argument)
        }
    }

    // MARK: - Organization validation

    @Test(arguments: ["swift-primitives", "swift-institute", "a", "swift-ietf"])
    func `accepts a GitHub organization login`(login: Swift.String) throws {
        try Workspace.GitHub.App.validate(login)
    }

    @Test(arguments: ["", "-leading", "trailing-", "has space", "../escape", "a/b", "org?x"])
    func `rejects anything that is not a login`(login: Swift.String) {
        // This value reaches a URL path and a cache file name. Traversal and
        // separators must never survive it.
        #expect(throws: Workspace.GitHub.App.Error.self) {
            try Workspace.GitHub.App.validate(login)
        }
    }

    // MARK: - Cache keys

    @Test
    func `keys the cache by organization and permission set`() {
        let narrow = Workspace.GitHub.App.Cache.key(
            organization: "swift-primitives",
            permissions: [.init(name: "contents", level: "read")]
        )
        let wide = Workspace.GitHub.App.Cache.key(
            organization: "swift-primitives",
            permissions: []
        )
        // A narrowed token and a full-grant token are different credentials.
        // Sharing a cache entry would hand a caller that asked for read-only
        // one that can write.
        #expect(narrow != wide)
        #expect(wide == "swift-primitives.all")
        #expect(narrow == "swift-primitives.contents-read")
    }

    @Test
    func `orders the permission set so the key is stable`() {
        let one = Workspace.GitHub.App.Cache.key(
            organization: "swift-primitives",
            permissions: [
                .init(name: "metadata", level: "read"),
                .init(name: "contents", level: "read"),
            ]
        )
        let other = Workspace.GitHub.App.Cache.key(
            organization: "swift-primitives",
            permissions: [
                .init(name: "contents", level: "read"),
                .init(name: "metadata", level: "read"),
            ]
        )
        // Flag order is the caller's accident, not a different credential;
        // without the sort the same request misses its own cache entry every
        // time the flags move.
        #expect(one == other)
    }

    // MARK: - Expiry

    @Test
    func `reads GitHub's expiry as POSIX seconds`() throws {
        #expect(Workspace.GitHub.Timestamp.seconds(from: "1970-01-01T00:00:00Z") == 0)
        #expect(Workspace.GitHub.Timestamp.seconds(from: "2026-08-01T12:00:00Z") == 1_785_585_600)
        #expect(Workspace.GitHub.Timestamp.seconds(from: "2024-02-29T00:00:00Z") == 1_709_164_800)
    }

    @Test(arguments: [
        "2026-08-01T12:00:00+01:00", "2026-08-01 12:00:00Z", "2026-08-01T12:00:00",
        "2026-13-01T00:00:00Z", "2026-08-01T24:00:00Z", "", "Z",
    ])
    func `refuses a timestamp it cannot read exactly`(value: Swift.String) {
        // A tolerant parser that dropped an offset would place expiry hours
        // from the truth, and the failure surfaces as an unexplained 401
        // somewhere else entirely.
        #expect(Workspace.GitHub.Timestamp.seconds(from: value) == nil)
    }

    @Test
    func `holds a token back once it is inside the refresh margin`() {
        let token = Workspace.GitHub.App.Token(value: "irrelevant", expires: 1_000)
        #expect(token.isUsable(at: 0))
        #expect(token.isUsable(at: 699))
        #expect(!token.isUsable(at: 700))
        #expect(!token.isUsable(at: 1_001))
    }

    // MARK: - Assertion encoding

    @Test
    func `encodes the assertion's signing input as unpadded base64url`() {
        let input = Workspace.GitHub.App.Assertion.signingInput(
            header: #"{"alg":"RS256","typ":"JWT"}"#,
            claims: #"{"iat":1,"exp":2,"iss":"7"}"#
        )
        let parts = input.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count == 2)
        // Padding and the standard alphabet are both invalid in a JWT; a `=`
        // or a `+` here produces a signature GitHub rejects with no
        // explanation of which half was wrong.
        #expect(!input.contains("="))
        #expect(!input.contains("+"))
        #expect(!input.contains("/"))
        #expect(parts[0] == "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9")
    }

    // MARK: - CLI surface

    @Test
    func `accepts github token with an organization`() throws {
        var cli = Workspace.CLI(operation: .github, modes: [.token], organization: "swift-primitives")
        try cli.validate()
    }

    @Test
    func `requires an organization for github token`() {
        var cli = Workspace.CLI(operation: .github, modes: [.token])
        #expect(throws: Command.Error.self) { try cli.validate() }
    }

    @Test
    func `requires the token mode after github`() {
        var cli = Workspace.CLI(operation: .github, modes: [], organization: "swift-primitives")
        #expect(throws: Command.Error.self) { try cli.validate() }
    }

    @Test
    func `rejects credential flags outside github token`() {
        // A credential flag silently ignored mints a *wider* token than the
        // caller asked for, and nothing downstream can tell the difference.
        var narrowed = Workspace.CLI(operation: .doctor, permissions: ["contents=read"])
        #expect(throws: Command.Error.self) { try narrowed.validate() }
        var scoped = Workspace.CLI(operation: .sync, organization: "swift-primitives")
        #expect(throws: Command.Error.self) { try scoped.validate() }
    }
}
