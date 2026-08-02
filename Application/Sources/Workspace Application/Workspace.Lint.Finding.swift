public import JSON

extension Workspace.Lint {
    /// One unsuppressed finding classified by swift-linter's SARIF reporter.
    ///
    /// Workspace consumes this record; it never derives a rule identifier or
    /// severity from the human diagnostic line.
    public struct Finding: Equatable, Sendable {
        public let rule: Swift.String
        public let severity: Severity
        public let message: Swift.String
        public let path: Swift.String
        public let line: Swift.Int
        public let column: Swift.Int

        package init(
            rule: Swift.String,
            severity: Severity,
            message: Swift.String,
            path: Swift.String,
            line: Swift.Int,
            column: Swift.Int
        ) {
            self.rule = rule
            self.severity = severity
            self.message = message
            self.path = path
            self.line = line
            self.column = column
        }
    }
}

extension Workspace.Lint.Finding {
    /// Parses the existing swift-linter SARIF 2.1.0 result shape.
    package static func parse(sarif text: Swift.String) throws(Self.Error) -> [Self] {
        let document: JSON
        do throws(JSON.Error) {
            document = try JSON.parse(text)
        } catch {
            throw .malformed("swift-linter emitted malformed SARIF JSON: \(error)")
        }

        guard try Self.string(document["version"], label: "version") == "2.1.0" else {
            throw .malformed("swift-linter SARIF version is not 2.1.0")
        }
        guard let runs = document["runs"].array, runs.count == 1 else {
            throw .malformed("swift-linter SARIF must contain exactly one run")
        }
        guard let results = runs[0]["results"].array else {
            throw .malformed("swift-linter SARIF run has no results array")
        }

        var findings = [Self]()
        findings.reserveCapacity(results.count)
        for result in results {
            guard
                let locations = result["locations"].array,
                locations.count == 1
            else {
                throw .malformed(
                    "swift-linter SARIF result must contain exactly one location"
                )
            }
            let physical = locations[0]["physicalLocation"]
            let token = try Self.string(result["level"], label: "result.level")
            guard let severity = Severity(rawValue: token) else {
                throw .malformed(
                    "swift-linter SARIF result has unsupported level \(token)"
                )
            }
            findings.append(
                .init(
                    rule: try Self.string(result["ruleId"], label: "result.ruleId"),
                    severity: severity,
                    message: try Self.string(
                        result["message"]["text"],
                        label: "result.message.text"
                    ),
                    path: try Self.string(
                        physical["artifactLocation"]["uri"],
                        label: "result.location.uri"
                    ),
                    line: try Self.integer(
                        physical["region"]["startLine"],
                        label: "result.location.startLine"
                    ),
                    column: try Self.integer(
                        physical["region"]["startColumn"],
                        label: "result.location.startColumn"
                    )
                )
            )
        }
        return findings.sorted(by: Self.precedes)
    }

    /// Removes the machine-specific package prefix from one finding path.
    package func relative(to package: Swift.String) throws(Self.Error) -> Self {
        let prefix = package.hasSuffix("/") ? package : package + "/"
        let relative: Swift.String
        if path.hasPrefix(prefix) {
            relative = Swift.String(path.dropFirst(prefix.count))
        } else if path.hasPrefix("/") || path.hasPrefix("file:") {
            throw .malformed(
                "swift-linter SARIF result names a path outside its package root"
            )
        } else {
            relative = path
        }
        guard
            !relative.isEmpty,
            !relative.split(separator: "/", omittingEmptySubsequences: false)
                .contains("..")
        else {
            throw .malformed("swift-linter SARIF result has an invalid package-relative path")
        }
        return .init(
            rule: rule,
            severity: severity,
            message: message,
            path: relative,
            line: line,
            column: column
        )
    }

    static func precedes(_ lhs: Self, _ rhs: Self) -> Swift.Bool {
        if lhs.rule != rhs.rule { return lhs.rule < rhs.rule }
        if lhs.path != rhs.path { return lhs.path < rhs.path }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        if lhs.column != rhs.column { return lhs.column < rhs.column }
        if lhs.severity != rhs.severity { return lhs.severity.token < rhs.severity.token }
        return lhs.message < rhs.message
    }

    private static func string(
        _ value: JSON,
        label: Swift.String
    ) throws(Self.Error) -> Swift.String {
        do throws(JSON.Error) {
            return try Swift.String.deserialize(value)
        } catch {
            throw .malformed("swift-linter SARIF has an invalid \(label): \(error)")
        }
    }

    private static func integer(
        _ value: JSON,
        label: Swift.String
    ) throws(Self.Error) -> Swift.Int {
        do throws(JSON.Error) {
            return try Swift.Int.deserialize(value)
        } catch {
            throw .malformed("swift-linter SARIF has an invalid \(label): \(error)")
        }
    }
}
