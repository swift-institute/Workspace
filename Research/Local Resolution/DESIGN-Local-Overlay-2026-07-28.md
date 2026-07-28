# Design — the local overlay

**Status:** proposed, not implemented · **Date:** 2026-07-28
**Objective (principal, verbatim):** *"capability to do local development on single,
multiple, or all swift-institute packages as if each `Package.swift` had local path
based dependencies instead of URL based ones"* — without ever committing a
path-based manifest.

**Standing:** the principal's override of 2026-07-28 **overturns all prior research
and decisions on this topic**, including ADR-001's choice of generated
`.package(path:)` composition and its retirement of `swift package edit`. This
document is written from first principles and does not inherit those decisions.
Prior *measurements* are treated as evidence rather than authority; every fact
load-bearing for this design was re-measured today against the pinned toolchain.

**Standing rule this document asserts, at the Team Lead's direction:** *prior
measurements survive; conclusions built on them lapse.* Discarding evidence and
discarding conclusions are different acts, and an override does only the second.
ADR-001's executed spike findings are therefore carried forward as facts even
though its Decision is superseded.

**Vantage.** Everything below was measured on one macOS 27.0 machine, Swift 6.4
(`swiftlang-6.4.0.27.1`), Xcode 27.0 at `/Applications/Xcode-beta.app`,
`~/.swiftpm/configuration/` empty. Mechanism experiments ran on throwaway fixtures
in a session scratchpad with `file://` remotes; census and latency figures come
from the real checkout and from `github.com`. **No institute package worktree or
`.build` directory was written to.** Nothing here is a claim about CI, about Linux,
or about Xcode — the Xcode gap is called out explicitly as untested.

**Build system and manifest floor, stated because both moved recently.** At Swift
6.4 `--build-system` **defaults to `swiftbuild`**; `native` and `xcode` are
deprecated. The whole prior `Research/Local Resolution` corpus was measured on
Swift 6.3.3 under the *old* default, so none of it is inherited here. The
load-bearing results below were taken **on both build systems** and at
**`swift-tools-version: 6.3.3`** — the floor the ecosystem actually sits on, which
cannot move to 6.4 until a Linux container exists. Where a result is
build-system-specific or tools-version-specific this document says so; the
overlay's behaviour was identical on both.

**This document discharges the spike the founding implementation plan owed.**
`WORKSPACE_LOCAL_RESOLUTION_IMPLEMENTATION_PLAN.md` §7.1 already names
`swift package edit --path` as *Backend A, the first implementation candidate*,
and lists nine open questions no production architecture may assume past. Seven are
answered below; §7 records the two that are not, and §4 records the one whose
answer contradicts the plan's own required behaviour.

---

## 1. Summary of the recommendation

Build the overlay on **`swift package edit --path`**, owned end-to-end by the
Workspace CLI, with the roster and the hierarchy root as its only inputs.

The principal's proposed distinction — *local state is acceptable when generated,
unacceptable when authored* — **holds for SPM edit, and I could not break it.** The
editable state is a symlink and a JSON entry, both produced by a command, both
derived from committed inputs (`Workspace.json` + "the root is the parent of the
`Workspace` checkout"), both gitignored in 433 of 441 packages. A contributor
configures nothing. A fresh clone plus `workspace sync` plus one overlay command
yields the same graph on any machine.

That is the good news. Four things stand between it and a shippable capability, and
they are the substance of this document:

1. A **quiet-degradation path** that is real, reproducible, and already present in
   this tree today (§4).
2. A **velocity claim that my measurements do not yet support at the size the
   fleet assumes** (§3).
3. A **cost at scale that is unmeasured at real graph size** and may force a
   second, less-supported mechanism (§6).
4. **Eight packages that would let the overlay's own artifact be committed**, and
   **eight more that the overlay structurally cannot reach** (§7).

---

## 2. What `swift package edit` actually does — measured, not described

Fixture: consumer declaring a dependency by URL; dependency worktree carrying an
**uncommitted** marker so that "local source was compiled" is decidable.

| Question | Result |
|---|---|
| Is `Package.swift` modified? | **No** — byte-identical throughout |
| Is `Package.resolved` modified? | **No**, unless the local manifest itself changes the graph (see below) |
| Where does the state live? | `<root>/.build/workspace-state.json`: `state.name = "edited"`, `state.path = <absolute>`, with `basedOn` retaining the prior `sourceControlCheckout` |
| What lands in the worktree? | one symlink, `<root>/Packages/<identity> -> <absolute path>` |
| `git status` afterwards | `?? Packages/` — untracked, and **not ignored by default** |
| Is local source really compiled? | **Yes** — positive control: uncommitted marker present in compiled products; negative control: canonical marker absent from `.build` entirely |
| Does it work on a **transitive** dependency? | **Yes** — a root package can redirect a dependency it does not declare, and the whole graph recompiles |
| Does it work under `branch:` requirements? | **Yes** — which matters, because **2,137 of 2,188** institute edges are branch-based |
| Does it bypass version solving? | **No.** `edit` first requires the package to be *placeable*. Against an unsatisfiable requirement it exits **1** with the resolver's own error |
| Does the edited manifest drive resolution? | **Yes** — a dependency added only in local source is fetched and compiled, and `Package.resolved` gains its pin |
| Does `unedit` restore? | **Yes, completely** — see §5 |
| Local checkout declares a different package/target name? | **Fails loudly** — exit **1**, *"target 'Dep' referenced in product 'Elsewhere' could not be found"* |
| Edited package drops out of the graph entirely? | **Overlay lingers** — build green, `edited` entry retained, `Packages/` residue kept. Stale, not wrong, but `status` must surface it (§7) |
| Honoured under `--build-system native`? | **Yes** — verified in a clean room, marker in `arm64-apple-macosx/debug/Dep.build/Dep.swift.o` |
| Honoured at `swift-tools-version: 6.3.3`? | **Yes** — the manifest floor, not just 6.4 |
| Accepts `--scratch-path`? | **No** — exit **64**. This is consequential; see §4a |

Two consequences worth stating separately.

**The version requirement is still enforced; the *content* is not.** `edit` swaps
the source tree for an already-resolved slot. So the overlay cannot manufacture a
graph that could not exist — but it can and does compile source that corresponds to
no commit anywhere. That residual is the entire point of the feature, and it is
what §5's parity report exists to make visible rather than to prevent.

**Under a full overlay, a build contacts no remote at all.** Sixty packages, every
one edited, remote repositories physically removed from disk: build green, all
sixty local markers in compiled products. The negative control fires — `unedit` one
package and `swift package update` exits **1** on the missing remote — so the green
is a measurement and not an absence.

---

## 3. Baseline first — and the number is smaller than the framing assumes

The brief is right to demand this, and the honest answer is uncomfortable.

Measured, same fixture, marker-verified in compiled products every round:

| Loop | Round time |
|---|---|
| **Today:** change → commit → push → `swift package update` → build | 4.65 s / 6.07 s / 5.57 s |
| **Overlay:** change → build | 3.67 s / 3.42 s / 3.37 s |
| One-time `edit` | 0.70 s |

**~1.9 s per round.** Against a `file://` remote, one dependency, no review, no CI.
On this evidence alone the capability would not be worth building.

The measurement is not the claim, though, and the gap between them is where the
real cost lives. What the fixture excludes:

- **Remote round-trips.** Median `git ls-remote` to `github.com` over a random
  sample of 20 roster packages: **0.48 s** (max 0.56 s, 20/20 succeeded). Under
  branch-based dependencies `swift package update` must ask every branch-pinned
  remote for its tip. The flagship consumer, `Workspace/Application`, carries
  **200 pins**. Sequentially that is **~96 s of pure ref round-trips per
  cross-package change**; SwiftPM parallelises fetching, so treat 96 s as an upper
  bound on that component, not a measurement of it.
- **Commit, push, review, and CI**, which I did not measure and which dominate any
  seconds-level figure.

So the defensible statement is: **the overlay removes commit, push, and
re-resolution from the inner loop entirely, and with them a term that scales with
the number of branch-pinned remotes in the closure.** It does not make an
individual rebuild meaningfully faster.

> **Recommendation before implementation:** measure one real `swift package update`
> on `Workspace/Application` at 200 pins, warm cache, wall clock. That single number
> decides whether this capability is worth its complexity. I did not run it because
> it writes into a `.build` directory another session is using. It is one command
> and it should be taken before the first line of implementation.

---

## 4. The failure mode to design against, reproduced

The brief names it exactly: *a developer believing they are testing local source
when they are not.* It exists, it is deterministic, and this tree already contains
one instance of it.

**Delete `.build` under an active edit and the overlay silently disappears while
looking applied.**

```
edit applied      → Packages/dep -> …/dep      state: edited
rm -rf .build     → Packages/dep -> …/dep      state: (gone)
swift build       → Packages/dep -> …/dep      state: sourceControlCheckout
                    exit 0 · canonical source compiled · local marker absent
```

The symlink survives, because it lives in the worktree. The `edited` entry does
not, because it lives in `.build`. The next build resolves canonical, succeeds, and
says nothing. `swift package unedit` in that state exits **1** with *"dependency
not in edit mode"* — SwiftPM is not confused, but nothing consults it.

This explains a finding recorded as *unresolved* in
`Repository Safety Inspection` §4.3 and `Owner Capability Matrix` §3.3:
`Application/Packages/swift-git` is a live edit symlink while `workspace-state.json`
records `remoteSourceControl`. That was not a mystery. It is what deleting `.build`
under an edit leaves behind, and it is sitting in the checkout now.

Reproduced on **both** build systems — `swiftbuild` and `native` — so this is a
property of workspace state, not of a build engine. It is also not
tools-version-specific: reproduced at `6.3.3`.

A second, adjacent path: a `workspace-state.json` SwiftPM cannot decode is
**discarded whole** — including valid entries — with a single
`warning: unable to restore workspace state: …` and **exit 0**. I hit this by
writing a malformed file: sixty edits vanished and the build went green against
canonical. A warning inside a thousand-line build log is not a gate.

### 4a. The scratch-path finding — and why it lands the right way up

The founding plan's Backend A requires, as step 1 of its required behaviour,
*"assign an isolated context-specific scratch path."* **That is not achievable
with `swift package edit` at Swift 6.4, and the plan could not have known it.**

`swift package edit` **rejects `--scratch-path`** — exit **64**, usage error; its
entire option set is `--revision`, `--branch`, `--path`. Editable state can
therefore only ever be written to the *default* `.build`. But `swift build`,
`resolve` and friends **do** accept `--scratch-path`. The two halves disagree, and
the consequence is measured:

| Apply overlay to | Build with | Result |
|---|---|---|
| default `.build` | default `.build` | overlay live — local marker compiled |
| default `.build` | `--scratch-path <ctx>` | **overlay invisible** — canonical compiled, state records `sourceControlCheckout`, **exit 0, no comment**, while `Packages/` still claims the overlay |

That kills two of the founding plan's ambitions outright: **isolated per-context
scratch paths are not available to this backend**, and **two contexts for one root
cannot coexist** by that means (plan §7.1 open questions 1 and 6, answered
negative).

**And then it lands the right way up, which I did not expect.** The Workspace build
coordinator assigns a scratch path in exactly one case:
`Build.Coordinator.freshScratch` returns `nil` unless `fresh: true`
(`Build.Coordinator.swift:158–176`). So:

- **an ordinary coordinator build uses the default `.build` — the overlay is
  honoured**, which is what the inner loop needs;
- **a `--fresh` coordinator build or test gets a unique scratch directory — the
  overlay is bypassed by construction**, which is what a pre-PR gate needs.

`--fresh` is already the institute's documented pre-PR gate (*"the package passes a
fresh coordinator test from its own repository"*). It therefore **already is** the
clean-room check that ADR-001 Consequence 2 made mandatory and that the founding
plan §4.5 demanded alongside local validation — and it is overlay-free without
anyone remembering to make it so. The mechanism and the discipline compose.

**The one change required is a sentence, not a mechanism.** Today that divergence
is silent: a developer running `--fresh` under an active overlay gets canonical
source with nothing said. The coordinator must **state** that it bypassed an
active overlay, and `status` must name `--fresh` as the way to check remote
reproducibility. A correct bypass that looks identical to a forgotten overlay is
the same failure as §4 wearing better clothes.

**Design consequence.** The overlay's state is *two* facts that can disagree, and
SwiftPM will not reconcile them for you. Workspace must own that reconciliation:

- `workspace overlay status` compares the symlink set against SwiftPM's own
  `edited` entries and **exits non-zero on any disagreement**, naming each package
  and which half is missing.
- Every overlay-mode build goes through a Workspace command that runs that check
  **first** and refuses to proceed on a mismatch. Half-applied is an error, never a
  fallback.
- Repair is `workspace overlay apply` re-run — verified idempotent: re-editing over
  a stale symlink succeeds and restores the `edited` entry.

---

## 5. Reversibility and parity

**Off is a command, and it is complete.** `swift package unedit` removes
`Packages/` entirely, restores `sourceControlCheckout`, re-creates the canonical
working copy, and the next build compiles canonical source with the local marker
gone from products — verified with both controls. **The developer's uncommitted
work in the dependency worktree survives**, which was the invariant ADR-001's
Finding 3 demanded of any removal.

This is the sharpest difference from the mirror mechanism ADR-001 measured. That
mechanism was *sticky*: deleting its configuration left local source compiled and
recorded a pin pairing a canonical location with a revision absent from it —
green locally, impossible remotely. **`unedit` has no such behaviour.** I looked
for it and it is not there.

**Parity is decidable, not merely assertable.** A build under the overlay agrees
with a build without it exactly when every overlaid checkout is clean and sits at
the revision its pin names. Both halves are cheap to compute, per package:

```
git status --porcelain      → empty?
git rev-parse HEAD          → equals the pin's revision?
```

So `workspace overlay status` should report, per overlaid package, one of:
**identical to pin** (parity holds), **clean but ahead/behind** (reproducible once
pushed and re-resolved), or **dirty** (this build is reproducible nowhere). The
third is not an error — it is the feature — but it must be *stated*, and it is the
answer to "which mode am I in".

Mode visibility must be read from SwiftPM's resolved state, never inferred from a
ledger. The existing `Workspace.Composition.verify` already does exactly this and
is the one piece of the current surface worth carrying forward.

---

## 6. Scale

Census of the real tree, enumerated rather than sampled:

| Fact | Value |
|---|---|
| Roster packages | **441** — all 441 materialized with a `.git` |
| Declared `url:` dependency edges | **2,188** |
| …resolving to a roster package | **2,054** |
| Requirement kinds | branch **2,137** · from **32** · range **19** |
| Highest in-degree | `swift-index-primitives` 64 · `swift-byte-primitives` 63 · `swift-standard-library-extensions` 62 |
| Largest manifests | `swift-kernel` 31 deps · `swift-tests` 28 · `swift-authentication` 26 |
| Pins in the flagship consumer | **200** (`Workspace/Application`) |

**The overlay is per-root and linear in that root's closure.** "All packages" is not
one global act; it is "every institute package in *this* root's closure", repeated
per root a developer builds.

Cost of applying it, measured: **0.47 s** per `swift package edit` in a 1-dependency
graph, **~1.8 s** in a 60-dependency graph. Two points is not a curve, but the
direction is clear — each invocation reloads the whole workspace, so the total is
`N × f(N)`, not `N × constant`. Extrapolated to a 200-pin root that is **between 6
and 20 minutes**, and I will not narrow that range from two points.

If it lands at the high end, there is a measured alternative: **a single
well-formed write of `workspace-state.json` is honoured.** Sixty edited entries
written in one pass, build green, all sixty local markers in compiled products,
canonical markers absent from products (present only as dormant `.build/checkouts`
clones — I checked, rather than assuming the grep hits were compiled output). One
write replaces N invocations.

I recommend this **only as a measured fallback, not as the default**: it writes
SwiftPM's private `"version": 7` state, which no compatibility promise covers, and
§4 shows the cost of getting its shape wrong is a whole-state discard behind a
warning. If it is needed, it must be gated by reading the state back through
SwiftPM's own view and confirming every intended package reports `edited`.

**Decide this with a measurement, not with this document.** Time one
`swift package edit` on `Workspace/Application` at 200 pins.

---

## 7. Limits, and two defects found on the way

**Eight packages do not gitignore `Packages/`.** In these, the overlay's own symlink
is committable by a routine `git add -A`:

`swift-percent-primitives` · `swift-authentication` · `swift-image-magick` ·
`swift-money` · `swift-resource-pool` · `swift-server-dependencies` ·
`swift-sitemap` · `swift-svg-printer`

The other 433 ignore it. `Package.resolved` is ignored and untracked in **all 441**.
Fixing these eight is a precondition, and it is worth doing regardless of this
design.

**Eight institute-org packages are depended on 86 times but are absent from the
roster, so the overlay cannot reach them.** Cause, checked against the GitHub API
rather than guessed:

| Package | Dependents | Why excluded |
|---|---|---|
| `swift-primitives/swift-tagged-primitives` | **66** | `fork: true` |
| `swift-foundations/swift-url-routing` | 13 | `fork: true` |
| `swift-foundations/swift-ip-address` | 2 | not eligible |
| `swift-webpage`, `swift-structured-queries-postgres`, `swift-domain-name-system`, `swift-email-html`, `swift-entitlement` | 1 each | `swift-entitlement` is `private`; others as above |

`swift-tagged-primitives` has **66 dependents** — more than any package on the
roster. The exclusion is `Workspace.Inventory.Eligibility.Reason.fork` working as
designed, and the roster is generated, so this is not drift. But it means **"all
packages" has a documented hole**, and closing it is a principal-level question:
*should institute-owned forks be materialized?* Until answered, the overlay's
coverage claim must be stated as *all roster packages*, never *all dependencies*.

**A third limit, structural rather than incidental: the overlay is root-scoped, and
it can outlive its reason.** An `edited` entry survives the dependency leaving the
graph — build green, entry retained, `Packages/` residue kept. Nothing compiles it,
so it is stale rather than wrong; but if that dependency is later re-added, the
developer inherits a live overlay they did not apply in this session. `status` must
report edited entries with no corresponding graph edge, and `remove` must sweep
them.

Also out of scope until measured, stated rather than glossed:

- **Xcode.** `institute.xcworkspace` is a committed artifact and I did not test the
  overlay under Xcode at all. Xcode does not inherit a shell environment, and it
  drives SwiftPM through its own workspace machinery. Untested — and it is the
  founding plan's §7.1 open question 7, still open.
- **CI.** Every statement here is about a local checkout. The overlay must be
  provably absent in CI, which is a check to write, not a property to assume.
- **Linux and any second toolchain.**
- **Two of the founding plan's nine spike questions are answered negative rather
  than unanswered** — isolated context scratch paths, and two coexisting contexts
  for one root (§4a). Any design inheriting that plan's context model must be told
  so, because it assumed both were available.

---

## 8. The alternative I tested and am not recommending

Since the objective is phrased as *"as if each `Package.swift` had local path based
dependencies"*, the literal reading deserved a real test: make the manifests
conditional. A `Package.swift` is Swift code; it can derive the hierarchy root from
`#filePath` — no configured path, no machine-specific input — and emit
`.package(path:)` or `.package(url:)` depending on an environment variable.

**It works, and it works better than SPM edit on the two axes that matter most:**

- One environment variable switches **the entire transitive closure** in a single
  build. Verified: with two levels of manifest conditional, both dependencies
  became `fileSystem` and local worktree source compiled. **O(1) at any scale** —
  no per-package command, no per-package state, no `N × f(N)`.
- **Zero local state.** Nothing to half-apply, nothing to leave behind, nothing to
  reconcile. §4's failure mode cannot occur.
- The manifest cache does not stale: flipping the variable re-evaluates.
- `Package.resolved`'s `originHash` was identical in both modes.

I am not recommending it, for reasons that are about the institute rather than
about the mechanism:

1. It requires **editing and committing all 441 manifests**, and every future one.
2. It makes every public manifest **evaluate differently by environment** — an
   external consumer reading these manifests now finds a second resolution mode
   that exists for our convenience. That is a permanent change to a public
   interface, in service of a local workflow.
3. **Xcode is unresolved and probably hostile.** Xcode does not inherit the shell
   environment; switching modes would need a scheme setting or a
   `launchctl setenv` — which is precisely the hand-configured, machine-specific
   state the constraint forbids. SPM edit has no such dependency: its state is
   files on disk that Xcode reads through SwiftPM like anything else.
4. The switch is an environment variable, so **"which mode am I in" becomes a
   property of the invoking shell** rather than of the checkout — the hardest kind
   of mode confusion to diagnose.

If the fleet later concludes the per-root cost of SPM edit is intolerable at 200+
pins and Xcode is dropped as a first-class consumer, this becomes the better
design. It is recorded here so that conclusion does not have to be rediscovered.

---

## 9. Proposed surface

Full Swift, in `Workspace Application`, no new shell or Python.

**Vocabulary reconciled with the founding plan rather than minted fresh.** Its §12
already specifies `workspace resolution plan | apply | status | verify | remote`
and a `workspace context` family. I proposed `workspace overlay …` before reading
it. **Adopt `workspace resolution`** — it is the adjudicated name for exactly this
concept, and a second vocabulary for one thing is the confusion this design is
otherwise trying to remove:

```sh
workspace resolution plan   [--package <name>]…   # inspectable, changes nothing
workspace resolution apply  [--package <name>]…   # single, multiple, or all
workspace resolution status                       # mode, parity, half-applied, stale entries
workspace resolution remove [--package <name>]…
```

I am **not** adopting the plan's `context` family. Its contexts assume isolated
per-context scratch paths and multiple coexisting contexts per root; §4a shows
`swift package edit` provides neither. A persisted context model built on a
mechanism that cannot isolate would be a name for something that does not exist.
One overlay per root, discovered rather than named, is what the mechanism actually
supports — and it is enough for *single, multiple, or all*.

The plan's §4.6 discipline applies unchanged and is why `plan` is a verb here:
formulate an inspectable plan, support dry-run, identify affected paths, refuse
unsafe states by default, be idempotent, and verify the postcondition.

Satisfaction of the founding plan's §4 invariants, which remain binding: **4.1**
committed manifests are never touched — measured, byte-identical throughout;
**4.2** explicit, inspectable, regenerable, removable, deterministically
reversible — `unedit` verified complete; **4.3** Workspace decides policy and
`swift-package-manager` executes the mechanics; **4.4** external consumers see
URL declarations unchanged, because nothing is committed; **4.5** satisfied by
`--fresh` (§4a), which is overlay-free by construction; **4.6** the `plan` verb.

- `apply` with no `--package` covers **every roster package in the closure** of the
  root it is run against. With `--package` it covers exactly those and their
  roster-resolvable dependencies. Single, multiple, and all are the same code path
  with a different selection.
- Inputs are only `Workspace.json` and `Workspace.Root` (checkout resolved
  physically, hierarchy = its parent). **No new configuration file, no new
  durable path.** `Workspace.Layout` already derives every checkout location; the
  overlay adds no second derivation.
- Refuses, naming the package, when: the checkout is absent; the package is
  off-roster; SwiftPM's own `edit` exits non-zero (unsatisfiable requirement). No
  quiet fallback to the resolved graph, ever.
- `status` exits non-zero on half-applied state and prints the parity table of §5.
- `remove` is `unedit` per package plus a symlink-residue sweep, and it verifies
  the resulting state reports `sourceControlCheckout` before claiming success.

**On the existing `compose` / `verify` / `restore`:** its mechanism — rewriting the
committed manifest with a machine-local absolute path, per dependency pair — is the
thing the objective rules out. It also fails the *"nothing machine-specific"*
constraint on its own terms, independently of the new objective: a manifest
carrying an absolute path is machine-specific state in a tracked file, and
`compose`'s own warning says so. That constraint is ruling 143, standing since
2026-07-26, so this is not a new judgement being applied retroactively. I recommend retiring `compose` and `restore` once
`overlay` lands, and **keeping `verify`'s approach**: reading effective source from
SwiftPM's resolved state rather than from a ledger is right, and it is the honest
core of `status`. I have not touched that code.

---

## 10. What I checked, and what I assumed

**Checked, by running it today:** everything in §2 (both controls, every row);
the `.build`-deletion degradation and the malformed-state discard in §4; `unedit`'s
completeness and the preservation of uncommitted dependency work in §5; transitive
edit; edit under `branch:`; edit's refusal on an unsatisfiable requirement; the
offline full-overlay build and its negative control; the batch state write and the
disambiguation of its grep hits; the conditional-manifest alternative including
transitive propagation and manifest-cache freshness; both loops in §3, with the
marker verified in compiled products every round; the full 441-package census, the
gitignore audit, the requirement-kind census, and the eight off-roster packages'
GitHub attributes.

**Assumed, and flagged:** that per-edit cost extrapolates from two points (it may
not — §6 says measure it); that SwiftPM parallelises branch-tip fetches, making the
96 s figure an upper bound; that the eight `Packages/`-unignored packages are the
complete set for `Packages/` specifically — I did not audit every ignore pattern
for other overlay artifacts.

**Also checked, after the first draft, because the earlier corpus was measured
under a different default:** the overlay under `--build-system native` as well as
the 6.4 default `swiftbuild`, in a clean room with the hit locations disambiguated;
the overlay at `swift-tools-version: 6.3.3`, the real manifest floor; `edit`'s
rejection of `--scratch-path`; the divergence between an overlay applied to the
default `.build` and a build given a custom scratch path; `Build.Coordinator`'s
scratch policy read from source (`freshScratch` returns `nil` unless `fresh`);
identity mismatch in the local checkout; and an edited package dropping out of the
graph.

**Not checked at all, and not to be read as safe:** Xcode under the overlay; CI
absence of the overlay; Linux; any toolchain other than Swift 6.4; and the real
`swift package update` cost at 200 pins, which §3 says decides whether this is worth
building.

**A second zero I refused, in the re-measurement pass.** The first
`--build-system native` run reported the local marker absent from `.build/debug`
— which would have been a headline finding: *the overlay does not work on the
deprecated build system.* It was the instrument. `.build/debug` is a symlink into
`arm64-apple-macosx/debug`, and neither `find` nor `grep -r` descended it. A
positive control — *can this probe find any known string in native's output at
all?* — returned empty too, which is what exposed it. Grepping the real path shows
the marker present. **The probe that reports "not found" and the probe that reports
"nothing to search" are the same output**, and one of them was about to become a
design conclusion.

**One instrument trap hit and corrected, recorded because it nearly entered this
document:** I first read exit statuses through `… | tail -5`, which reports `tail`'s
status. `swift package unedit` appeared to exit 0 on an error. Re-run unpiped it
exits **1**. Same class as the false green in `FIRST-RESOLVE-2026-07-28.md`, one day
later, in a session that had read that document.

**A zero I refused twice.** The §3 baseline loop reported the marker absent from
compiled products in three consecutive rounds. Both times the cause was the fixture,
not the finding — first a missing `origin`, then manifests copied with absolute URLs
still pointing at the original fixture. Had the instrument reported a clean pass
instead of a visible zero, a broken baseline would have been the headline number.
