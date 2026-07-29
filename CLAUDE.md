# Workspace — agent instructions

The Swift Institute front door: the public package inventory, machine-checked facts about a
checkout, and an isolated local development checkout for Xcode. Read `README.md` first for
orientation. Nothing here needs Institute access — if a step wants credentials or a repository
you cannot read, that is a defect worth reporting.

## Commands

All paths are relative to the repository root.

```sh
swift run --package-path Application workspace sync --dry-run   # plan only, changes nothing
swift run --package-path Application workspace sync             # clone and fast-forward
swift run --package-path Application workspace build            # build the whole selection, one xcodebuild
swift run --package-path Application workspace doctor           # report checkout facts
swift run --package-path Application workspace doctor --institute  # + roster currency (needs gh)
Application/.build/debug/workspace package test --package-path Application --fresh
Application/.build/debug/workspace navigation install
Application/.build/debug/workspace navigation check
Application/.build/debug/workspace lint install                 # pinned swift-linter
Application/.build/debug/workspace lint check                   # parity with CI
Application/.build/debug/workspace lint                         # sweep the ecosystem
Application/.build/debug/workspace package lint                 # one package, no arguments

# local-source composition, for changing a package and its consumer together
swift run --package-path Application workspace compose --consumer <c> --dependency <d>
swift run --package-path Application workspace verify  --consumer <c> --dependency <d>
swift run --package-path Application workspace restore --consumer <c> --dependency <d>
```

The first `swift run` in a fresh clone compiles the whole dependency graph and is **silent for
several minutes**. It is not hung. That invocation bootstraps the executable; after it exists,
run SwiftPM work only through `Application/.build/debug/workspace package`.

`doctor` reports which checks apply to your setup. A check that needs Institute access reports
that it did not run — that is not a failure of your checkout. `--institute` is the one opt-in
that asks for those checks; it is never selected from ambient machine state, so an
authenticated `gh` never changes what a plain `doctor` does.

## Gotchas

- **The materialized org roots (`swift-primitives/`, `swift-standards/`, `swift-foundations/`,
  …) hold independent repositories, not part of this one.** Each has its own history, remote,
  CI, and license. Work on a package inside its own repository and open the pull request there.
  The active layout resolves the checkout physically and places the roots beside it (see
  ARCHITECTURE.md, "Materialization layout"); invoking through a symlink does not redirect the
  hierarchy. The root names remain ignored here transitionally for checkouts that materialized
  inside the clone, and committing their contents to this repository is always wrong. Doctor
  reports legacy-only and duplicate legacy-plus-sibling materializations as errors, uses only
  the sibling for downstream checks, and never migrates or deletes the legacy contents.
- **`Workspace.json` is the sole name → org → path authority.** A repository's location is
  derived from its inventory entry's `organization` and `layer` fields (authority, vendor, and
  jurisdiction orgs nest under their layer root, e.g. `swift-standards/swift-ietf/<package>`).
  Never infer a location from a package's name and never scan the tree for packages — resolve
  through the inventory (`Workspace.Layout` in the application). Materialized paths are
  regenerable state; nothing durable may reference one as stable.
- **`sync` never rewrites work.** It fast-forwards only a checkout that is clean, on `main`,
  tracking `origin/main`, with no local commits. It never resets, cleans, stashes, rebases, or
  switches a branch. Dirty worktrees and feature branches are reported and left alone. Preserve
  that guarantee in any change you make to it.
- **`Package.resolved` is generated state.** Never commit, hand-edit, or delete it to force
  resolution. Change `Package.swift` and resolve.
- **`institute.xcworkspace` is generated state; `Selection.json` is its authored input.**
  `sync` renders the workspace from the resolved selection and byte-compares before writing,
  so it is deterministic in the same sense `Workspace.json` is. It is ignored and must never
  be committed — a tracked derived file can disagree with its source, and it did: the
  version tracked until 2026-07-28 rendered a five-entry selection while the working copy
  carried 437, and nothing reported the divergence because agreement was never checked
  against the *committed* pair. Change the selection and run `sync`; never hand-edit the
  workspace or add references in Xcode. `Selection.json` is committed policy input — the
  public default checkout, the whole roster since c850ed5 — so it is the one of the two
  that stays tracked.
- **`Selection.json` is policy; `Selection.local.json` is one machine's choice.** They used to
  be the same file, which meant every local expansion showed up as a pending policy change,
  was one `git add .` from becoming one, and left the file perpetually dirty. On 2026-07-28
  that became a live hazard: concurrent sessions had to be told individually not to commit,
  checkout, stash or clean it. To change what *your* checkout opens, write the ignored
  `Selection.local.json` — `{"version": 1, "add": [...], "remove": [...]}`, both keys
  required — and never edit `Selection.json` for that purpose. Three properties are
  load-bearing and must survive any change here. It is a **delta**, not a replacement, so a
  package added to policy later still arrives rather than being silently frozen out.
  Validation applies to the **merged** result — `Selection.effective(at:in:)` is the only
  path to a selection, and an override that is present but malformed fails the command
  instead of falling back to committed policy. And `sync` and `doctor` both **lead with
  which selection is in effect**, naming every identity the local file withholds, because a
  silent override is worse than the shared artifact it replaced. That line is a report
  header rather than a `doctor` check on purpose: a check can report `notApplicable`, and a
  check that never ran must never look like one that passed (issue #43). See
  `Research/Local Resolution/DESIGN-Selection-Override-2026-07-29.md` and issue #46.
- **`workspace build` builds the selection in one `xcodebuild`; `workspace package build` builds
  one package in one `swift build`. They are not the same measurement.** The package path
  resolves dependencies from *pinned remotes*, so it cannot see a local edit at all — change a
  selected package and a consumer's `swift build` compiles the published version and reports
  success. The workspace path resolves members from local paths, so it is the only one that
  builds the institute from the working copy. It is also the only one that shares work: the
  serialised path gives each package its own `.build` and recompiles the shared closure once per
  package, while one merged graph compiles it once.
- **A stale `Institute.xcscheme` does not fail the build — it silently builds less of the
  selection.** `xcodebuild` drops a `BuildableReference` whose blueprint matches no target in its
  container *without a warning*: measured, one fabricated entry among valid ones still exits 0 and
  prints `** BUILD SUCCEEDED **`, and only an entirely unmatched scheme fails (exit 66). Nothing
  in the build output can catch it either, because an up-to-date target compiles nothing, so "not
  in the log" and "not in the scheme" are the same observation. This is why the scheme is
  generated from `swift package dump-package` rather than from target names anyone typed, and why
  `workspace build` re-renders it from the manifests and byte-compares *before* building, refusing
  to run on a mismatch. Never hand-edit the scheme, and never soften that pre-flight check into a
  warning — a build path that can report success having compiled a fraction of the selection is
  the exact failure this gate exists to prevent.
- **Roster drift is detected by CI, not by anyone remembering.** `inventory-currency`
  compares `Workspace.json` against a live discovery in both directions. It needs an
  authenticated `gh`, so no contributor command reaches it and none should: `doctor` is
  credential-free and offline, and selecting Institute access from ambient state would make
  a green `doctor` mean different things on different machines — including for every
  contributor who authenticated `gh` to run `gh issue list`, as this file tells them to.
  `--institute` is the explicit ask; the nightly `roster-currency` workflow is what removes
  the human. That workflow fails rather than reporting clean when the check says `not run`,
  because a check that did not execute must never read like one that found nothing — the
  defect that kept this check unreachable for its whole life (issue #43).
- **Dependencies are branch-based.** `doctor` warns when a recorded pin lags its branch tip;
  a green over stale pins is not evidence — re-resolve.
- **A lint verdict of "clean" always means something was measured.** swift-linter
  ships rule-pack-agnostic: without a reachable configuration zero rules fire, and a
  directory with no `Lint.swift`, a *file* path, or an empty directory each exit zero
  having printed nothing. Exit status attests that a process ran, never that it was
  configured. Workspace adjudicates every run against the engine's always-on summary
  line and reports `UNMEASURED` — never clean — when the line is absent, no rules
  loaded, or no files were scanned, per package inside the sweep as well as alone.
  Preserve that in any change: a lint path that can report clean without a summary
  line is the defect this capability exists to prevent. The sweep likewise fails
  rather than reporting an empty ecosystem clean when the inventory materializes
  nothing, which is what a run from the wrong hierarchy root looks like.
- **There is no way for a package to opt out of being linted.** A package with no
  `Lint.swift` is linted against the default bundle for its layer — `primitives`,
  `standards`, or `institute` — spawned through the prebuilt runner directly, because
  the dispatcher needs a consumer manifest to classify and without one loads zero
  rules. The default is what that layer's configured packages already activate, so
  adopting a `Lint.swift` later cannot change the verdict. Do not reintroduce an
  allowlist, a skip list, or any other record that excuses a package from
  measurement: the `Lint.json` allowlist and the `unconfigured` verdict were deleted
  on 2026-07-29 for exactly that reason. A package outside every layer root is
  `UNMEASURED`, never defaulted to a guessed bundle. This one path has no CI
  counterpart — CI activates on `Lint.swift` and runs nothing for these packages —
  so it is Workspace's own measurement and is documented as one.
- **swift-linter is developer tooling, not an inventory package.** Install it through
  `workspace lint install`; never add it to `Workspace.json` and never put a machine
  path in durable configuration. Workspace sets `SWIFT_LINTER_RUNNER` on the child
  process itself — never a developer's shell profile, which would be machine-specific
  by construction. Parity with CI is the point: same rolling `ci-binaries` release,
  same checksum verification, same `--exit-policy strict`. Do not add a flag that
  softens the rule set, the severities, or the exit policy — a local capability that
  can disagree with CI teaches people to trust whichever answer is convenient.
  `lint check` compares the installed composite digest against the one CI consumes;
  a lint run never contacts the network.
- **cclsp is developer tooling, not an inventory package.** Install and verify it through
  `workspace navigation`; never add it to `Workspace.json`, resolve it from a personal fork,
  or put a fixed machine checkout path in durable configuration. `navigation serve` owns the
  Xcode/`TOOLCHAINS` boundary. The merged cross-package index remainder is Workspace issue #25.
- **The generated Xcode workspace uses relative references only.** Never emit an absolute path
  into `institute.xcworkspace` or into `Workspace.json` — `Application` remains
  `group:Application`, while materialized packages use `group:../<inventory-derived-reference>`.
- **A composed manifest is uncommittable local state.** `compose` writes a machine-local
  absolute path deliberately: off-machine it must fail loudly at resolution rather than silently
  resolve elsewhere. Never commit one; `restore` before pushing. `restore` returns the declared
  clause byte-for-byte and never touches the dependency's worktree.
- **`restore`'s structural check is not a reproducibility guarantee.** It evaluates the restored
  manifest in isolation and confirms three things: it evaluates, the dependency is declared by
  URL again, and no local path leaked. It resolves nothing and contacts no remote. Report its
  scope honestly — a green structural check does not mean the consumer builds from canonical
  sources, and unpushed dependency commits will only surface in a real resolve.

## Contributing

Open work lives in GitHub issues:

```sh
gh issue list
```

Changes are pull requests. Before opening one: `doctor` reports no errors, the package passes a
fresh coordinator test from its own repository, and new behaviour is covered by a test. New
capability comes with the acceptance criteria that prove it — a check whose failure mode is a
clean-looking pass is not finished.
