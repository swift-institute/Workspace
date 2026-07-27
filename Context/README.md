# Agent context

`workspace context install` materializes the checkout-root entry point from
this directory.

- `AGENTS.md` is the platform-neutral boot context.
- `CLAUDE.md` imports `AGENTS.md` instead of duplicating it.
- Canonical skill directories are projected as relative symbolic links into
  `.claude/skills`; `.agents/skills` points to the same projection.

The installer owns generated documents carrying its marker and symbolic links
that point into canonical skill roots. It adds current projections and removes
retired generated projections. It fails closed on divergent paths and never
removes user-owned entries.

Before projection, the Swift `Skill Validation` product parses every canonical
hub, accepts only `name` and `description` metadata, requires the directory and
declared names to match, and rejects `SKILL.md` files over 500 lines.

Workspace also owns the Swift build coordinator exposed through
`workspace package`. It serializes SwiftPM work, fixes build concurrency at
three jobs, rejects arguments that would override coordinator-owned state, and
provides isolated `--fresh` build and test evidence whose scratch state is
removed before returning. Agent context points to that typed interface rather
than to repository-local script collections.

The cclsp/SourceKit-LSP boundary is likewise Workspace-owned through
`workspace navigation`. It installs a pinned public cclsp revision into derived
state, generates machine-local MCP and per-package LSP configuration from the
physical Workspace layout, and launches only the SourceKit-LSP selected by
Xcode with `TOOLCHAINS` removed. cclsp remains external developer tooling, not a
`Workspace.json` package.
