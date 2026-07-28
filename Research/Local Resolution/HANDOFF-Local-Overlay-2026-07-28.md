# Handoff — the local overlay, 2026-07-28

Written at a clean boundary before a fleet refresh. The design is
`DESIGN-Local-Overlay-2026-07-28.md`; this records what is **not** in it — the
reasoning that lived in a conversation, the work that was withdrawn, and the
state a successor picks up.

---

## 0. The one thing to inherit

**This capability got smaller under adjudication, and every step of that came from
measuring something we had been asserting.**

No private state is written. No prohibition was overridden. Three of the four
safety gates dissolved because the thing they were guarding stopped existing. Two
supported mechanisms replaced one unsupported one. Five source files and a test
suite were written and then deleted.

None of that came from a better idea. It came from checking numbers that were
being quoted — an 18-minute apply cost that turned out to be the flagship consumer
against a median of 36; a per-edit cost extrapolated from two points; a byte-shape
requirement that no real file met; a prohibition described as an absence until
someone read its actual wording.

> **The instinct worth inheriting is not any fact about SwiftPM below. It is:
> withdraw the machinery when the measurement removes its justification.**

The facts in §5 will go stale with the next toolchain. That instinct will not.

---

## 1. Where it stands

**Design: complete, adjudicated, pushed.** Approved by the Team Lead, with the
principal's capstone (§4b) adopted as the acceptance criterion.

**Implementation: one increment landed.** `swift-foundations/swift-package-manager`
`ce4231b` — `edit`/`unedit` under a deadline, with lock contention named rather
than guessed. Verified: 5 tests, 1 suite, passed. Nothing else is started.

*Two compile failures preceded that green, both from writing against an assumed
API surface rather than a checked one:* `Duration` arriving as `internal` through
`internal import Process` under `InternalImportsByDefault`, so a `public func`
could not use it — fixed by naming `Swift.Duration`, which is what the parameter
always meant; and `termination(_:)` being file-private, fixed by widening it to
`internal` rather than writing a second mapping. Recorded because I had verified
the two APIs I was *suspicious* of and not the ones I assumed were fine, which is
the more common shape of this error.

**Withdrawn: the entire batch-write branch.** See §3 — this is the part most
likely to be re-derived by someone who does not read it.

| Layer | State |
|---|---|
| `swift-spm-standard` (L2) | **untouched.** Its prohibition on synthesising resolver state stands unamended |
| `swift-package-manager` (L3) | **landed, `ce4231b`** — `Package.Manager+Edit.swift`, `Error.locked` / `Error.timedOut`, classification tests |
| `Workspace Application` (L5) | **not started.** `workspace resolution plan/apply/status/remove` |

---

## 2. The architecture, in one table

Two jobs, two mechanisms, **both on supported interfaces**. A successor who reads
only one thing should read this:

| Job | Mechanism | Scale |
|---|---|---|
| **Developer inner loop** — change a package, test its consumers | `swift package edit --path`, per consumer | one edit, or a small working set |
| **Whole graph** — build everything from local source | a synthetic umbrella root nobody commits, plain `.package(path:)` | one root, 113 members |

Neither writes SwiftPM's private state. Neither modifies a committed manifest.
The retirement of `compose`/`restore` covers rewriting a **committed** manifest
with a machine-local path — it says nothing about a generated root.

---

## 3. What was withdrawn, and why — read this before rebuilding it

**The batch `workspace-state.json` write, and the `swift-spm-standard` encoder
that would have carried it.** Five source files and a test suite were written and
then deleted, uncommitted.

**Why it was proposed.** Applying the overlay costs `0.45 + 0.025N` seconds per
`swift package edit` against a graph of size `N` — measured at three sizes — so
applying it across a closure is quadratic. At `Workspace/Application`'s 200 pins
that is ~18 minutes, and a command nobody runs is not a capability.

**Why it was withdrawn.** Two reasons, in increasing order of importance.

The number was the worst case presented as the case. The closure-size
distribution across all 441 roster packages:

| | closure | whole-closure apply |
|---|---|---|
| **median** | **36** | **49 s** |
| mean | 53 | ~2 min |
| p90 | 122 | 7.1 min |
| max (`swift-identities-mailgun`) | 250 | 27.9 min |

**250 of 441 packages sit under 50.** The 18-minute figure was the flagship
consumer, not the typical one.

And the decisive reason, which is not about numbers: **overlaying a whole closure
inside a consumer is not what a developer wants.** The inner loop is *change X,
test the consumers of X* — one edit per consumer, everything else canonical, which
**is** the parity property the design exists to preserve. Wanting everything local
is the umbrella's job. That argument would hold even if the median had been 200.

**What that dissolved:** the batch write, the encoder, and three of the four gates
the Team Lead had mandated — fail-closed-on-version at write, read-back
verification, and the loud fallback all existed only to make a write safe. The
toolchain canary went with the encoder. Fail-closed-on-version was always the
*decoder's* job, and already lives there.

> **The prohibition it would have overridden.** `swift-spm-standard`'s decoder
> states: *"SwiftPM owns that file exclusively; nothing in this ecosystem may
> synthesise it, and offering an encoder would invite exactly the hand-editing of
> resolver state that is forbidden."* That is a prohibition, not a gap, and its
> stated reason is the precise hazard the mechanism creates. **It stands
> unoverridden. Do not reverse it without re-deriving §3's numbers.**

**The one genuine closure-scale case**, if you are looking for the hole: running a
package's *own tests* against an entirely local graph. `swift build` never compiles
test targets — 813 of 2,916, 28% of the tree — umbrella or not. It is rare, largely
covered by an umbrella proving the graph compiles, and tolerable at 49 s median.

---

## 4. The `swift-package-manager` increment, and why it is two error cases

`edit(_:path:at:timeout:)` and `unedit(_:at:force:timeout:)`, plus
`Error.locked(directory:)` and `Error.timedOut(directory:)`.

**Why a deadline at all.** SwiftPM takes an exclusive lock on the target package's
`.build` and, when it cannot acquire it, prints a waiting notice and then **waits
indefinitely**. It does not time out and it does not fail. An unbounded call is
worse than a failing one: a hang has no exit status, no diagnostic, and nothing to
report. On a machine running a fleet sweep it is the *expected* case.

**Why the implementation is smaller than planned.** I began writing a lock-file
probe and stopped when the APIs I was reaching for turned out not to exist — there
is no `Kernel.File.Lock.available`, no `Process.Sleep`. Checking rather than
assuming surfaced the better answer: **`Process.Configuration` already carries a
watchdog `timeout`** that `SIGKILL`s on expiry, reports `.signaled`, and preserves
stderr drained before the kill. No new dependency, no lock detection reimplemented.

**Why two cases rather than the one the Team Lead specified.** They asked for
expiry to be the named lock failure. SwiftPM prints its waiting notice *before* it
begins waiting, so the notice is in captured stderr and the outcomes are
distinguishable:

- notice present → `.locked(directory:)`
- notice absent → `.timedOut(directory:)`

Attributing *every* slow run to contention would be a guess presented as a
diagnosis. Both cases are loud and named, so the intent is met. **The Team Lead
ratified the split over their own wording; do not collapse it.**

**The bounded risk, stated because it is the kind that rots quietly.**
Discrimination reads a message SwiftPM owns and may reword. If the wording
changes, a locked run degrades from `.locked` to `.timedOut` — *a less specific
loud failure, never silence and never a false success* — and the timeout itself
does not depend on the message at all.

**The tests deliberately do not invoke `swift package edit` against a real
package.** Doing so would take the exclusive lock these operations exist to
survive, and a test that hangs on a busy machine is worse than no test. The
classification logic is tested directly; the invocation path is the same spawn
`dump(at:)` already exercises.

---

## 5. Facts a successor should not re-derive

Measured today against Swift 6.4 / Xcode 27.0. Full evidence and controls in the
design.

- `swift package edit --path` leaves `Package.swift` and `Package.resolved`
  untouched, works on **transitive** dependencies, works under `branch:`
  requirements (2,137 of 2,188 institute edges), and refuses an unsatisfiable
  requirement with exit 1.
- `unedit` is a **complete** reversal and preserves uncommitted work in the
  dependency worktree.
- **Deleting `.build` under an active overlay silently drops it** while leaving the
  `Packages/` symlink in place; the next build compiles canonical, exit 0, no
  warning. Reproduced on both `swiftbuild` and `native`.
- `swift package edit` **rejects `--scratch-path`** (exit 64), so a build given a
  custom scratch path cannot see an overlay. This composes correctly with the
  coordinator, which assigns a scratch path only under `--fresh` — making the
  documented pre-PR gate overlay-free by construction.
- **The overlay can be used offline but not applied offline.**
- **Four caches** must be cleared for any clean/offline/reverted claim:
  `Package.resolved`, `.build`, `.build/checkouts`, and the shared manifest cache.
- Conditional manifests were tested and rejected (§8a): the only Xcode-visible
  trigger — a generated sentinel file — turns the overlay **on** correctly and
  cannot turn it **off**, because SwiftPM's manifest cache is keyed on manifest
  content.
- **8 packages do not gitignore `Packages/`** — a ship precondition.

---

## 6. Two instrument notes, because they cost real time

**My own extraction was checked against the products trap.** The full-tree session
found 241 library products across 42 packages declared with symbolic constants,
invisible to any manifest grep. My closure figures came from grepping manifests, so
I re-ran against that failure mode: of **2,188** raw `.package(` occurrences,
**2,188** are `url: "literal"` and **0** are unaccounted for. The hole is in
*product* declarations, not *dependency* declarations.

That also bounds the warning: **the overlay never enumerates products.**
`swift package edit` takes a package *identity*, and identities come from the
generated roster and SwiftPM's own resolved state. The trap is decisive for the
umbrella and inert for the overlay — do not inherit it as covering both.

**The pipe cost me three things in one day**, the third after I had written the
lesson down and pushed it. False exit status, false "not found", and finally a run
I could not see at all because `tail` buffers until its input closes — a healthy
long-running process and a hung one produce byte-identical output, which is
nothing. Full account in `swift-institute/.github`
`.github/scripts/CONVERGENCE-DISCIPLINE.md` §11, coda. **A rule you have recorded
is not a habit you have formed.**

---

## 7. Next increment

1. **Commit the `swift-package-manager` work** once its tests are green.
2. **Layer 5:** `workspace resolution plan | apply | status | remove`, adopting the
   founding plan's §12 vocabulary. Its `context` family is declined — contexts
   assume per-context scratch isolation and multiple contexts per root, and
   `swift package edit` provides neither.
3. **`status` is the heart.** Two facts can disagree — the `Packages/` symlink and
   SwiftPM's `edited` entry — and SwiftPM will not reconcile them. `status` exits
   non-zero on any mismatch and prints the parity table; every overlay build runs
   that check first; half-applied is an error, never a fallback.
4. **Acceptance is §4b**, all three legs: overlay applied, no `Package.resolved`,
   no remote → green with local markers in products; **and** the same build fails
   with the overlay removed; **and** fails under `--fresh`. The first leg alone is
   passed by a warm `.build/checkouts` and proves nothing.
5. **Open, not blocking:** the umbrella experiment in the full-tree session, and
   whether a shared `--scratch-path` achieves module reuse with no new machinery.

**Not to be done without new evidence:** rebuilding the batch write, or reversing
`swift-spm-standard`'s prohibition.
