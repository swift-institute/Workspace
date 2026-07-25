import GitHub
import JSON
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Workspace_Application

extension Workspace.Inventory.Test.Unit {
    @Test
    func `Merge preserves exact-key annotations and sorts layer owner name`() throws {
        let foundations = GitHub.Organization.Name("swift-foundations")
        let standards = GitHub.Organization.Name("swift-standards")
        let annotated = Workspace.Repository.Key(
            owner: foundations,
            name: .init("swift-zeta")
        )
        let existing = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [
                .init(name: annotated.name.underlying, url: annotated.url, layer: .components)
            ]
        )
        let discovery = Workspace.Inventory.Discovery(
            repositories: [
                .init(
                    id: .init(2),
                    key: annotated,
                    layer: .foundations
                ),
                .init(
                    id: .init(1),
                    key: .init(owner: standards, name: .init("swift-alpha")),
                    layer: .standards
                ),
            ],
            exclusions: []
        )

        let merged = try Workspace.Inventory.Merge()(discovery, into: existing)

        #expect(merged.repositories.map(\.name) == ["swift-alpha", "swift-zeta"])
        #expect(merged.repositories.map(\.layer) == [.standards, .components])
        #expect(merged.repositories[1].url == annotated.url)
    }
}

extension Workspace.Inventory.Test.`Edge Case` {
    @Test
    func `Duplicate existing key is rejected`() {
        let key = Workspace.Repository.Key(
            owner: .init("swift-foundations"),
            name: .init("swift-file")
        )
        let repository = Workspace.Repository(
            name: key.name.underlying,
            url: key.url,
            layer: .foundations
        )
        let existing = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [repository, repository]
        )

        #expect(throws: Workspace.Inventory.Merge.Error.self) {
            _ = try Workspace.Inventory.Merge()(
                .init(repositories: [], exclusions: []),
                into: existing
            )
        }
    }

    @Test
    func `Duplicate candidate key is rejected`() {
        let key = Workspace.Repository.Key(
            owner: .init("swift-foundations"),
            name: .init("swift-file")
        )
        let candidate = Workspace.Inventory.Repository(
            id: .init(1),
            key: key,
            layer: .foundations
        )
        let existing = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: []
        )

        #expect(throws: Workspace.Inventory.Merge.Error.self) {
            _ = try Workspace.Inventory.Merge()(
                .init(repositories: [candidate, candidate], exclusions: []),
                into: existing
            )
        }
    }

    @Test
    func `Owner change is an explicit transfer with annotation and default layers`() throws {
        let old = Workspace.Repository.Key(
            owner: .init("swift-standards"),
            name: .init("swift-moved")
        )
        let new = Workspace.Repository.Key(
            owner: .init("swift-foundations"),
            name: old.name
        )
        let existing = Workspace.Configuration(
            version: 1,
            scope: "swift-institute",
            swift: "6.3.3",
            xcode: "26.6",
            repositories: [.init(name: old.name.underlying, url: old.url, layer: .standards)]
        )
        let discovery = Workspace.Inventory.Discovery(
            repositories: [.init(id: .init(1), key: new, layer: .foundations)],
            exclusions: []
        )

        do throws(Workspace.Inventory.Merge.Error) {
            _ = try Workspace.Inventory.Merge()(discovery, into: existing)
            Issue.record("Expected transfer review failure")
        } catch {
            guard case .transfer(let name, let from, let to, let annotation, let layer) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(name == old.name)
            #expect(from == old)
            #expect(to == new)
            #expect(annotation == .standards)
            #expect(layer == .foundations)
        }
    }

    @Test
    func `Unknown annotation field is rejected instead of discarded`() {
        let json = """
            {
              "version": 1,
              "scope": "swift-institute",
              "swift": "6.3.3",
              "xcode": "26.6",
              "repositories": [
                {
                  "name": "swift-example",
                  "url": "https://github.com/swift-foundations/swift-example.git",
                  "layer": "foundations",
                  "annotation": "must-survive"
                }
              ]
            }
            """

        #expect(throws: JSON.Error.self) {
            _ = try Workspace.Configuration(jsonString: json)
        }
    }
}
