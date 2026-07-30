public import RFC_4648

extension Workspace.Dependency {
    /// A comment- and string-aware parser for manifest package declarations.
    public struct Parser: Sendable {
        public init() {}
    }
}

extension Workspace.Dependency.Parser {
    public func parse(_ bytes: [Byte]) throws(Error) -> [Workspace.Dependency.Declaration] {
        // swift-linter:disable:next raw value access
        // REASON: stdlib UTF-8 lexer boundary; Parser's public byte-domain input remains Byte
        let source = bytes.map(\.underlying)
        guard Swift.String(validating: source, as: Swift.UTF8.self) != nil else {
            throw .invalidUTF8
        }
        let tokens = try tokenize(source)
        var declarations = [Workspace.Dependency.Declaration]()
        var index = 0

        while index + 2 < tokens.count {
            guard
                tokens[index].kind == .punctuation(0x2E),
                tokens[index + 1].kind == .identifier("package"),
                tokens[index + 2].kind == .punctuation(0x28)
            else {
                index += 1
                continue
            }

            let parsed = declaration(in: tokens, openingAt: index + 2)
            declarations.append(parsed.declaration)
            index = parsed.next
        }
        return declarations
    }

    private func declaration(
        in tokens: [Token],
        openingAt opening: Swift.Int
    ) -> (declaration: Workspace.Dependency.Declaration, next: Swift.Int) {
        let line = tokens[opening].line
        var depth = 1
        var index = opening + 1
        var url: (Token, Swift.Int)?
        var path: (Token, Swift.Int)?
        var registry: (Token, Swift.Int)?

        while index < tokens.count {
            switch tokens[index].kind {
            case .punctuation(0x28), .punctuation(0x5B), .punctuation(0x7B):
                depth += 1
            case .punctuation(0x29), .punctuation(0x5D), .punctuation(0x7D):
                depth -= 1
                if depth == 0 {
                    if let url {
                        return (
                            argument(url.0, end: url.1, kind: .url, line: line),
                            index + 1
                        )
                    }
                    if let path {
                        return (
                            argument(path.0, end: path.1, kind: .path, line: line),
                            index + 1
                        )
                    }
                    if let registry {
                        return (
                            argument(registry.0, end: registry.1, kind: .registry, line: line),
                            index + 1
                        )
                    }
                    return (
                        .malformed(
                            "package declaration has no url, path, or id argument",
                            line: line
                        ),
                        index + 1
                    )
                }
            case .identifier(let label) where depth == 1:
                guard
                    index + 1 < tokens.count,
                    tokens[index + 1].kind == .punctuation(0x3A)
                else {
                    index += 1
                    continue
                }
                let value = index + 2
                let end = argumentEnd(in: tokens, from: value)
                switch label {
                case "url": url = (tokens[safe: value] ?? tokens[index], end)
                case "path": path = (tokens[safe: value] ?? tokens[index], end)
                case "id": registry = (tokens[safe: value] ?? tokens[index], end)
                default: break
                }
            default:
                break
            }
            index += 1
        }

        return (
            .malformed("package declaration has no closing parenthesis", line: line),
            tokens.count
        )
    }

    private func argument(
        _ token: Token,
        end: Swift.Int,
        kind: Argument,
        line: Swift.Int
    ) -> Workspace.Dependency.Declaration {
        guard case .string(let value, let interpolated) = token.kind, !interpolated else {
            return .malformed("package \(kind.label) is not a static string literal", line: line)
        }
        guard token.offset + 1 == end else {
            return .malformed("package \(kind.label) is not a single string literal", line: line)
        }
        switch kind {
        case .url: return .url(value, line: line)
        case .path: return .path(value, line: line)
        case .registry: return .registry(value, line: line)
        }
    }

    private func argumentEnd(in tokens: [Token], from start: Swift.Int) -> Swift.Int {
        var depth = 1
        var index = start
        while index < tokens.count {
            switch tokens[index].kind {
            case .punctuation(0x28), .punctuation(0x5B), .punctuation(0x7B):
                depth += 1
            case .punctuation(0x29), .punctuation(0x5D), .punctuation(0x7D):
                depth -= 1
                if depth == 0 { return index }
            case .punctuation(0x2C) where depth == 1:
                return index
            default:
                break
            }
            index += 1
        }
        return index
    }
}

extension Workspace.Dependency.Parser.Argument {
    fileprivate var label: Swift.String {
        switch self {
        case .url: "url"
        case .path: "path"
        case .registry: "id"
        }
    }
}

extension Array {
    fileprivate subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
