import File_System
import Testing

@testable import Workspace_Application

extension Workspace.Layout {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Workspace.Layout.Test.Unit {
    private static func repository(
        name: Swift.String,
        organization: Swift.String,
        layer: Workspace.Layer
    ) -> Workspace.Repository {
        .init(
            name: name,
            url: "https://github.com/\(organization)/\(name).git",
            organization: organization,
            layer: layer
        )
    }

    @Test(arguments: [
        (Workspace.Layer.primitives, "swift-primitives"),
        (.standards, "swift-standards"),
        (.foundations, "swift-foundations"),
        (.components, "swift-components"),
        (.applications, "swift-applications"),
    ])
    func `every layer roots at its organization`(
        layer: Workspace.Layer,
        organization: Swift.String
    ) {
        #expect(layer.organization == organization)
    }

    @Test
    func `a layer-root repository materializes directly under its layer root`() {
        let repository = Self.repository(
            name: "swift-dimension-primitives",
            organization: "swift-primitives",
            layer: .primitives
        )

        #expect(
            Workspace.Layout.reference(for: repository)
                == "swift-primitives/swift-dimension-primitives"
        )
    }

    @Test
    func `an authority repository nests under its layer root by organization`() {
        let repository = Self.repository(
            name: "swift-rfc-0000",
            organization: "swift-ietf",
            layer: .standards
        )

        #expect(
            Workspace.Layout.reference(for: repository)
                == "swift-standards/swift-ietf/swift-rfc-0000"
        )
    }

    @Test
    func `directory descends from the root through the layout components`() throws {
        let root = try File.Directory(validating: "/scratch")
        let repository = Self.repository(
            name: "swift-rfc-0000",
            organization: "swift-ietf",
            layer: .standards
        )

        let directory = try Workspace.Layout.directory(for: repository, at: root)
        let parent = try Workspace.Layout.parent(for: repository, at: root)

        #expect(directory.description == "/scratch/swift-standards/swift-ietf/swift-rfc-0000")
        #expect(parent.description == "/scratch/swift-standards/swift-ietf")
    }

}

extension Workspace.Layout.Test.`Edge Case` {
    @Test(arguments: ["swift/evil", ".", ".."])
    func `an invalid layout component is a configuration error, not a silent path`(
        name: Swift.String
    ) {
        let repository = Workspace.Repository(
            name: name,
            url: "https://github.com/swift-foundations/\(name).git",
            organization: "swift-foundations",
            layer: .foundations
        )

        #expect(throws: Workspace.Error.self) {
            _ = try Workspace.Layout.directory(
                for: repository,
                at: try File.Directory(validating: "/scratch")
            )
        }
    }
}
