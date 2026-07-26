extension Workspace.Doctor {
    /// The generated workspace document against the rendering
    /// `Workspace.json` requires.
    public struct Reference: Equatable, Sendable {
        public let expected: Swift.String
        public let actual: Swift.String?

        public init(expected: Swift.String, actual: Swift.String?) {
            self.expected = expected
            self.actual = actual
        }
    }
}

extension Workspace.Doctor {
    /// `institute.xcworkspace` matches `Workspace.json`.
    public static let reference = Check<Reference>(
        name: "workspace-reference",
        scope: .contributor,
        controls: .init(
            positive: .init(expected: "expected", actual: "different"),
            negative: .init(expected: "expected", actual: "expected")
        )
    ) { reference in
        guard let actual = reference.actual else {
            return [.init(severity: .error, message: "institute.xcworkspace is missing")]
        }
        guard actual != reference.expected else { return [] }
        return [
            .init(
                severity: .error,
                message: "institute.xcworkspace does not match Workspace.json"
            )
        ]
    }

    func reference() -> Outcome {
        Self.reference.run(
            population: [
                .init(
                    expected: Workspace.Xcode.render(configuration.repositories),
                    actual: Workspace.Xcode.contents(at: root)
                )
            ],
            inventory: 1
        )
    }
}
