import Testing

@testable import Skill_Validation

@Suite
struct `Skill Document Tests` {
    @Test
    func `parses canonical scalar metadata`() throws {
        let document = try Skill.Document(
            source: """
                ---
                name: example-skill
                description: Apply when validating an example.
                ---

                # Example
                """,
            expectedName: "example-skill"
        )

        #expect(document.name == "example-skill")
        #expect(document.description == "Apply when validating an example.")
        #expect(document.body.contains("# Example"))
    }

    @Test
    func `parses canonical block description`() throws {
        let document = try Skill.Document(
            source: """
                ---
                name: example-skill
                description: |
                  First line.
                  Apply when the second line is relevant.
                ---

                # Example
                """
        )

        #expect(
            document.description
                == "First line.\nApply when the second line is relevant."
        )
    }

    @Test
    func `rejects routing metadata`() {
        #expect(throws: Skill.Error.invalidField("requires")) {
            _ = try Skill.Document(
                source: """
                    ---
                    name: example-skill
                    description: Example.
                    requires: another-skill
                    ---
                    # Example
                    """
            )
        }
    }

    @Test
    func `rejects a directory name mismatch`() {
        #expect(
            throws: Skill.Error.mismatchedName(
                expected: "expected-skill",
                actual: "example-skill"
            )
        ) {
            _ = try Skill.Document(
                source: """
                    ---
                    name: example-skill
                    description: Example.
                    ---
                    # Example
                    """,
                expectedName: "expected-skill"
            )
        }
    }

    @Test
    func `rejects duplicate metadata`() {
        #expect(throws: Skill.Error.duplicateField("description")) {
            _ = try Skill.Document(
                source: """
                    ---
                    name: example-skill
                    description: First.
                    description: Second.
                    ---
                    # Example
                    """
            )
        }
    }

    @Test
    func `rejects missing canonical metadata`() {
        #expect(throws: Skill.Error.missingField("description")) {
            _ = try Skill.Document(
                source: """
                    ---
                    name: example-skill
                    ---
                    # Example
                    """
            )
        }
    }

    @Test
    func `rejects invalid names`() {
        #expect(throws: Skill.Error.invalidName("Example_Skill")) {
            _ = try Skill.Document(
                source: """
                    ---
                    name: Example_Skill
                    description: Example.
                    ---
                    # Example
                    """
            )
        }
    }

    @Test
    func `rejects markup in the boot description`() {
        #expect(throws: Skill.Error.descriptionContainsMarkup) {
            _ = try Skill.Document(
                source: """
                    ---
                    name: example-skill
                    description: Use <example> markup.
                    ---
                    # Example
                    """
            )
        }
    }

    @Test
    func `rejects an empty body`() {
        #expect(throws: Skill.Error.emptyBody) {
            _ = try Skill.Document(
                source: """
                    ---
                    name: example-skill
                    description: Example.
                    ---

                    """
            )
        }
    }

    @Test
    func `rejects descriptions over the byte limit`() {
        let description = Swift.String(repeating: "x", count: 1_025)
        #expect(throws: Skill.Error.descriptionIsTooLong) {
            _ = try Skill.Document(
                source: """
                    ---
                    name: example-skill
                    description: \(description)
                    ---
                    # Example
                    """
            )
        }
    }

    @Test
    func `normalizes CRLF line endings`() throws {
        let document = try Skill.Document(
            source: "---\r\nname: example-skill\r\ndescription: Example.\r\n---\r\n# Example\r\n"
        )

        #expect(document.body == "# Example\n")
    }

    @Test
    func `rejects a context-heavy skill hub`() {
        let source = (
            [
                "---",
                "name: example-skill",
                "description: Example.",
                "---",
            ] + Array(repeating: "# Detailed rule", count: 497)
        ).joined(separator: "\n") + "\n"

        #expect(
            throws: Skill.Error.tooManyLines(actual: 501, maximum: 500)
        ) {
            _ = try Skill.Document(source: source)
        }
    }
}
