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
swift test --package-path Application                           # the application's own tests

# local-source composition, for changing a package and its consumer together
swift run --package-path Application workspace compose --consumer <c> --dependency <d>
swift run --package-path Application workspace verify  --consumer <c> --dependency <d>
swift run --package-path Application workspace restore --consumer <c> --dependency <d>
```

The first `swift run` in a fresh clone compiles the whole dependency graph and is **silent for
several minutes**. It is not hung. Build first (`swift build --package-path Application`) when
you want the compile and the command to be separate, legible steps.

`doctor` reports which checks apply to your setup. A check that needs Institute access reports
that it did not run — that is not a failure of your checkout.

## Gotchas

- **The materialized org roots (`swift-primitives/`, `swift-standards/`, `swift-foundations/`,
  …) hold independent repositories, not part of this one.** Each has its own history, remote,
  CI, and license. Work on a package inside its own repository and open the pull request there.
  The org roots are ignored here; committing their contents to this repository is always wrong.
- **`Workspace.json` is the sole name → org → path authority.** A repository's location is
  derived from its inventory entry's `organization` and `layer` fields (authority, vendor, and
  jurisdiction orgs nest under their layer root, e.g. `swift-standards/swift-ietf/<package>`).
  Never infer a location from a package's name and never scan the tree for packages — resolve
  through the inventory (`Workspace.Layout` in the application). Materialized paths are
  regenerable state; nothing durable may reference one as stable.
- **A flat `Packages/` directory is a superseded checkout, not the layout.** `doctor` reports
  it (`layout-migration` warning); re-running `sync` materializes the org hierarchy alongside.
  Tooling never deletes `Packages/` — removal is a manual act after local work is salvaged.
- **`sync` never rewrites work.** It fast-forwards only a checkout that is clean, on `main`,
  tracking `origin/main`, with no local commits. It never resets, cleans, stashes, rebases, or
  switches a branch. Dirty worktrees and feature branches are reported and left alone. Preserve
  that guarantee in any change you make to it.
- **`Package.resolved` is generated state.** Never commit, hand-edit, or delete it to force
  resolution. Change `Package.swift` and resolve.
- **Dependencies are branch-based.** `doctor` warns when a recorded pin lags its branch tip;
  a green over stale pins is not evidence — re-resolve.
- **The generated Xcode workspace uses relative references only.** Never emit an absolute path
  into `institute.xcworkspace` or into `Workspace.json` — a test asserts this.
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

Changes are pull requests. Before opening one: `doctor` reports no errors, the package builds
and tests from its own repository, and new behaviour is covered by a test. New capability comes
with the acceptance criteria that prove it — a check whose failure mode is a clean-looking pass
is not finished.
