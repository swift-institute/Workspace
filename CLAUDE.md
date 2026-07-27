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
swift run --package-path Application workspace doctor           # report checkout facts
Application/.build/debug/workspace package test --package-path Application --fresh
Application/.build/debug/workspace navigation install
Application/.build/debug/workspace navigation check

# local-source composition, for changing a package and its consumer together
swift run --package-path Application workspace compose --consumer <c> --dependency <d>
swift run --package-path Application workspace verify  --consumer <c> --dependency <d>
swift run --package-path Application workspace restore --consumer <c> --dependency <d>
```

The first `swift run` in a fresh clone compiles the whole dependency graph and is **silent for
several minutes**. It is not hung. That invocation bootstraps the executable; after it exists,
run SwiftPM work only through `Application/.build/debug/workspace package`.

`doctor` reports which checks apply to your setup. A check that needs Institute access reports
that it did not run — that is not a failure of your checkout.

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
- **Dependencies are branch-based.** `doctor` warns when a recorded pin lags its branch tip;
  a green over stale pins is not evidence — re-resolve.
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
