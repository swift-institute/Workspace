extension Skill {
    /// The canonical metadata and body of an agent skill.
    public struct Document: Equatable, Sendable {
        public let name: Swift.String
        public let description: Swift.String
        public let body: Swift.String

        /// Parses the deliberately small skill-document interface.
        ///
        /// Canonical frontmatter owns only `name` and `description`. Routing,
        /// dependencies, and review history belong in the skill index, prose,
        /// or version control rather than boot metadata.
        public init(
            source: Swift.String,
            expectedName: Swift.String? = nil
        ) throws(Skill.Error) {
            let lines = source.split(
                omittingEmptySubsequences: false
            ) { character in
                character == "\n"
                    || character == "\r\n"
                    || character == "\r"
            }
            let lineCount = lines.last?.isEmpty == true
                ? lines.count - 1
                : lines.count
            guard lineCount <= Self.maximumLineCount else {
                throw .tooManyLines(
                    actual: lineCount,
                    maximum: Self.maximumLineCount
                )
            }

            guard lines.first == "---" else {
                throw .invalidFrontmatter
            }

            var fields = [Swift.String: Swift.String]()
            var index = 1
            var closingIndex: Swift.Int?
            while index < lines.count {
                let line = lines[index]
                if line == "---" {
                    closingIndex = index
                    break
                }
                guard
                    !line.isEmpty,
                    !Self.startsWithWhitespace(line),
                    let separator = line.firstIndex(of: ":")
                else {
                    throw .invalidFrontmatter
                }

                let key = Swift.String(line[..<separator])
                guard key == "name" || key == "description" else {
                    throw .invalidField(key)
                }
                guard fields[key] == nil else {
                    throw .duplicateField(key)
                }

                let remainder = line[line.index(after: separator)...]
                let value = Self.trimmingHorizontalWhitespace(remainder)
                if value == "|" {
                    index += 1
                    var continuation = [Swift.String]()
                    while index < lines.count, lines[index] != "---" {
                        let continuationLine = lines[index]
                        guard continuationLine.isEmpty || continuationLine.hasPrefix("  ") else {
                            throw .invalidFrontmatter
                        }
                        continuation.append(
                            continuationLine.isEmpty
                                ? ""
                                : Swift.String(continuationLine.dropFirst(2))
                        )
                        index += 1
                    }
                    fields[key] = continuation.joined(separator: "\n")
                    continue
                }

                guard !value.isEmpty else {
                    throw .invalidFrontmatter
                }
                fields[key] = Swift.String(value)
                index += 1
            }

            guard let closingIndex else {
                throw .invalidFrontmatter
            }
            guard let name = fields["name"] else {
                throw .missingField("name")
            }
            guard let description = fields["description"] else {
                throw .missingField("description")
            }
            guard Self.isValid(name: name) else {
                throw .invalidName(name)
            }
            if let expectedName, expectedName != name {
                throw .mismatchedName(expected: expectedName, actual: name)
            }

            let normalizedDescription = Self.trimmingWhitespace(description)
            guard !normalizedDescription.isEmpty else {
                throw .descriptionIsEmpty
            }
            guard normalizedDescription.utf8.count <= 1_024 else {
                throw .descriptionIsTooLong
            }
            guard
                !normalizedDescription.contains("<"),
                !normalizedDescription.contains(">")
            else {
                throw .descriptionContainsMarkup
            }

            let bodyStart = closingIndex + 1
            let body = bodyStart < lines.count
                ? lines[bodyStart...].map(Swift.String.init).joined(separator: "\n")
                : ""
            guard !Self.trimmingWhitespace(body).isEmpty else {
                throw .emptyBody
            }

            self.name = name
            self.description = normalizedDescription
            self.body = body
        }
    }
}

extension Skill.Document {
    private static let maximumLineCount = 500

    private static func startsWithWhitespace(_ value: Substring) -> Swift.Bool {
        guard let first = value.first else { return false }
        return first == " " || first == "\t"
    }

    private static func trimmingHorizontalWhitespace(
        _ value: Substring
    ) -> Substring {
        var start = value.startIndex
        var end = value.endIndex
        while start != end, value[start] == " " || value[start] == "\t" {
            start = value.index(after: start)
        }
        while start != end {
            let preceding = value.index(before: end)
            guard value[preceding] == " " || value[preceding] == "\t" else {
                break
            }
            end = preceding
        }
        return value[start..<end]
    }

    private static func trimmingWhitespace(
        _ value: Swift.String
    ) -> Swift.String {
        var start = value.startIndex
        var end = value.endIndex
        while start != end, isWhitespace(value[start]) {
            start = value.index(after: start)
        }
        while start != end {
            let preceding = value.index(before: end)
            guard isWhitespace(value[preceding]) else { break }
            end = preceding
        }
        return Swift.String(value[start..<end])
    }

    private static func isWhitespace(_ character: Swift.Character) -> Swift.Bool {
        character == " "
            || character == "\t"
            || character == "\n"
            || character == "\r"
    }

    private static func isValid(name: Swift.String) -> Swift.Bool {
        guard
            (1...64).contains(name.utf8.count),
            name.first != "-",
            name.last != "-"
        else {
            return false
        }
        return name.utf8.allSatisfy { byte in
            (97...122).contains(byte)
                || (48...57).contains(byte)
                || byte == 45
        }
    }
}
