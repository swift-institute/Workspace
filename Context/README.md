# Agent context

`workspace context install` materializes the checkout-root entry point from
this directory.

- `AGENTS.md` is the platform-neutral boot context.
- The generated `CLAUDE.md` is a relative symbolic link to `AGENTS.md`, so
  there is one document rather than two files that can drift.
- Canonical skill directories are projected as symbolic links into the invoking
  account's `~/.claude/skills`; the account-wide `~/.agents/skills` points to
  the same projection for Codex and ChatGPT.

The destinations are account-wide rather than per-checkout because this
hierarchy has several roots a session legitimately starts in. A per-checkout
projection loads for exactly one of them; installing one per root means several
installations that drift. The account root is read from `HOME` at install time
and never written down, so no committed file names a machine, an account, or a
checkout location. Skill link targets are absolute because the projection
directory no longer sits inside the hierarchy it points into, and how deep a
checkout sits below the account root — or whether it sits below it at all —
differs per machine. The `CLAUDE.md` target is relative because it sits beside
`AGENTS.md` and should survive moving the hierarchy.

The installer owns generated documents carrying its marker and symbolic links
that point into canonical skill roots. It adds current projections and removes
retired generated projections. It fails closed on divergent paths and never
removes user-owned entries — including a projection pointing anywhere outside
the canonical Institute roots, which it does not recognize and must not touch.
It migrates its former checkout-local `.agents/skills` link to the account-wide
link only when that old link still points to the projection it owned.

Canonical skill roots are optional. The public `swift-institute/Skills`
repository is what every contributor clones; `Internal`, `Engagement`, and
`rule-institute` are separate repositories only some accounts carry. A source
root that is absent is skipped, so the installation an Institute member gets
and the one an outside contributor gets differ only in which skills exist to
project. Requiring all four made the command fail for everyone holding fewer,
which is how it came to have never run on any machine.

Before projection, the Swift `Skill Validation` product parses every canonical
hub, accepts only `name` and `description` metadata, requires the directory and
declared names to match, and rejects `SKILL.md` files over 500 lines.

Workspace also owns the Swift build coordinator exposed through
`workspace package`. It serializes SwiftPM work, fixes build concurrency at
three jobs, rejects arguments that would override coordinator-owned state, and
provides isolated `--fresh` build and test evidence whose scratch state is
removed before returning. Agent context points to that typed interface rather
than to repository-local script collections.

The bare command is established once from a fresh clone with
`swift run --package-path Application workspace install`. That self-hosting
bootstrap copies the executable out of generated SwiftPM build state and links
it from `$HOME/.local/bin`; every later SwiftPM operation uses
`workspace package`. The installer does not edit shell startup files and
refuses to replace any command path it cannot prove it owns.

The cclsp/SourceKit-LSP boundary is likewise Workspace-owned through
`workspace navigation`. It installs a pinned public cclsp revision into derived
state, generates machine-local MCP and per-package LSP configuration from the
physical Workspace layout, and launches only the SourceKit-LSP selected by
Xcode with `TOOLCHAINS` removed. cclsp remains external developer tooling, not a
`Workspace.json` package.
