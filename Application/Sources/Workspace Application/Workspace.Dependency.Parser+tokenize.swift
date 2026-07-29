extension Workspace.Dependency.Parser {
    func tokenize(_ bytes: [UInt8]) throws(Error) -> [Token] {
        var tokens = [Token]()
        var index = 0
        var line = 1

        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x0A {
                line += 1
                index += 1
                continue
            }
            if byte == 0x20 || byte == 0x09 || byte == 0x0D {
                index += 1
                continue
            }
            if byte == 0x2F, index + 1 < bytes.count, bytes[index + 1] == 0x2F {
                index += 2
                while index < bytes.count, bytes[index] != 0x0A { index += 1 }
                continue
            }
            if byte == 0x2F, index + 1 < bytes.count, bytes[index + 1] == 0x2A {
                let start = line
                index += 2
                var depth = 1
                while index < bytes.count, depth > 0 {
                    if bytes[index] == 0x0A {
                        line += 1
                        index += 1
                    } else if
                        bytes[index] == 0x2F,
                        index + 1 < bytes.count,
                        bytes[index + 1] == 0x2A
                    {
                        depth += 1
                        index += 2
                    } else if
                        bytes[index] == 0x2A,
                        index + 1 < bytes.count,
                        bytes[index + 1] == 0x2F
                    {
                        depth -= 1
                        index += 2
                    } else {
                        index += 1
                    }
                }
                guard depth == 0 else { throw .unterminatedBlockComment(line: start) }
                continue
            }
            if let string = try string(in: bytes, at: index, line: &line) {
                tokens.append(
                    .init(
                        kind: .string(string.value, interpolated: string.interpolated),
                        line: string.line,
                        offset: tokens.count
                    )
                )
                index = string.next
                continue
            }
            if Self.identifierHead(byte) {
                let start = index
                index += 1
                while index < bytes.count, Self.identifierBody(bytes[index]) {
                    index += 1
                }
                tokens.append(
                    .init(
                        kind: .identifier(
                            Swift.String(decoding: bytes[start..<index], as: Swift.UTF8.self)
                        ),
                        line: line,
                        offset: tokens.count
                    )
                )
                continue
            }
            if Self.punctuation.contains(byte) {
                tokens.append(
                    .init(kind: .punctuation(byte), line: line, offset: tokens.count)
                )
            }
            index += 1
        }
        return tokens
    }

    private func string(
        in bytes: [UInt8],
        at start: Swift.Int,
        line: inout Swift.Int
    ) throws(Error) -> (
        value: Swift.String,
        interpolated: Swift.Bool,
        line: Swift.Int,
        next: Swift.Int
    )? {
        var hashes = 0
        var quote = start
        while quote < bytes.count, bytes[quote] == 0x23 {
            hashes += 1
            quote += 1
        }
        guard quote < bytes.count, bytes[quote] == 0x22 else { return nil }

        let openingLine = line
        let multiline =
            quote + 2 < bytes.count
            && bytes[quote + 1] == 0x22
            && bytes[quote + 2] == 0x22
        var index = quote + (multiline ? 3 : 1)
        var content = [UInt8]()
        var interpolated = false

        while index < bytes.count {
            if closesString(
                bytes,
                at: index,
                hashes: hashes,
                quotes: multiline ? 3 : 1
            ) {
                return (
                    Swift.String(decoding: content, as: Swift.UTF8.self),
                    interpolated,
                    openingLine,
                    index + hashes + (multiline ? 3 : 1)
                )
            }

            let byte = bytes[index]
            if byte == 0x0A {
                line += 1
                guard multiline else { throw .unterminatedString(line: openingLine) }
                content.append(byte)
                index += 1
                continue
            }
            if byte == 0x5C {
                var marker = index + 1
                var matchedHashes = 0
                while marker < bytes.count, bytes[marker] == 0x23, matchedHashes < hashes {
                    marker += 1
                    matchedHashes += 1
                }
                if matchedHashes == hashes, marker < bytes.count {
                    if bytes[marker] == 0x28 {
                        interpolated = true
                        index = marker + 1
                        continue
                    }
                    if hashes == 0 {
                        switch bytes[marker] {
                        case 0x30: content.append(0)
                        case 0x6E: content.append(0x0A)
                        case 0x72: content.append(0x0D)
                        case 0x74: content.append(0x09)
                        case 0x22, 0x5C: content.append(bytes[marker])
                        default:
                            content.append(byte)
                            content.append(bytes[marker])
                        }
                        index = marker + 1
                        continue
                    }
                }
            }
            content.append(byte)
            index += 1
        }
        throw .unterminatedString(line: openingLine)
    }

    private func closesString(
        _ bytes: [UInt8],
        at index: Swift.Int,
        hashes: Swift.Int,
        quotes: Swift.Int
    ) -> Swift.Bool {
        guard index + quotes + hashes <= bytes.count else { return false }
        for offset in 0..<quotes where bytes[index + offset] != 0x22 {
            return false
        }
        for offset in 0..<hashes where bytes[index + quotes + offset] != 0x23 {
            return false
        }
        return true
    }

    private static func identifierHead(_ byte: UInt8) -> Swift.Bool {
        byte == 0x5F || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
    }

    private static func identifierBody(_ byte: UInt8) -> Swift.Bool {
        identifierHead(byte) || (0x30...0x39).contains(byte)
    }

    private static let punctuation: Set<UInt8> = [
        0x2E,  // .
        0x28,  // (
        0x29,  // )
        0x5B,  // [
        0x5D,  // ]
        0x7B,  // {
        0x7D,  // }
        0x3A,  // :
        0x2C,  // ,
    ]
}
