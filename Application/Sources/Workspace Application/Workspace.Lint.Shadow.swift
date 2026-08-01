extension Workspace.Lint {
    /// A Swift standard-library name a package can shadow, and the reason
    /// `--fix` has to know which packages do.
    ///
    /// PLAT-ARCH-022 qualifies bare standard-library names — `Error`
    /// becomes `Swift.Error`, and so on. That rewrite is only sound where
    /// the bare name *resolves* to the standard library's type. In a
    /// package that declares its own `Error` at any scope, some bare
    /// occurrences resolve to the local one, and qualifying those
    /// retargets a reference to a different type. The result still
    /// compiles whenever both types satisfy the position, which is the
    /// whole hazard: nothing downstream reports it.
    ///
    /// The rule pack already refuses inside the *file* that carries the
    /// declaration. That guard cannot see a reference in a sibling file,
    /// and it cannot see a shadow a package inherits through an
    /// `@_exported import` without declaring anything itself. Fleet
    /// sizing on 2026-08-01 measured both populations at ecosystem scale:
    /// 141 of 385 packages declare one of these names somewhere, 16 of
    /// those carry cross-file bare references in qualifiable positions,
    /// and a further 16 inherit a shadow purely by re-export.
    ///
    /// So the gate is package-scoped, and it is *computed* — a curated
    /// skip list would be wrong the first time a package gained or lost a
    /// declaration, and nothing would say so.
    public enum Shadow: Swift.String, Sendable, Hashable, CaseIterable {
        case error = "Error"
        case sequence = "Sequence"
        case collection = "Collection"
    }
}

extension Workspace.Lint.Shadow {
    /// Where a shadowing declaration was found.
    ///
    /// Carried rather than counted: a package skipped for shadowing has
    /// to say *which* name and *where*, or the fleet run's output is a
    /// list of packages nobody can check.
    public struct Site: Sendable, Hashable {
        /// The shadowed standard-library name.
        public let name: Workspace.Lint.Shadow

        /// The file, relative to the package root.
        ///
        /// Relative on purpose: an absolute path names a machine, and
        /// these lines are read out of fleet logs.
        public let file: Swift.String

        /// The one-based line number.
        public let line: Swift.Int

        /// The source line, trimmed — the evidence itself.
        public let text: Swift.String

        public init(
            name: Workspace.Lint.Shadow,
            file: Swift.String,
            line: Swift.Int,
            text: Swift.String
        ) {
            self.name = name
            self.file = file
            self.line = line
            self.text = text
        }
    }
}

extension Workspace.Lint.Shadow.Site: CustomStringConvertible {
    public var description: Swift.String {
        "\(file):\(line) declares `\(name.rawValue)` — \(text)"
    }
}

extension Workspace.Lint.Shadow {
    /// What one source file contributes to the gate.
    public struct Reading: Sendable, Hashable {
        /// Declarations of a shadowed name in this file.
        public var declarations: [Site] = []

        /// Modules this file re-exports with `@_exported import`.
        ///
        /// Collected in the same pass as the declarations because the
        /// second tier of the gate needs them and a second walk over the
        /// same trees would double the cost of every fix run.
        public var reexports: [Swift.String] = []

        public init(declarations: [Site] = [], reexports: [Swift.String] = []) {
            self.declarations = declarations
            self.reexports = reexports
        }

        public var isEmpty: Swift.Bool {
            declarations.isEmpty && reexports.isEmpty
        }
    }
}

extension Workspace.Lint.Shadow {
    /// Declaration keywords that can introduce a shadowing type.
    ///
    /// `associatedtype` is here because a protocol's associated type
    /// named `Error` shadows inside every conforming context, which is
    /// exactly the cross-file case the file-local guard misses.
    static let declarationKeywords: Swift.Set<Swift.String> = [
        "enum", "struct", "class", "actor", "protocol", "typealias", "associatedtype",
    ]

    /// Declaration keywords that can carry a generic parameter list.
    ///
    /// A generic parameter named `Error` shadows for the whole body of
    /// the declaration that introduces it — including, for a generic
    /// type, every extension of it in every other file.
    static let genericKeywords: Swift.Set<Swift.String> = [
        "enum", "struct", "class", "actor", "func", "init", "subscript", "typealias",
    ]

    /// Keywords that may sit between `import` and the module name.
    static let importQualifiers: Swift.Set<Swift.String> = [
        "public", "internal", "package", "fileprivate", "private", "open",
        "struct", "class", "enum", "protocol", "typealias", "func", "var", "let",
        "actor", "precedencegroup",
    ]
}

extension Workspace.Lint.Shadow {
    /// Reads one file's contribution to the gate.
    ///
    /// A line scanner rather than a parse. That is a deliberate trade:
    /// the gate decides whether to *withhold* a rewrite, so its errors
    /// are asymmetric. Reporting a declaration that is not one costs a
    /// package its PLAT-ARCH-022 fixes for one run; missing one applies a
    /// silent retarget. The scanner therefore over-reports rather than
    /// under-reports wherever the two are in tension — and it is pure, so
    /// its behaviour is pinned by fixtures rather than by whatever the
    /// ecosystem happens to hold today.
    ///
    /// Whole-line comments are skipped. Not because a false positive
    /// there would be unsafe — it would be safe, merely noisy — but
    /// because the sizing pass measured two of them and a reported site
    /// that points at prose is a site nobody can act on. A declaration
    /// cannot begin with `//`, so nothing sound is lost.
    ///
    /// - Parameter file: The path recorded on any site found, relative to
    ///   the package root.
    public static func read(
        _ source: Swift.String,
        at file: Swift.String
    ) -> Reading {
        var reading = Reading()
        var number = 0
        for line in source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            number += 1
            let trimmed = line.drop(while: \.isWhitespace)
            guard !trimmed.isEmpty else { continue }
            guard
                !trimmed.hasPrefix("//"),
                !trimmed.hasPrefix("/*"),
                !trimmed.hasPrefix("*")
            else { continue }

            let tokens = Self.tokens(of: trimmed)
            guard !tokens.isEmpty else { continue }

            let text = Swift.String(
                trimmed.reversed().drop(while: \.isWhitespace).reversed()
            )
            for name in Self.declarations(in: tokens) {
                reading.declarations.append(
                    .init(name: name, file: file, line: number, text: text)
                )
            }
            if let module = Self.reexport(in: tokens) {
                reading.reexports.append(module)
            }
        }
        return reading
    }
}

extension Workspace.Lint.Shadow {
    /// One lexical unit of a source line.
    ///
    /// Identifiers and single punctuation characters are all this gate
    /// needs; whitespace is dropped. `@` is treated as an identifier
    /// character so an attribute arrives as one token, which is what
    /// makes `@_exported` recognizable without a second rule.
    enum Token: Equatable, Sendable {
        case identifier(Swift.String)
        case symbol(Swift.Character)
    }

    static func tokens(of line: Swift.Substring) -> [Token] {
        var tokens = [Token]()
        var current = ""
        for character in line {
            if character.isLetter || character.isNumber
                || character == "_" || character == "@" || character == "$"
            {
                current.append(character)
                continue
            }
            if !current.isEmpty {
                tokens.append(.identifier(current))
                current = ""
            }
            if !character.isWhitespace {
                tokens.append(.symbol(character))
            }
        }
        if !current.isEmpty {
            tokens.append(.identifier(current))
        }
        return tokens
    }

    static func identifier(_ token: Token?) -> Swift.String? {
        guard case .some(.identifier(let word)) = token else { return nil }
        return word
    }
}

extension Workspace.Lint.Shadow {
    /// Every shadowed name this line declares.
    ///
    /// Two shapes, and only two. A declaration keyword immediately
    /// followed by the name — `enum Error`, `typealias Collection` — and
    /// a generic parameter position in the list that immediately follows
    /// a declaration's own name. The second is anchored to the keyword
    /// rather than to any `<` on the line, so `Set<Error>` in a signature
    /// is a *use* and is not reported.
    static func declarations(in tokens: [Token]) -> [Workspace.Lint.Shadow] {
        var found = [Workspace.Lint.Shadow]()
        for index in tokens.indices {
            guard let word = Self.identifier(tokens[index]) else { continue }

            if Self.declarationKeywords.contains(word),
                let next = Self.identifier(tokens.indices.contains(index + 1) ? tokens[index + 1] : nil),
                let name = Workspace.Lint.Shadow(rawValue: next)
            {
                found.append(name)
            }

            guard Self.genericKeywords.contains(word) else { continue }
            // `init` and `subscript` carry no declared name, so their
            // generic list opens one token earlier.
            let opening = (word == "init" || word == "subscript") ? index + 1 : index + 2
            guard
                tokens.indices.contains(opening),
                tokens[opening] == .symbol("<")
            else { continue }
            found.append(contentsOf: Self.parameters(in: tokens, from: opening))
        }
        return found
    }

    /// Shadowed names in parameter position of the generic list opening
    /// at `opening`.
    ///
    /// Parameter position means "immediately after the `<` or a `,` at
    /// depth one". A name inside a constraint — `<T: Collection>` — is a
    /// reference to the standard library's protocol, not a shadow, and is
    /// correctly not reported.
    static func parameters(
        in tokens: [Token],
        from opening: Swift.Int
    ) -> [Workspace.Lint.Shadow] {
        var found = [Workspace.Lint.Shadow]()
        var depth = 0
        var index = opening
        while index < tokens.count {
            switch tokens[index] {
            case .symbol("<"):
                depth += 1
            case .symbol(">"):
                depth -= 1
                if depth == 0 { return found }
            case .identifier(let word):
                guard depth == 1, index > opening else { break }
                let previous = tokens[index - 1]
                guard previous == .symbol("<") || previous == .symbol(",") else { break }
                if let name = Workspace.Lint.Shadow(rawValue: word) {
                    found.append(name)
                }
            default:
                break
            }
            index += 1
        }
        return found
    }

    /// The module this line re-exports, if it re-exports one.
    ///
    /// `@_exported import Foo`, `@_exported public import Foo`, and
    /// `@_exported import struct Foo.Bar` all name `Foo`: the leading
    /// component is the module, and the declaration kind in between is
    /// skipped.
    static func reexport(in tokens: [Token]) -> Swift.String? {
        guard tokens.contains(.identifier("@_exported")) else { return nil }
        guard let start = tokens.firstIndex(of: .identifier("import")) else { return nil }
        var index = start + 1
        while index < tokens.count {
            guard let word = Self.identifier(tokens[index]) else { return nil }
            guard Self.importQualifiers.contains(word) else { return word }
            index += 1
        }
        return nil
    }
}
