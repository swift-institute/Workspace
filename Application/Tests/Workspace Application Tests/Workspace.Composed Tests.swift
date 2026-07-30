import Standard_Library_Extensions
import Testing

@testable import Workspace_Application

extension Workspace.Composed {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Workspace.Composed.Test {
    static func manifest(
        reference: Swift.String,
        package: Swift.String,
        libraryProducts: [Swift.String],
        buildableTargetCount: Swift.Int = 1
    ) -> Workspace.Composed.Manifest {
        .init(
            reference: reference,
            package: package,
            libraryProducts: libraryProducts,
            buildableTargetCount: buildableTargetCount
        )
    }
}

extension Workspace.Composed.Test.Unit {
    @Test
    func `The rendered manifest declares one path dependency and one product dependency per contributing repository`() {
        let manifests = [
            Workspace.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-two",
                package: "swift-example-two",
                libraryProducts: ["Example Two"],
                buildableTargetCount: 2
            ),
            Workspace.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-one",
                package: "swift-example-one",
                libraryProducts: ["Example One", "Example One Testing"],
                buildableTargetCount: 3
            ),
        ]

        let text = Workspace.Composed.Root.render(manifests, swift: "6.3.3")

        #expect(text.hasPrefix("// swift-tools-version: 6.3.3\n"))
        #expect(text.contains(".package(path: \"../swift-primitives/swift-example-one\"),"))
        #expect(text.contains(".package(path: \"../swift-primitives/swift-example-two\"),"))
        #expect(
            text.contains(
                ".product(name: \"Example One\", package: \"swift-example-one\"),"
            )
        )
        #expect(
            text.contains(
                ".product(name: \"Example One Testing\", package: \"swift-example-one\"),"
            )
        )
        #expect(
            text.contains(
                ".product(name: \"Example Two\", package: \"swift-example-two\"),"
            )
        )

        // Sorted by reference regardless of input order, so the render is
        // deterministic run over run on the same selection.
        let oneIndex = text.range(of: "swift-example-one")!.lowerBound
        let twoIndex = text.range(of: "swift-example-two")!.lowerBound
        #expect(oneIndex < twoIndex)
    }

    @Test
    func `Rendering the same manifests twice produces byte-identical text`() {
        let manifests = [
            Workspace.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-one",
                package: "swift-example-one",
                libraryProducts: ["Example One"]
            )
        ]

        let first = Workspace.Composed.Root.render(manifests, swift: "6.3.3")
        let second = Workspace.Composed.Root.render(manifests, swift: "6.3.3")

        #expect(first == second)
    }

    @Test
    func `Expected target count sums only the repositories contributing a library product`() {
        let manifests = [
            Workspace.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-one",
                package: "swift-example-one",
                libraryProducts: ["Example One"],
                buildableTargetCount: 3
            ),
            Workspace.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-two",
                package: "swift-example-two",
                libraryProducts: ["Example Two"],
                buildableTargetCount: 2
            ),
        ]

        #expect(Workspace.Composed.Root.expectedTargetCount(in: manifests) == 5)
    }
}

extension Workspace.Composed.Test.`Edge Case` {
    @Test
    func `A repository with no library product is excluded from the composed root and its target count`() {
        let manifests = [
            Workspace.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-one",
                package: "swift-example-one",
                libraryProducts: ["Example One"],
                buildableTargetCount: 3
            ),
            // An executable-only repository: no library product, so it has
            // no way into the composed graph through a product dependency.
            Workspace.Composed.Test.manifest(
                reference: "../swift-primitives/swift-example-tool",
                package: "swift-example-tool",
                libraryProducts: [],
                buildableTargetCount: 1
            ),
        ]

        let text = Workspace.Composed.Root.render(manifests, swift: "6.3.3")

        #expect(!text.contains("swift-example-tool"))
        #expect(Workspace.Composed.Root.expectedTargetCount(in: manifests) == 3)
    }

    @Test
    func `An empty selection renders a composed root with no dependencies and an expected count of zero`() {
        let text = Workspace.Composed.Root.render([], swift: "6.3.3")

        #expect(text.contains("dependencies: [\n    ],"))
        #expect(Workspace.Composed.Root.expectedTargetCount(in: []) == 0)
    }
}
