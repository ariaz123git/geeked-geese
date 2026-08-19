# Recent failures

**At most five. An entry leaves this file only when it has been turned into a
check, and it names the check that retired it.**

---

## What this is, and why it is capped

`CLAUDE.md` already carries a list of things that have gone wrong here — the
parser hang, the inside-out mesh builder, the goose that flew tail-first, the
four-second input lag. That list is permanent prose and it only grows. It is
also the file loaded into every session and every subagent, and instruction
adherence degrades with instruction **count**: the dominant failure is silent
omission, and what gets omitted is whatever is furthest down.

So this file is the *bounded* version, and the bound is the mechanism rather
than a tidiness preference. It is the shape Reflexion uses — write on failure
only, store the **diagnosis** and not the transcript, and hard-cap the buffer,
because past a few entries the reflections dilute each other rather than
compound.

**The cap is a forcing function.** A sixth failure cannot be written down until
a fifth has been converted into an assertion, a hook, or a deleted footgun. That
is the only way a lessons file gets *smaller*, and a lessons file that never
gets smaller is just `CLAUDE.md` with extra steps.

`tools/doctest.gd::_the_failure_log()` enforces both the cap and the dating.

## How to write one

```
### F-00N · YYYY-MM-DD · one-line title
**Symptom:** what you saw, including the wrong number if there was one.
**Diagnosis:** why, in one paragraph. Not the debugging story — the cause.
**Retires when:** the specific check or change that would make this impossible.
```

**"Retires when" is not optional and must be a specific artefact**, not "be
careful". If you cannot name the check, the entry is not a lesson, it is a
grievance — and it should go in `docs/HANDOFF.md` §4 with its arithmetic
instead, which is where evidenced-but-unfixed things live.

## How one leaves

Convert it, then delete it in the **same commit** as the check that retires it,
with the check named in the commit message. Never delete an entry any other way:
a silently dropped entry is a lesson unlearned twice.

---

### F-001 · 2026-08-18 · Two gates print `ERROR: N resources still in use at exit` and nothing looks
**Symptom:** `--probe --migtest` exits **0** with `[mig] PASS` and then prints
`WARNING: 34 ObjectDB instances were leaked at exit` and `ERROR: 17 resources
still in use at exit` on stderr. `--selftest` does the same intermittently, with
1 resource. `verify.ps1` reports both steps green.
**Diagnosis:** pre-existing, and **isolated to HEAD~2 by stashing** — not caused
by this session's changes, though building extra nodes makes it more likely. The
17 are `Music`'s 16 bed streams plus `Sfx`'s parking-lot ambience.
`Music._exit_tree()` exists specifically to release them and **it does run** —
confirmed with a temporary `print`. So the streams are held past that point by
something else, most plausibly AudioServer playback objects torn down after the
leak report. The reason nobody saw it for the life of the project is the reason
that matters: `verify.ps1` greps each step for its own `^\[tag\]` pass line and
checks the exit code, and **only step 7 looks for `SCRIPT ERROR`**. A gate can
print anything it likes on stderr and still be called green.
**Half retired, 2026-08-18:** every step in `verify.ps1` now fails on
`SCRIPT ERROR`, through one shared `ScriptErrors` helper, so a harness that
raises inside a branch its pass line does not depend on can no longer print
PASS and be believed.
**Retires when:** the remaining half is closed — the resource leak itself. Two
things were tried and measured. `Music._exit_tree()` **does run** (confirmed with
a temporary `print`) and nulls every bed stream, and an equivalent `_exit_tree()`
added to `sfx.gd` left the count at **exactly 17, `amb_parking_lot.wav`
included**, so it was reverted rather than shipped as a fix that fixes nothing.
The holder is therefore not the autoload caches; the remaining candidate is the
AudioServer's playbacks, torn down after the leak report. Until that is closed,
gating on `ERROR: N resources still in use` would make the build permanently red
for a known-open condition, which is how a check gets deleted.

### F-003 · 2026-08-18 · `add_child()` during `main._ready()` fails silently and hands back an empty node
**Symptom:** the first version of the leg-1 shelf check built the strip mall at
leg 1 and leg 2 and counted **zero** pickups in both, and reported a correct
filter as broken on both legs.
**Diagnosis:** `tools/selftest.gd::run()` is called from `main._ready()`, so the
scene root is still "busy setting up children". `add_child()` on it prints a
non-fatal engine error and **does nothing**; the node is returned, it is empty,
and every count taken from it is zero. The failure mode is the dangerous one —
the harness accuses the game, exactly as `probe_common.gd`'s header warns, and
the accusation is specific and plausible. Awaiting one frame fixes it, and then
exposes F-001.
**Retires when:** `tools/probe_common.gd` grows a `settled(tree)` helper that
every harness calls before it constructs anything, with the reason in its
docstring, and the trap list at the top of that file gains this as lesson 6.
