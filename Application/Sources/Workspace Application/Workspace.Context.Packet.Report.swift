public import JSON

extension Workspace.Context.Packet {
    struct Report: Equatable, Sendable {
        let record: Workspace.Context.Packet.Record?
        let diagnostics: [Swift.String]
        let maxBytes: Swift.Int

        var status: Swift.Int32 {
            guard diagnostics.isEmpty else { return 2 }
            guard let record else { return 2 }
            guard record.diagnostics.isEmpty else { return 2 }
            return record.divergences.isEmpty ? 0 : 1
        }

        func render(_ output: Workspace.Context.Packet.Output) -> Swift.String {
            switch output {
            case .json: return boundedJSON()
            case .human: return bounded(human)
            }
        }

        private var json: JSON {
            guard let record else {
                return [
                    "schemaVersion": 1.json,
                    "status": "incomplete".json,
                    "diagnostics": diagnostics.sorted().json,
                ]
            }
            return [
                "schemaVersion": 1.json,
                "status": (status == 0 ? "complete" : status == 1 ? "divergent" : "incomplete").json,
                "issue": [
                    "identity": record.key.identity.json,
                    "title": record.title.json,
                    "state": record.state.json,
                    "type": record.type.json,
                    "stateReason": record.stateReason.json,
                    "url": record.url.json,
                    "body": record.body.json,
                    "assignees": record.assignees.sorted().json,
                    "labels": record.labels.sorted().json,
                ] as JSON,
                "relationships": [
                    "parent": record.parent.json,
                    "children": record.children.sorted().json,
                ] as JSON,
                "includedComments": record.comments.sorted { $0.url < $1.url }.map {
                    ["url": $0.url.json, "author": $0.author.json, "body": $0.body.json] as JSON
                }.json,
                "divergences": record.divergences.sorted().json,
                "checkpointDiagnostics": (diagnostics + record.diagnostics).sorted().json,
            ]
        }

        private var human: Swift.String {
            guard let record else {
                return (["context packet: incomplete"] + diagnostics.sorted().map { "  \($0)" })
                    .joined(separator: "\n") + "\n"
            }
            var lines = [
                "context packet: \(record.key.identity) — \(record.state)",
                "title: \(record.title)",
                "type: \(record.type)",
                "state reason: \(record.stateReason ?? "none")",
                "assignees: \(record.assignees.sorted().joined(separator: ", "))",
                "labels: \(record.labels.sorted().joined(separator: ", "))",
                "parent: \(record.parent ?? "none")",
                "children: \(record.children.sorted().joined(separator: ", "))",
                "included comments: \(record.comments.count)",
            ]
            lines += record.divergences.sorted().map { "divergence: \($0)" }
            lines += (diagnostics + record.diagnostics).sorted().map { "diagnostic: \($0)" }
            lines.append(
                status == 0
                    ? "context packet: complete"
                    : status == 1 ? "context packet: divergent" : "context packet: incomplete"
            )
            return lines.joined(separator: "\n") + "\n"
        }

        private func bounded(_ value: Swift.String) -> Swift.String {
            let bytes = Array(value.utf8)
            guard bytes.count > maxBytes else { return value }
            var marker = "\ncontinuation: 0 byte(s) withheld\n"
            var allowance = Swift.max(0, maxBytes - marker.utf8.count)
            while true {
                let prefix = scalarBounded(value, to: allowance)
                let next = "\ncontinuation: \(bytes.count - prefix.utf8.count) byte(s) withheld\n"
                let nextAllowance = Swift.max(0, maxBytes - next.utf8.count)
                if nextAllowance == allowance {
                    marker = next
                    return prefix + marker
                }
                allowance = nextAllowance
            }
        }

        private func scalarBounded(_ value: Swift.String, to limit: Swift.Int) -> Swift.String {
            var result = ""
            for scalar in value.unicodeScalars {
                let next = result + Swift.String(scalar)
                guard next.utf8.count <= limit else { break }
                result = next
            }
            return result
        }

        private func boundedJSON() -> Swift.String {
            let complete = json.jsonString(pretty: true, sortKeys: true) + "\n"
            guard complete.utf8.count <= maxBytes else {
                let identity = record?.key.identity ?? "unavailable"
                let compact: JSON = [
                    "schemaVersion": 1.json,
                    "status": (status == 0 ? "complete" : status == 1 ? "divergent" : "incomplete").json,
                    "issue": ["identity": identity.json] as JSON,
                    "continuation": [
                        "bytesWithheld": (complete.utf8.count - maxBytes).json,
                        "reason": "packet exceeded maxBytes; request a larger bound or explicit comment URL".json,
                    ] as JSON,
                ]
                return compact.jsonString(pretty: true, sortKeys: true) + "\n"
            }
            return complete
        }
    }
}
