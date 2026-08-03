import Standard_Library_Extensions
import Testing

@testable import Workspace_Application

extension Workspace.Context.Packet {
    @Suite
    struct Test {}
}

extension Workspace.Context.Packet.Test {
    @Test
    func `key accepts a canonical Issue coordinate only`() {
        #expect(Workspace.Context.Packet.Key(argument: "swift-institute/Workspace#100")?.identity == "swift-institute/Workspace#100")
        #expect(Workspace.Context.Packet.Key(argument: "swift-institute/Workspace#0") == nil)
        #expect(Workspace.Context.Packet.Key(argument: "swift-institute/Workspace") == nil)
        #expect(Workspace.Context.Packet.Key(argument: "swift-institute/Workspace#one") == nil)
    }

    @Test
    func `report has deterministic bounded JSON and states its continuation`() {
        let report = Workspace.Context.Packet.Report(
            record: .init(
                key: Workspace.Context.Packet.Key(argument: "swift-institute/Workspace#100")!,
                title: "Render a packet",
                state: "open",
                type: "Task",
                stateReason: nil,
                url: "https://github.com/swift-institute/Workspace/issues/100",
                body: String(repeating: "state ", count: 300),
                assignees: ["coenttb"],
                labels: ["task"],
                parent: "swift-institute/.github#126",
                children: ["swift-institute/Workspace#101"],
                comments: [],
                divergences: [],
                diagnostics: []
            ),
            diagnostics: [],
            maxBytes: 512
        )

        let first = report.render(.json)
        let second = report.render(.json)
        #expect(first == second)
        #expect(first.utf8.count <= 512)
        #expect(first.contains("continuation"))
        #expect(report.status == 0)
    }

    @Test
    func `incomplete evidence exits two rather than looking clean`() {
        let report = Workspace.Context.Packet.Report(record: nil, diagnostics: ["GitHub unavailable"], maxBytes: 24_000)
        #expect(report.status == 2)
        #expect(report.render(.human).contains("incomplete"))
    }

    @Test
    func `human packet truncation preserves a non ASCII scalar boundary`() {
        let record = Workspace.Context.Packet.Record(
            key: Workspace.Context.Packet.Key(argument: "swift-institute/Workspace#100")!,
            title: Swift.String(repeating: "€", count: 400),
            state: "open",
            type: "Task",
            stateReason: nil,
            url: "https://github.com/swift-institute/Workspace/issues/100",
            body: "",
            assignees: [], labels: [], parent: nil, children: [], comments: [],
            divergences: [], diagnostics: []
        )

        // 512 was the originally chosen bound, but at exactly 512 bytes the
        // continuation marker's digit count happens to make the raw title
        // budget an exact multiple of "€".utf8.count (3), which defeats the
        // very property this test exists to demonstrate — see #110. 501
        // keeps the same truncation shape (still far short of the full
        // 1200-byte title) without that coincidental alignment.
        let maxBytes = 501
        let rendered = Workspace.Context.Packet.Report(record: record, diagnostics: [], maxBytes: maxBytes).render(.human)
        let marker = rendered.range(of: "\ncontinuation:")!
        let title = rendered.range(of: "title: ")!
        let rawTitleBytes = maxBytes
            - rendered[marker.lowerBound...].utf8.count
            - rendered[..<title.upperBound].utf8.count
        let renderedTitle = rendered[title.upperBound..<marker.lowerBound]

        #expect(rendered.utf8.count <= maxBytes)
        #expect(!rendered.contains("\u{FFFD}"))
        #expect(rendered.contains("continuation:"))
        #expect(rawTitleBytes % "€".utf8.count != 0)
        #expect(renderedTitle.utf8.count % "€".utf8.count == 0)
    }

    @Test
    func `measured comment mismatch exits one`() {
        let record = Workspace.Context.Packet.Record(
            key: Workspace.Context.Packet.Key(argument: "swift-institute/Workspace#100")!,
            title: "Packet",
            state: "open",
            type: "Task",
            stateReason: nil,
            url: "https://github.com/swift-institute/Workspace/issues/100",
            body: "",
            assignees: [], labels: [], parent: nil, children: [], comments: [],
            divergences: ["included comment belongs to another Issue"], diagnostics: []
        )
        #expect(Workspace.Context.Packet.Report(record: record, diagnostics: [], maxBytes: 24_000).status == 1)
    }
}
