extension Skill {
    public enum Error: Swift.Error, Equatable, Sendable {
        case descriptionContainsMarkup
        case descriptionIsEmpty
        case descriptionIsTooLong
        case duplicateField(Swift.String)
        case emptyBody
        case invalidField(Swift.String)
        case invalidFrontmatter
        case invalidName(Swift.String)
        case mismatchedName(expected: Swift.String, actual: Swift.String)
        case missingField(Swift.String)
        case tooManyLines(actual: Swift.Int, maximum: Swift.Int)
    }
}

extension Skill.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .descriptionContainsMarkup:
            "description must not contain angle-bracket markup"
        case .descriptionIsEmpty:
            "description must not be empty"
        case .descriptionIsTooLong:
            "description must not exceed 1024 UTF-8 bytes"
        case .duplicateField(let field):
            "frontmatter field appears more than once: \(field)"
        case .emptyBody:
            "skill body must not be empty"
        case .invalidField(let field):
            "unsupported frontmatter field: \(field)"
        case .invalidFrontmatter:
            "frontmatter must be a closed YAML block containing canonical fields"
        case .invalidName(let name):
            "invalid skill name: \(name)"
        case .mismatchedName(let expected, let actual):
            "directory name \(expected) does not match skill name \(actual)"
        case .missingField(let field):
            "missing frontmatter field: \(field)"
        case .tooManyLines(let actual, let maximum):
            "skill document has \(actual) lines; maximum is \(maximum)"
        }
    }
}
