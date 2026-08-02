import Testing

@testable import Workspace_Application

extension Workspace.Context.Packet {
    @Suite
    struct Test {}
}

extension Workspace.Context.Packet.Test {
    @Test
    func `key accepts a canonical Issue coordinate only`() {
        #expect(Key(argument: "swift-institute/Workspace#100")?.identity == "swift-institute/Workspace#100")
        #expect(Key(argument: "swift-institute/Workspace#0") == nil)
        #expect(Key(argument: "swift-institute/Workspace") == nil)
        #expect(Key(argument: "swift-institute/Workspace#one") == nil)
    }

    @Test
    func `report has deterministic bounded JSON and states its continuation`() {
        let report = Report(
            record: .init(
                key: Key(argument: "swift-institute/Workspace#100")!,
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
        let report = Report(record: nil, diagnostics: ["GitHub unavailable"], maxBytes: 24_000)
        #expect(report.status == 2)
        #expect(report.render(.human).contains("incomplete"))
    }

    @Test
    func `human packet truncation preserves a non ASCII scalar boundary`() {
        let record = Record(
            key: Key(argument: "swift-institute/Workspace#100")!,
            title: Swift.String(repeating: "é", count: 400),
            state: "open",
            type: "Task",
            stateReason: nil,
            url: "https://github.com/swift-institute/Workspace/issues/100",
            body: "",
            assignees: [], labels: [], parent: nil, children: [], comments: [],
            divergences: [], diagnostics: []
        )

        let rendered = Report(record: record, diagnostics: [], maxBytes: 512).render(.human)

        #expect(rendered.utf8.count <= 512)
        #expect(!rendered.contains("\u{FFFD}"))
        #expect(rendered.contains("continuation:"))
    }

    @Test
    func `measured comment mismatch exits one`() {
        let record = Record(
            key: Key(argument: "swift-institute/Workspace#100")!,
            title: "Packet",
            state: "open",
            type: "Task",
            stateReason: nil,
            url: "https://github.com/swift-institute/Workspace/issues/100",
            body: "",
            assignees: [], labels: [], parent: nil, children: [], comments: [],
            divergences: ["included comment belongs to another Issue"], diagnostics: []
        )
        #expect(Report(record: record, diagnostics: [], maxBytes: 24_000).status == 1)
    }
}
