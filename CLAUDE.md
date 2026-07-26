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
```

`doctor` reports which checks apply to your setup. A check that needs Institute access reports
that it did not run — that is not a failure of your checkout.

## Gotchas

- **`Packages/` holds independent repositories, not part of this one.** Each has its own
  history, remote, CI, and license. Work on a package inside its own repository and open the
  pull request there. `Packages/` is ignored here; committing its contents to this repository is
  always wrong.
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

## Contributing

Open work lives in GitHub issues:

```sh
gh issue list
```

Changes are pull requests. Before opening one: `doctor` reports no errors, the package builds
and tests from its own repository, and new behaviour is covered by a test. New capability comes
with the acceptance criteria that prove it — a check whose failure mode is a clean-looking pass
is not finished.
