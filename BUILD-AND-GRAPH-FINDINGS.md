# Build and graph findings

**Measured 2026-07-28** against the 441-package roster. Every figure here is a measurement with a
timestamp, not a fact — date anything taken from this file and expect drift.

This record exists because the findings below cost a full session to establish and several of them
are invisible to per-package work. A successor who does not read this will re-derive them or
re-break them.

---

## 1. Public packages that cannot be built by the public

**Five private Institute packages are required by five public packages, across six dependency
edges.**

**State this as edges and distinct packages, never as a row count.** The table below has six rows
but names **five** distinct dependents — `swift-domain-name-system-kernel` appears twice, taking
both `swift-domain-name-system` and `swift-ip-address`. Reading the row count as a package count
produced a "six public packages" error twice, in two separate sessions, before it was caught.

| Private dependency | Required by (all public, non-archived) |
|---|---|
| `swift-webpage` | `swift-authentication` |
| `swift-email-html` | `swift-identities-mailgun` |
| `swift-entitlement` | `swift-products` |
| `swift-ip-address` | `swift-domain-name-system-kernel`, `swift-sockets-ip-address` |
| `swift-domain-name-system` | `swift-domain-name-system-kernel` |

**6 edges — 5 distinct private packages, 5 distinct public dependents.**

All five private packages verified `PRIVATE`, non-archived, non-fork. All five dependents verified
`PUBLIC`, non-archived — that second direction matters, because a private dependency is only a
defect if the dependent is public. Each private package is declared as a `.package(url:)` dependency
inside a public manifest, so naming them here discloses nothing that the public manifests do not
already.

**Population, because a count without one is how this went wrong twice.** The table was derived from
the **441 roster manifests only**. An independent measurement over a wider population — all **383
public repositories** across `swift-foundations`, `swift-primitives`, `swift-standards` and
`swift-institute`, including 286 nested `Experiments/` packages and 19 repositories not checked out
locally — found the **same six edges**, all library `.target` dependencies rather than test-only,
with **zero transitive additions**, under a grep carrying a positive control (285 of 286 matched a
must-exist string, so its zero is a real zero). Two different populations, same answer.

`CLAUDE.md` states that nothing in this repository needs Institute access, and that a step wanting
a repository you cannot read *"is a defect worth reporting"*. This is that report.

**A resolve performed by an authenticated member succeeds, which is why this was invisible.** Each
of the five dependents resolves fine for anyone with access. Per-package builds never force the
whole graph to resolve at once; the defect only appeared under a single root spanning all 441
packages.

It also bounds any "build the whole graph from local source with the remotes gone" goal: five
required packages are neither in the roster nor on disk. Publishing them, vendoring them, or
removing the dependencies is a decision, not a defect that tooling can fix.

## 2. The build coordinator serializes the whole machine

`Application/Sources/Build Coordinator/Build.Coordinator.swift` acquires an **exclusive** lock,
runs the entire SwiftPM invocation to completion, then releases:

```
POSIX.Kernel.Lock.lock(…, kind: .exclusive)
Process.Spawn.run(…)          // the whole build, including compilation
POSIX.Kernel.Lock.unlock(…)
```

There is no release-for-compilation. **Effective parallelism for coordinator builds is 1,
machine-wide, across every session.** Running N concurrent `workspace package build` invocations
does not speed anything up; N−1 of them sit at zero progress holding no work.

Consequences that are easy to get wrong:

- A full-tree figure derived from this is measuring **serialization**, not CPU. More cores do not
  move it. A naive 441-package sweep projects to ~57 hours; that is a mutex, not compute.
- Concurrent `swift-build` processes visible in `ps` are usually **not** coordinator builds. Check
  whether the parent holds the lock before concluding the coordinator allows concurrency.

  This was tested directly rather than assumed. A whole-graph build and a second `swift-build` were
  observed running at the same time, which appears to contradict the lock being held for the whole
  run. Resolving the parent of each against the set of lock holders showed otherwise:

  ```
  lock holders: 61716 only
    umbrella build        parent=workspace(61716)  COORDINATOR
    swift-authentication  parent=zsh(70080)        OUTSIDE — holds no lock
  ```

  The second build had a shell parent and no lock: it **bypassed the coordinator** rather than the
  lock being released for manifest evaluation. **Observed concurrency is evidence of bypass, not of
  a permissive lock.** It also means a session building in-tree with a bare `swift build` races
  every coordinated build on the machine without either party knowing.
- `--scratch-path`, `--build-path`, `--cache-path`, `--config-path`, `--security-path` and
  `-j`/`--jobs` are **hard-owned** by the coordinator and rejected from passthrough
  (`Build.Action.swift`). The only scratch control exposed is `--fresh`, which allocates an
  *isolated* scratch.

**Cross-root scratch sharing is therefore foreclosed by design. That question is answered, not
open.** A synthetic umbrella root is the sanctioned way to get shared artifacts, because one root
means one scratch by construction.

### Passing arguments through the coordinator

`--argument --build-system --argument native` **fails** with `Missing value for option '--argument'`
— the parser rejects a value beginning with `--`. The working form is:

```sh
workspace package build --package-path <p> --argument=--build-system --argument=native
```

Confirm the flag arrived rather than assuming: `--build-system native` emits a deprecation warning,
and **that warning is the positive control**. A passing build alone does not show the flag reached
SwiftPM rather than being silently dropped.

## 3. The roster graph

- **113 top-level packages** — nothing in the roster depends on them — and their transitive closure
  is **441/441 with zero uncovered**.
- **113 is a hard floor, structurally.** A package nothing depends on cannot be reached
  transitively, so *every* possible cover must contain all of them. This is a proof, not a greedy
  cover that happened to land there; an independently computed greedy cover produced the same 113.
- 37 packages have no in-roster dependencies at all.
- Declared surface: **2,916 targets — 2,085 library, 813 test, 9 executable, 9 macro** — and
  **1,607 library products** across 441 packages.

### 241 library products are invisible to grep

42 packages declare products with symbolic constants rather than string literals:

```swift
.library(name: .stripeTypes, targets: [.stripeTypes]),
```

Raw `.library(` occurrences: **1,609**. Parseable as string literals: **1,368**. **Invisible: 241,
across 42 packages** (`swift-stripe-types` 43, `swift-stripe-live` 41, `swift-stripe` 41).

**Any product enumerator built on `grep` omits those 241 and reports success.** Evaluate the
manifest instead — `workspace package dump-package` — and use literal parsing only where it is
provably complete.

**Boundary, which matters as much as the finding:** this is a hole in *product* declarations only.
Dependency declarations are string literals throughout — 2,188 raw `.package(` occurrences, 2,188
parseable, zero unaccounted. So it is **decisive for product enumeration and inert for
identity-based enumeration**. Do not inherit the broad version of this warning and build defensive
machinery nothing needs.

### Manifest identity

Five packages declare a manifest name differing from their directory:

| Directory | Manifest declares |
|---|---|
| `swift-certificate-verification` | `swift-certificates` |
| `swift-image-magick` | `SwiftImageMagick` |
| `swift-json-web-token` | `swift-jwt` |
| `swift-password` | `swift-password-validation` |
| `swift-time-based-one-time-password` | `swift-one-time-password` |

These did **not** block umbrella resolution. When extracting them, match `Package(\s*name:` — a
bare first-`name:` match returns a `.product(name:)` and silently reports the wrong identity.

## 4. What a `swift build` sweep cannot tell you

Four limits, all of which must be stated **beside** any pass/fail number rather than in a footnote.
A green sweep is compatible with an ecosystem that cannot be compiled in release on any current
toolchain.

1. **Test targets never compile.** `swift build` does not build them: **813 of 2,916 targets, 28% of
   the declared surface, untouched** — permanently, for any `swift build`-based verification,
   whatever the graph shape.
2. **Debug-only builds are blind to the release crash class.** `CrossModuleOptimization` runs only
   under `-O -enable-default-cmo`; `-Onone` never executes it. See `swift-institute/Issues#58`.
3. **Transitive coverage compiles only the products a consumer actually uses**, not every target in
   a dependency. Building N packages does not compile N packages' full surface.
4. **Shared caches are not cleared.** Without `--fresh`, every build shares `repositories`,
   `manifests` and `prebuilts` under `~/Library/Caches/org.swift.swiftpm`. "These packages build as
   the tree currently sits" is a different and lesser claim than "these resolved cleanly from
   canonical source".

On (4): the shared manifest cache is content-keyed and can serve stale results for manifests that
read ambient filesystem state. **Zero of 441 roster manifests do so** — checked with a positive
control for `Context.environment` and a negative control for `append(contentsOf:)`, which a looser
pattern had initially mis-reported as a hit.

## 5. Why a clean build is often not evidence

The most transferable lesson of the session.

A local release-mode probe of `swift-structured-queries-primitives` returned `rc=0`. **That result
was discarded rather than reported**, because the log contained **zero** occurrences of `-O`,
`-Onone` or `enable-default-cmo` — so it could not be shown that the configuration ever ran the pass
that crashes. A clean build from a configuration that never executed the failing pass is not a
negative result; it is an instrument that cannot return non-zero.

The re-probe forced `-Xswiftc -enable-default-cmo` and demonstrated three things before the clean
result was accepted:

```
enable-default-cmo : 756 occurrences      -Onone : 0
-O                 : 756 occurrences      Products/ : Release
Structured_Queries_Primitives compiled : 24 times   <- the module that crashes in CI
crash signatures : 0
```

The pass was enabled, the configuration was release, **and the specific failing module was actually
compiled** rather than skipped or served from cache. "Did it build" would have reached the same
conclusion on far weaker grounds.

Generally: **before believing a zero, show the instrument can return non-zero.** Applied across this
session it caught a `.gitignore` probe, a workspace absolute-path probe whose pattern did not match
the file's syntax, a manifest ambient-state probe, and a payload scan — each of which would
otherwise have reported a clean zero for the wrong reason.

### Verify by enumeration, not by exit code

`gh project item-add` returns **rc=0 whether or not it adds the item**. It silently no-opped once
during this session; the item was genuinely absent from the board's 98 entries. A retry worked. Any
automation trusting its exit status will drop items without a trace.

## 6. Sweep state at handoff

Full-tree debug sweep, **stopped by ruling** rather than completed.

- **14 of 441 recorded: 13 pass, 1 real failure.**
- The failure is `swift-linter`, but the fault is in **`swift-manifests`**:
  `thrown expression type 'Either<File.System.Read.Full.Error, Never>' cannot be converted to error
  type 'File.System.Read.Full.Error'` in `Manifest.Load.swift`. **Attribute failures to the
  repository owning the erroring file, not to the package being built** — otherwise one upstream
  defect inflates into N failing packages and the distinct-cause count is wrong.
- **6 results were discarded as instrument artifacts**, not defects: 4 `SIGTERM` from driver
  restarts, and 2 watchdog kills.
- Cover set stopped with **105 of 113 remaining**.

**The watchdog false-failure mechanism, which will recur:** the per-package watchdog timed from
process spawn, not from lock acquisition. Under a serial lock a queued build accumulates wall clock
while doing nothing, and gets killed as a failure with a **zero-byte log and zero resolved
checkouts** — that signature means starvation, not a defect. Raising the ceiling makes it rarer, not
correct. With queue depth bounded to one the worst case is (longest queued build + own build), which
against observed maxima is ~3,000s.

**This sweep cannot see the migration blocker.** It is debug, macOS-arm64, test-free and
swiftbuild-only, against a fleet whose CI is none of those.

## 7. Swift 6.4 status

The ecosystem is directed to move to Swift 6.4 and above. It is currently blocked.

- Compiler crashes on **6.3.3-RELEASE, 6.4-dev and 6.5-dev** — three toolchains, three modules, one
  configuration: release, `-O`, `-enable-default-cmo`, whole-module. Full record and evidence in
  **`swift-institute/Issues#58`**.
- **Not reproducible on macOS-arm64** (controlled negative, §5). Both OS and architecture differ
  from CI, so this establishes "not macOS-arm64", not "Linux-specific".
- **No reproducer can be produced on Apple hardware.** Reduction requires a Linux x86_64 container.
- Declared tools-versions are near-uniform (433 of 441 at 6.3.3, **zero** at 6.4), but a declared
  version says nothing about whether a package compiles under 6.4. The two questions are
  independent.

**The Apple CI legs avoid this crash class by omission, not by declaration.** They are debug because
nothing states otherwise, and are one `-configuration Release` away from it. Anyone adding a release
configuration to a simulator or macOS leg walks into this with no warning in the file.

## 8. The umbrella root

A synthetic root — committed nowhere — with `.package(path:)` on all 441 roster packages and a
single target depending on all **1,607** library products. Product names came from `dump-package`
for the 42 symbolic packages (42/42, no failures) and literal parsing for the other 399.

**Resolution succeeds:** `rc=0` in 6m52s. Three predicted failure modes did not occur — the single
duplicate product name (`"Server Dependencies"`, in both `swift-server` and
`swift-server-dependencies`) disambiguates via `.product(name:package:)`; the five manifest-identity
mismatches did not block; no platform conflicts arose.

**Path dependencies override URL dependencies by identity, completely: zero of the 441 roster
packages were fetched from the network.** Only third-party packages and the seven non-roster
Institute packages were.

### Correct behaviour that looks like breakage

The override is not silent. SwiftPM emits a `Conflicting identity` warning for every package where
a path dependency and a URL dependency resolve to the same identity:

```
warning: 'swift-xml': Conflicting identity for swift-array-primitives: dependency
'github.com/swift-primitives/swift-array-primitives' and dependency
'/…/swift-primitives/swift-array-primitives' both point to the same package identity
'swift-array-primitives'.
```

At roster scale this is **hundreds of warnings before a single module compiles** — over 320 observed
during manifest loading alone, still climbing when this was written. Resolution is correct: nothing
is broken, and the local path wins every time.

**Anyone using this mechanism must be told to expect them.** The first person to watch a whole-graph
build emit several hundred warnings will reasonably conclude something is wrong and stop. Correct
behaviour that presents as breakage is its own kind of defect, and the remedy is documentation
rather than suppression — suppressing them would also hide a genuine identity collision.

That override is the mechanism a "whole graph from local source" goal depends on, and it is the
reason §1 surfaced: the seven packages that *were* fetched are the ones not on disk, five of them
private.

**Depending on N packages is not building N packages.** SwiftPM compiles only the products actually
depended upon, which is why the umbrella must name products rather than packages. Verify a whole-
graph claim by counting distinct `-module-name` values in the build log against the 2,085 library
targets — a few hundred means a shortcut wearing a full-graph label.

**Whatever the umbrella reports, it is not evidence about 6.4** while it builds debug, and it never
builds the 813 test targets. "One build covers the whole ecosystem" and "6.4 is verified" are
unrelated claims.

### Status, and how to re-run it

**The build was started and then stopped by decision, not by failure.** At termination, after about
26 minutes:

| | |
|---|---|
| elapsed | ~26 min |
| identity warnings | **903**, across 182 of 441 packages |
| errors | **0** |
| modules compiled | **0** — still evaluating manifests |

**No module count was obtained, so no whole-graph claim is made here.** Nothing had gone wrong: at
182 of 441 packages in 26 minutes, manifest evaluation alone extrapolated to roughly two hours
before the first of ~2,085 modules, and under the serial lock (§2) that is two hours in which no
session on the machine can build anything. The mechanism was already demonstrated by the half that
succeeded — resolution, complete path-over-URL override, and the absence of the predicted failure
modes — so the remaining module count was judged not worth a fleet-wide build freeze on a shared
developer machine. **Prove it on a runner with no other tenants.**

The method is recorded so this is re-run rather than re-designed:

1. Enumerate roster paths from `Workspace.json` (`organization` + `layer`, authority orgs nesting
   under their layer root).
2. Enumerate library products **per package**: `workspace package dump-package` for any manifest
   declaring products symbolically, literal parsing only where provably complete. Do not grep — see
   §3.
3. Generate a root with `.package(path:)` per roster package and one target depending on every
   library product. Use `.product(name:package:)` throughout so the one duplicate name resolves.
4. `workspace package resolve` first — it reaches identity and duplicate-product failures in minutes
   instead of after a long compile.
5. Build, then count **distinct `-module-name` values** against the 2,085 library targets. Record
   load at both ends.

Expect: ~7 minutes to resolve, hundreds of identity warnings, and a long manifest-loading phase
before the first module. Under the coordinator's serial lock (§2) it also blocks every other
build on the machine for its whole duration, so it needs a deliberate window rather than an
opportunistic one.
