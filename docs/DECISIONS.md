# Decisions

The authoritative record of **decision status** for this project — whether a
thing is open, decided, or has been reversed. Other docs may discuss a decision
at length; they should link here for its *status* rather than asserting it.

> **Convention.** A lightweight, single-file variant of **Architecture Decision
> Records (ADR)** — the pattern from Michael Nygard's "Documenting Architecture
> Decisions," where each record is a dated, numbered, immutable entry and a
> reversal is a *new* record that supersedes the old one rather than an edit to
> it. That "supersede, don't edit" rule is the whole point: it makes reversals
> visible instead of silent. This is established practice, not a house
> invention. The single-file, low-ceremony shape is borrowed from the same
> author's other project — **an entirely separate repo**, `C:/projects/habitmaxxer`,
> whose `docs/decisions/DECISIONS.md` and `docs/README.md` are the working model.
> Nothing at that path exists in *this* repo; ours is `docs/DECISIONS.md`.

---

## Why this file exists here specifically

This project has a documented, expensive failure mode: **a constraint recorded
as prose keeps applying after it stops being true, because a comment cannot
run.** It has now happened three times that anyone has counted:

1. `main.gd::ROUTE` forbade a 230 s leg 7 because `DEPART_AT` was "written
   against a 180 s clock" — after `zone_truckstop.gd` had grown `_clock_scale()`
   and made that false. It blocked the change for a whole session.
2. `boss_ranger.gd` said leg 6's exam was unbuilt because "leg 6 does not exist
   yet" — after `zone_corn.gd` shipped the corn field.
3. `CLAUDE.md`'s own banner told every session that the game "has never had a
   human playing it" and that "the next real work is tuning", after a session
   had built the instruments to do that tuning.

A decision that lives only in prose, in a commit message, or in one person's
head is the same bug. **If you make a call, log it here in the same session.**

---

## How to use this file

**When to add an entry** — low-judgment trigger, and when in doubt write the
one-liner: whenever a choice is made or reversed about scope, a feel/pacing
number, an architectural rule, a verification standard, or anything a future
session would otherwise assume is still open (or still settled).

**Who decides what** — see `CLAUDE.md`, *"Taste is the human's. Everything
measurable is yours."* Entries owned by the human are marked **Open (human)**
and must not be quietly closed by an agent. Entries an agent decided are marked
with what it measured, and are revertible in one commit.

**Lifecycle**
- **Open → Decided:** update the *same* entry, flip Status, stamp the date.
- **Decided → Superseded / Reversed:** do **not** rewrite the old entry. Flip its
  Status to `Superseded by [ID]` and add a **new** entry on top. The old one
  stays as the record.

**Entry format**

```
## [ID] · [YYYY-MM-DD] · [short title]
Status: Open (human) | Open | Decided | Superseded by [ID] ([date])
Decision: one line — the choice
Why: one line — the reasoning, with the number if there is one
Refs: files, commits, docs
```

IDs increment. Newest on top.

---

## D-062 · 2026-09-25 · `verify.ps1` owns a wall-clock limit on every gate; F-005 retired
Status: Decided (agent)
Decision: All eleven gate invocations in `verify.ps1` go through one `Godot()` helper — `Start-Process` to temp files, `WaitForExit(limit)`, `taskkill /T /F` on timeout, then the last twelve lines printed and exit code 124. Limits sit above each step's in-engine failsafe (360 s; substances 720, flight 420); `-StepTimeout` overrides. A killed compile gate ends the run. F-005 leaves `docs/RECENT_FAILURES.md` in the same commit, retired by this helper.
Why: F-005 — a `main.gd` that will not parse hangs every gate forever, and the in-engine failsafe cannot help because it lives in `main.gd` too. **Canaried with the exact 2026-08-19 fault** (two statements joined onto one line): `-Quick -StepTimeout 45` killed the gate at 45 s, printed *"Parse Error: Expected end of statement after expression … (res://scripts/core/main.gd:136)"*, stopped, and left no Godot process running — 46 s end to end where it used to be forever. A normal full run through the helper then passed in 330 s with every PASS line intact. `taskkill /T` rather than `Process.Kill()` because the console build can run the engine as a child and Windows PowerShell 5.1 has no `Kill(entireProcessTree)`.
Refs: `verify.ps1` (`Godot()`, the compile-gate early stop, `-StepTimeout`); `docs/RECENT_FAILURES.md` (F-005 removed).

## D-061 · 2026-09-25 · Restart, pressed end to end, was already right — and is now held
Status: Decided (agent)
Decision: `inputtest::_restart_test()` builds a run worth losing — leg 3's zone, chaos banked, a goose dead, tolerance built, grass still running with `Engine.time_scale` at 0.92 — and restarts it twice: R, R through real key events, and RESTART RUN pressed twice (asserting the first press relabels it). After each it asserts leg 1, zero chaos, six geese, no tolerance, nothing running, time scale 1.0, leg 1's zone and a clock within 5 s of its 240, the zone running and the mission on leg 1. 113 checks → 134.
Why: A run is seven legs and about forty-five minutes, and the one control that throws it away had only ever been pressed ONCE by a harness (D-051 armed the prompt and backed out). Its reset is spread across five autoloads, and a restart that resets four of them is a new run that is secretly still the old one. **Both paths were correct**; this is a surface locked in, not a bug found, and it is recorded so nobody re-sweeps it.

Canaried by dropping `Subs.tolerance.clear()` from `Game.new_run()`: exactly two failures, the tolerance row on each path.

**Found in passing, not fixed:** `pause_menu.gd` says its confirmation is *"the same contract as the `R` key in main.gd, so the two ways of restarting behave identically"* — but the key's window is `RESTART_CONFIRM_MS` = 1500 and the button's is `RESTART_ARM_SECS` = 3.0. Which is right is pacing; they are just not identical.
Refs: `tools/inputtest.gd::_restart_test`, `::_dirty_run`, `::_run_state`; `scripts/core/game.gd::new_run`; `scripts/core/main.gd::_unhandled_input`; `scripts/ui/pause_menu.gd::_on_restart_pressed`.

## D-060 · 2026-09-25 · The director's menu watch could not see a menu
Status: Decided (agent)
Decision: `main.gd`'s per-frame `_menus_open()` poll moves from `_process()` to `_poll_menus()`, connected to `SceneTree.process_frame`. `inputtest::_pause_menu_test()` asserts the gameplay HUD and the objectives panel are hidden while the pause menu is open and the HUD is back after. 111 checks → 113.
Why: The poll's own comment: *"The pause menu opens itself on ui_cancel, so the director can't be told about it by a signal — poll instead."* It lived in `_process()` on `main`, which inherits PAUSABLE, and **every menu and card in the game pauses the tree** — so the poll stopped on the frame a menu opened and never once saw one open. Its job, per `_set_hud_visible()`, is hiding the HUD while a menu owns the screen; only the three paths that call `_set_hud_visible(false)` by hand (Almanac, Controls, Flock) ever did. Driven with Escape before the fix: *"gameplay HUD visible behind the menu = true, objectives = true"*. Found from a render, not a gate: the first render of the dose card showed a HUD clock reading **3:00 on a 240 s leg** behind it — the label's build-time placeholder, because the card had paused the tree before the HUD's first `_process` wrote the real time. That HUD should not have been on screen at all.

**Same shape as D-050**, one level up: a `process_mode` silently switching off the code whose whole purpose is to react to a pause. `SceneTree.process_frame` is emitted whether or not the tree is paused. The failing run before the fix was the canary; re-rendered after, the card sits over the dimmed zone alone.
Refs: `scripts/core/main.gd::_poll_menus`, `::_ready`; `tools/inputtest.gd::_pause_menu_test`.

## D-059 · 2026-09-25 · The dose hint is wired, as specced — decided without playing it
Status: Decided (agent) — **revertible in one line**: delete the `_first_dose_hint()` call in `substance_pickup.gd::_on_enter()`
Decision: `substance_pickup.gd::_on_enter()` raises `briefing.show_once(&"dose_hint", BRIEF_DEFS.dose_hint())` the first time the bird steps onto anything edible, unless a menu or card is already up. Harness runs mark the hint seen at boot (`main.gd`), so no measurement meets it mid-run; `briefing.gd` gains a public `mark_seen()` for that. `inputtest::_eat_test()` un-sees it, walks onto leg 1's grass, asserts the card appears and pauses the tree, closes it with Enter, and asserts the bird is still standing on the grass ready to eat. `--probe --brief-dose` photographs it. 108 checks → 111.
Why: The card that teaches the dose arc — the game's one input-timing skill, with a miniature of the HUD's own arc on it — was designed with this exact hook in `docs/ONBOARDING_NOTES.md` §5.4, specced to fire on leg 1 in `docs/CAMPAIGN_SPEC.md` §2.1 (*"the existing … `dose_hint()` cards fire here"*), and built. **Nothing called it.** `grep dose_hint` finds the definition, two docs and no caller. It is also the only card the Settings "Show hints" checkbox gates, so — with D-056's HUD half — that checkbox was dead twice over. Its first render (this session) reads correctly: nothing clipped, the arc in the green, the callout and FINE button clear.

**This is a feel call made without playing it, and it is said so here.** A modal the first time you stand on grass is exactly what the onboarding research this repo cites warns can read as friction; the docs argued it through (*"teach at the moment of use"*, one screen, never twice, honours Show hints) and chose it, and this implements their choice rather than a new one. If it grates in play, the revert is one line.
Refs: `scripts/world/substance_pickup.gd::_first_dose_hint`; `scripts/ui/briefing.gd::mark_seen`; `scripts/core/main.gd::_probe_if_headless` (harness pre-mark, `--brief-dose`); `tools/inputtest.gd::_eat_test`, `::_key`.

## D-058 · 2026-09-25 · The grid baseline retakes from somewhere else, and says what it hit
Status: Decided (agent)
Decision: `substancetest.gd::_the_grid()` retakes its sober diagonal from three lanes — the pad's centre, then 3 m either side of the path — reuses whichever came back clean for the dosed run, and prints the bodies the bird slid against on any disturbed attempt (a chaos prop by its `label`).
Why: A full verify failed on the SOBER baseline, all three attempts at **0.773 / 0.766 / 0.747 rad** — not the scatter of three shoves but one thing parked in the path, read three times from the same start. An axis-aligned box the bird slides along reads almost exactly PI/4. HANDOFF §4 already knew `hold_actors()` freezes cats and people and not loose carts; the retake loop added for it could beat a cart ROLLING through and could never beat one that had STOPPED. Proven, not assumed: an experiment wall across the centre lane read 0.785 and was named; the 3 m-right lane then hit an unnamed `RigidBody3D` already on the pad — a prop the earlier doses had pushed there — at **0.758**, the failing run's own signature; the left lane was clean at 0.000 and the gate passed. The experiment was removed. **Still open:** nothing stops props accumulating on the pad over a run, and the same class could reach the other channels that walk; this closes the one check that had failed on it twice.
Refs: `tools/substancetest.gd::_the_grid`, `::_diagonal`, `_diag_hits`; HANDOFF §4 "`hold_actors()` freezes the ACTORS and not the PHYSICS".

## D-057 · 2026-09-25 · The share key has two handlers, and D-032 fixed one of them
Status: Decided (agent)
Decision: `goose_controller.gd` owns the one share cooldown and exposes `share_ready()` / `spend_share()`. `flock_pen.gd::_share_nearby()` asks `share_ready()`, counts a pen goose only if the dose actually MOVED it, and spends the cooldown when it pays. `inputtest.gd` runs the share test twice — wherever the bird is, and 1.2 m from a non-DD pen goose on purpose — and asserts the same invariant at both. 105 checks → 108.
Why: Found by a canary run for D-056 that failed two checks it had no business touching: *"three share presses inside a 1.00 s cooldown fired the verb 3 times"*. The share key is handled twice — the pen in `_input`, first, whenever a pen goose is within `SHARE_RANGE` (5.0 m); the controller's blanket share in `_unhandled_input`, only for what the pen lets through. **D-032 added the cooldown and the "moved somebody" check to the controller's path and gave the pen neither**, while the pen's own comment claimed the two were *"kept identical so the key never behaves differently depending on where you're standing"*. Pinned at the pen, the unfixed build fired **3 times in 6 frames** and paid **once for a saturated flock** — 60 + 22 per bird in reach, on every press, forever. The gate's share test had passed for its whole life because the previous test usually left the bird about 7–8 m from the nearest pen goose: **2–3 m of margin against a 5 m range** was the only thing keeping it green, and on the run that failed, the bird had drifted inside it.

This is the handoff's own warning in new clothes — *a counting bug fixed by adding a second emitter is not fixed until the first is gone* — with "handler" for "emitter". **When a verb has two handlers, a fix to one is half a fix, and a test that does not pin which handler it reaches is testing the dice.**

Canaried twice: the unfixed pen failed both at-pen checks (mash and saturated); with only the pen's `spend_share()` call disabled, exactly one (the mash).
Refs: `scripts/goose/goose_controller.gd::share_ready`, `::spend_share`, `::_unhandled_input`; `scripts/world/flock_pen.gd::_share_nearby`; `tools/inputtest.gd::_share_test`, `::_pen_spot`, `::_pen_distance`.

## D-056 · 2026-09-25 · Every row of Settings, driven by hand, and four of them did not do what they said
Status: Decided (agent)
Decision: `inputtest.gd::_settings_walk()` walks the Settings panel with the D-pad, moves each slider five presses, toggles each checkbox with A, picks Classic through the Art style popup, and asserts the **consumer** of each row — the camera's sensitivity, FOV and invert flag, all three buses, Juice's shake and FX scales, the HUD's FX, the objectives panel, the goose, the cats and the people. Four fixes: `pause_menu.gd::_chain_focus()` gives the rows an explicit D-pad order; `_step_focused_slider()` moves a focused slider one twentieth of its range; `cat.gd` and `npc_human.gd` rebuild their visual on `pref_changed`; `mission_hud.gd::set_host_visible()` composes "a menu is up" with the Show hints pref instead of `main.gd` overwriting `visible`. 70 checks → 105.
Why: **Shipped as a report and read before it was armed**, and its first run found four real things:

| row | measured |
|---|---|
| Invert Y, Show hints | **unreachable on a pad.** D-pad down went art style → six sliders → BACK. A CheckBox sits at the left of its row and a slider in the middle of the next, and Godot's geometric guess skipped both checkboxes |
| every slider | **95–100 presses end to end** on a pad: a focused Slider moves by `step`, 0.01, and pad buttons do not auto-repeat. Now 17–20 |
| Art style | *"Cats and people follow the goose. Takes effect immediately."* The goose did; **7 of 7 cats and 9 of 9 people** stayed low-poly until the next zone |
| Show hints | **OFF held until the menu closed.** `main.gd::_set_hud_visible()` wrote the panel's `visible` on every menu open and close, so resuming from the menu you turned it off in put it back |

The last session recorded `show_hints` as *"checked and innocent — re-reads on pref_changed"*. The listener is real and was never the problem; a **second writer** of the same property was. Checking that a consumer listens is not checking that nothing else writes after it.

**A Godot 3 API got in, and the compile gate passed it.** The first slider fix set `HSlider.custom_step`, which 4.7 does not have (`ClassDB` lists only `step` on `Range`, nothing on `Slider`) — it raised `SCRIPT ERROR` on every row at run time and the walk saw no sliders at all. A property write on a native-typed variable is resolved at run time, so `--gate` cannot see it; `verify.ps1`'s `SCRIPT ERROR` check on every step can. Raising `step` instead would have coarsened the mouse drag and knocked FOV's 68° default off its grid, so the menu takes left / right itself.

**Canaried in two runs:** chain + cat and person listeners removed → exactly 3 failures (both checkboxes unreached; 7 of 7 cats; 9 of 9 people). Slider step + host visibility removed → 8 (seven sliders at 50–100 presses; Show hints after the close).

**The same canary run surfaced something unrelated, and it is D-057.**
Refs: `scripts/ui/pause_menu.gd::_chain_focus`, `::_step_focused_slider`; `scripts/world/cat.gd::_on_pref_changed`, `::_build_visual`; `scripts/world/npc_human.gd` (same, plus `_vis` held by reference); `scripts/ui/mission_hud.gd::set_host_visible`; `scripts/core/main.gd::_set_hud_visible`; `tools/inputtest.gd::_settings_walk`, `::_style_counts`, `::_far_value`.

## D-055 · 2026-09-25 · A pad can get through the game, not just around one zone
Status: Decided (agent)
Decision: `Game._setup_input()` binds pad **Start → `ui_cancel`** (pause) and pad **A → `ui_accept` and `gg_skip`** (confirm / continue). `pause_menu.gd` gives RESUME focus on open, the Art style picker focus on SETTINGS, and SETTINGS focus again on BACK. `briefing.gd::DISMISS_ACTIONS` gains `gg_honk`, so B closes a card. The flight card reads `[ENTER · A]`; the README, the pause menu's control table and the control card name Start. `inputtest.gd::_gamepad_walk()` drives it with `InputEventJoypadButton`s only. 56 checks → 70.
Why: The README advertises a gamepad scheme and every VERB on it worked. Nothing had checked whether a pad could get a player THROUGH the game. Printed from the engine, not remembered: Godot 4.7.1 binds `ui_cancel` to **Escape alone** and `ui_accept` to **Enter / Keypad Enter / Space alone**, and `Game.ACTIONS` gave `gg_skip` no pad button. So on a pad there was no pause (and so no settings, Almanac or quit); the roster and control card, which close on those three actions, could not close; and **the flight's own results card — `[ENTER]`, waiting on `gg_skip` with no timeout — was a wall at the end of flight 1**. The walk found the roster soft-lock by accident on its first draft, which killed a bird before ending the leg and stalled right after the results card without being able to say why.

**The first hypothesis was the opposite bug, and it was wrong.** Older Godot bound `ui_cancel` to pad B, which would have made every honk open the pause menu. The same printout refuted it. That is also why B is **not** a back button now: the menu opens and closes on one action, so B on `ui_cancel` would pause the game on every honk.

**Two prose claims were false for the same reason.** `briefing.gd` said *"ui_cancel is Escape/pad-B"* and `docs/ONBOARDING_NOTES.md` rule 1 says every card closes on *"gamepad A, gamepad B"*. B did nothing to a card. Both became true when `gg_honk` joined the dismiss list, and the walk now closes the flight briefing with B so they stay true.

**Canaried per binding:** before the fix, 4 failures (Start, focus, B ×10 presses, never reached the flight). With only `gg_skip`'s A removed, exactly one (*"fired `finished` 0 times"*). With only `ui_accept`'s A removed, the Almanac check names the cause and two cascade after it.

**One guard was written, canaried and removed.** A focused Button answers `ui_accept` — Space, the flap — so a closed menu still holding focus (say, on an armed RESTART RUN) would be a hazard, and `_close()` released focus explicitly. With the release disabled, nothing was focused after the close anyway: **Godot 4.7.1 releases a Control's focus when its CanvasLayer hides.** A release that changes nothing is not a guard, so it was deleted, the comment says what was measured, and the walk reports where focus is after a close rather than asserting it.

**Side effect, and it is the point:** a keyboard player can now walk the pause menu with the arrows, and Space / Enter press what is focused — one press of Space resumes.
Refs: `scripts/core/game.gd::_setup_input`; `scripts/ui/pause_menu.gd::_focus`, `::_back_from_settings`; `scripts/ui/briefing.gd::DISMISS_ACTIONS`; `scripts/migration/migration.gd::_finish`; `scripts/ui/control_card.gd`; `tools/inputtest.gd::_gamepad_walk`, `::_pad`; `README.md` controls.

## D-054 · 2026-09-25 · The gates stop sharing a save file with the player
Status: Decided (agent)
Decision: `Prefs` is **hermetic** in any run launched with arguments after `--` — it starts from `DEFAULTS` and never writes `user://geeked_geese.cfg`. `main.gd::_probe_if_headless()` force-closes the first-run briefing before dispatching any harness, `probe_common.fresh_goose()` refuses a paused tree, and `migtest::_enter_flight()` closes the flight's own first-run card where it actually appears. `verify.ps1` hashes the player's save (content + write time) before step 1 and after the last step and fails if they differ; the compile gate prints `OS.get_user_data_dir()` so that path is confirmed by the engine rather than guessed. That verdict is gate 13.
Why: The save on the machine this is built on read **`best_chaos=131201955`** — no human run reaches that, so the pause menu's BEST CHAOS line was dead for the one person who reads it — and **all 17 substances `unlocked`**, because the `--ui` and `--finale` render probes unlock five and six entries to photograph them and the substance gate doses everything. The Almanac is a discovery mechanic and it had been fully spent by harnesses. Both first-run briefings were marked seen, because `--probe` force-closes the card and closing a card is what records it. A full `verify.ps1` rewrote the file on every run (write time moved Sep 20 → Sep 25 01:24 with identical content during this session's baseline), and `audiotest` round-trips each volume slider through 0.25 and 1.00, so a harness that died mid-way left the player's volume wherever it stopped.

**It also ran the other way, and that is the bigger finding.** Every gate READ the player's save, and three of them only passed because of what it said. Made hermetic — which is exactly a fresh checkout — `inputtest` failed **8 of 36** (*"holding forward for a second moved the goose 0.00 m"*), `feeltest` reported **all 13** windows at 0.00, and `migtest` spent **1241 physics frames** paused behind the flight's first-run card and measured every flight channel at 0.00. The briefing re-asserts `paused` every frame, so `migtest`'s per-tick unpause could never win. On any machine where nobody had dismissed those cards, the first `verify.ps1` would have accused a healthy controller, and the second would have passed — because the first one had just dismissed them.

**Keyed on "any user argument", not on a list of flags,** so a harness added tomorrow is hermetic without anyone remembering to list it. A player launching the game has none.

**Canaried by setting `hermetic = false`:** `verify.ps1 -Quick` failed on **exactly one** verdict, the new one, naming the file — and the two stamps it printed had the **same SHA-256** and different write times. A hash-only guard would have passed that canary, because the old bug rewrote identical content on most runs. The write time is the half of the check that does the work.

**Not touched: the player's file itself.** Its polluted values are still on disk (`best_chaos`, `unlocked`, `seen_briefings`); which of them a human earned cannot be told apart. Recorded in `docs/HANDOFF.md` §3 for the human, with the one-line reset.
Refs: `scripts/core/prefs.gd::hermetic`; `scripts/core/main.gd::_probe_if_headless`; `tools/probe_common.gd::fresh_goose` (lesson 9); `tools/migtest.gd::_enter_flight`; `tools/gate.gd` (user data line); `verify.ps1` (the snapshot at the top, step 13).

## D-053 · 2026-09-20 · The SFX volume slider was connected to nothing
Status: Decided (agent)
Decision: `sfx.gd` creates an `SFX` bus sending to Master and routes all 17 players to it; `prefs.gd` gains a public `apply_audio()`; `sfx.gd` and `music.gd` both call it once their buses exist. `audiotest.gd::_the_volume_sliders()` asserts the buses exist, that every SFX player is on the SFX bus, and that moving each slider moves its bus. 246 checks → 254.
Why: `pause_menu.gd` offers Master, SFX and Music sliders. `prefs.gd::_apply_audio()` writes each to a bus **by name** — and nothing in the project ever created a bus called `SFX`, while `sfx.gd` routed every player to `"Master"` directly. `AudioServer.get_bus_index()` returns `-1` for a missing bus **without raising anything**, so the branch was skipped in silence. Measured before the fix: *"bus SFX index=-1"*, *"sfx players on the SFX bus: 0 of 17, elsewhere: Master: 17"*. **The slider moved a number nobody could hear.**

**This is the `stamina_restore` shape for the third time** — an exported control that nothing consumes, passing every gate because no gate asked whether the far end was attached. D-047 caught it in a substance field, D-051/D-052 in unreachable UI, and this one in an options menu.

**A second bug came out with it: boot order.** `Prefs` is autoload #1 and calls `_apply_audio()` in its own `_ready()`; `Music` is #10 and creates the Music bus long afterwards. So a saved music volume was written to a bus that did not exist yet and the game came back at full music until the player touched the slider again. Both `Sfx` and `Music` now re-apply once their buses are up, through the new public seam rather than by reaching for the underscore method.

**The third assertion is the one that survives a refactor.** Bus-exists and players-routed are both about today's plumbing; *"move the slider 0.25 → 1.00 and the bus moves more than 3 dB"* stays true however the volume is wired. All three read −12.0 dB → +0.0 dB now.

Canaried by putting the pool players back on Master while leaving the bus in place: **exactly one** check failed (*"16 of 17 Sfx players are not on the SFX bus"*) and bus-exists stayed green.
Refs: `scripts/core/sfx.gd::_ensure_sfx_bus`, `SFX_BUS`; `scripts/core/prefs.gd::apply_audio`; `scripts/core/music.gd::_setup_buses`; `tools/audiotest.gd::_the_volume_sliders`.

## D-052 · 2026-09-20 · The pause menu's buttons, which nobody had ever been able to press
Status: Decided (agent)
Decision: `inputtest.gd` opens the pause menu with Escape and presses ALMANAC, CONTROLS and FLOCK through `Button.pressed`, asserting for each that the overlay opens, the menu hides, the tree stays paused, Escape closes the overlay, and the menu comes back. 41 checks → 56.
Why: D-050 means those buttons had **never been clicked — not by a player, not by a probe, not once**, because the menu could not open. The handoff behind each (suppress the menu, open the overlay, hand the screen back on `closed`) is three signals wired in `main.gd::_build_overlays()` and had never run outside the render probe.

**Pressed through `Button.pressed`, not by calling the callback.** The wiring is the part most likely to be wrong; invoking the lambda directly would skip exactly the thing under test.

**All three were already correct.** That is the result, and it is worth having: this is a surface the game HAS, that nobody could reach, now held by assertions. An unwired signal is a dead button that raises no error anywhere.

**The canary discriminated cleanly.** Unwiring `almanac_requested` produced three failures (opens, hides, comes back — they cascade). Unwiring only `control_card.closed` produced **exactly one**: the control card still opened, and only *"menu back=false"* fired. FLOCK stayed green through both. A check that fails everything when you break one thing is not localising, and this one does.
Refs: `tools/inputtest.gd::_menu_buttons_report`, `::_find_button`; `scripts/core/main.gd::_build_overlays` signal wiring.

## D-051 · 2026-09-20 · Every key a player presses, pressed through the viewport
Status: Decided (agent)
Decision: `inputtest.gd` sweeps the keys no harness had ever sent — TAB (`gg_objectives`), R (`gg_restart`) and J (`gg_cam_left`) — through `Input.parse_input_event()`, and asserts each. 30 checks → 41.
Why: D-050 found the pause menu dead because nothing had ever pressed Escape. **The pause menu was simply the first key anyone checked**, and the other three run through `_unhandled_input`, which fires only on events that reached the viewport un-consumed — the exact path that was broken.

**All three turned out to work**, which is a result and not a wasted pass: they are now locked in, and the class of bug that killed the pause menu cannot take them silently.

**Shipped as a report, then armed**, which is the order this project uses. Read across five runs: TAB cycled `[0, 1, 2, 0]` every time, R took the prompt false → true every time, J moved the yaw 0.331 rad in 20 frames. Only then did they become `_ok()` calls.

**TAB gets two assertions, not one, and the canary proved why.** The lap check (three presses return to the start mode) passes on `[0, 0, 0, 0]` — a completely dead key is a valid lap. It takes a second assertion, that the FIRST press changed something, to catch it. Watched failing by disabling both handlers with `if false and …`: TAB reported `[0, 0, 0, 0]` and R reported `false -> false`, and the two live assertions named them.

**The pause-menu test gained a clean-screen guard on the way.** One run failed 2-of-35 and could not be reproduced in five more. Unproven, but the mechanism is known and cheap to exclude: every overlay consumes `ui_cancel` and `briefing.gd` lists it in `DISMISS_ACTIONS`, so a briefing card up at the wrong moment eats the Escape and the menu never sees it — failing `opened` and `paused`, which is exactly 2. The test now clears the screen first and calls it a HARNESS fault if it cannot, rather than delivering a verdict on the menu.

**Found in passing:** J and K orbit the camera, are in `Game.ACTIONS`, and are **absent from the README's control table**. A player finds them by accident or not at all. Not fixed here — it is a documentation call.
Refs: `tools/inputtest.gd::_ui_sweep_report`, `::_press`, `::_pause_menu_test`.

## D-050 · 2026-09-20 · The pause menu could close itself and never open itself
Status: Decided (agent) — **found by the human, in real play**
Decision: `pause_menu.gd` sets `process_mode = PROCESS_MODE_ALWAYS` instead of `PROCESS_MODE_WHEN_PAUSED`. `inputtest.gd::_pause_menu_test()` presses Escape **through `Input.parse_input_event()`** and asserts the menu opens, the tree pauses, and a second press gives the game back.
Why: `process_mode` gates `_input()` exactly as it gates `_process()`. Under `WHEN_PAUSED` the node is inert whenever the tree is running — and **the only thing that pauses the tree is `_open_menu()` itself**. So Escape did nothing, for the life of the project, and with it went everything behind the menu: settings, the Almanac, the control card, the flock roster, restart. The README advertises all of it.

**Twelve gates were green while this was broken, and the reason generalises.** *Nothing in this project had ever sent an input event through the viewport.* Every harness either calls `Input.action_press()` — which sets action STATE and never produces an `InputEvent`, so no `_input()` anywhere fires — or calls a handler directly. `main.gd`'s own restart probe does the latter: `_unhandled_input(rev)`, invoked on main, which proves the handler works and proves nothing about whether the event reaches it. That is the same shape as D-047's eating verb: **the method was tested, the path was not.**

**The bug was its own canary.** The check was written first and run against the unfixed code: *"escape: open=false paused=false"*, two checks failing. Nothing had to be armed.

**`almanac.gd` is also `WHEN_PAUSED` and that is correct** — checked, not assumed. It is only ever opened from `pause_menu.almanac_requested`, which fires while the tree is already paused (`main.gd:202-208`), so it is active exactly when it needs to be.

**A second press is asserted, not just the first.** `_open_menu()` sets `get_tree().paused` and `_close()` clears it; a menu that strands the tree paused stops every zone, flight and timer with no way back, and is the same bug wearing the other shoe.
Refs: `scripts/ui/pause_menu.gd::_ready`; `tools/inputtest.gd::_pause_menu_test`, `::_escape`.

## D-049 · 2026-08-19 · A deadline that starts after the risky part is not a deadline
Status: Decided (agent)
Decision: The headless failsafe moves out of `_probe_if_headless()` into `_arm_headless_deadline()`, called from the **top** of `main.gd::_ready()`. `selftest::_the_failsafe_is_first()` asserts the ordering by reading the source.
Why: `_arm_failsafe()` exists so a headless run cannot become *"an invisible process that outlives the shell that started it"* — its own words. It was armed inside `_probe_if_headless()`, which is the LAST statement of `_ready()`, so a stall in `_build_overlays()` or in the first zone `Game.new_run()` builds ran with no deadline at all. Zone construction is the largest body of code in this project and the likeliest thing to hang; it was the one part the failsafe did not cover. `docs/HANDOFF.md` §4 recorded it.

**Checked by source order rather than behaviour, deliberately.** Proving it at runtime means hanging the build on purpose and waiting out the timer, which is a check nobody keeps. Same idiom as `_the_hitstops()`: read the file, assert the shape. Watched failing by moving the call back next to `_probe_if_headless()` — it names both lines.

**THE FIRST VERSION OF THAT CHECK FAILED ON CORRECT CODE, AND THE REASON IS WORTH KEEPING.** It searched the raw text, and the comment ABOVE the arming call explains what would otherwise run unguarded — naming `_build_overlays()` and `Game.new_run()` while doing so. **A source-order check that a comment can break is a check that punishes explaining yourself.** It now walks lines, skips comments, and matches statements at the start of a stripped line.

**And this landed via a 20-minute detour that found something CLAUDE.md did not say.** A swallowed newline joined `_build_overlays()` to the next statement; `--gate` then printed **nothing at all** and never exited, which CLAUDE.md attributes only to a parser hang. It was an ordinary parse error: `main.gd` would not load, so the gate never ran, `tree.quit()` was never called, and the process sat alive — while the documented `grep '^[gate]'` filter threw away the `Parse Error ... at main.gd:136` that said so. **The failsafe cannot cover that case either, because it lives in `main.gd`.** CLAUDE.md now says to re-run without the filter first, written at the same line count as before.
Refs: `scripts/core/main.gd::_arm_headless_deadline`; `tools/selftest.gd::_the_failsafe_is_first`; CLAUDE.md *"The parser can HANG on an edit"*.

## D-048 · 2026-08-19 · An itemisation has to be in the same currency as the thing it itemises
Status: Decided (agent)
Decision: `Mission._complete()` records `paid` — the movement in `Game.chaos` across its `Game.score()` call — and `evaluate_leg()` sums that instead of the raw `reward` fields. `selftest::_the_itemisation()` drives one objective through `_complete()` at combo 7 and asserts the two agree.
Why: The results card prints *"includes N from objectives"* under a CHAOS figure that is fully combo-multiplied, and N was the sum of the raw `reward` exports. Every objective actually pays `reward × chaos_mult × (1 + 0.12 × (combo - 1))`, so the itemisation was **smaller than its own share of the total, and got further out the better the player chained** — backwards from what a scoreboard is for. `docs/HANDOFF.md` §4 recorded it.

**Read off `Game.chaos` across the call rather than recomputing the multiplier.** A second copy of that arithmetic in `mission.gd` is a second thing to keep in step with `game.gd`; a delta cannot drift. `_combo_milestone()` was checked and only shakes and sparkles, so the delta is the objective's payout and nothing else.

**The check runs at combo 7, and that is the whole check.** At combo 1 the multiplier is 1.0 and raw and paid are identical, so a check without a combo passes on the broken code — the same trap `_the_result_clocks()` avoids by demanding two legs whose clocks differ. Watched failing by setting `paid = reward`: *"recorded `paid` as 100 and Game.chaos moved by 172"*, which is 100 × 1.72 exactly.
Refs: `scripts/core/mission.gd::_complete`, `evaluate_leg`; `tools/selftest.gd::_the_itemisation`; `scripts/ui/results_screen.gd` CHAOS note.

## D-047 · 2026-08-19 · Something finally eats through the key
Status: Decided (agent)
Decision: `inputtest.gd` gains `_eat_test()`: the goose walks onto leg 1's infinite grass, holds `gg_eat` to three different charges, and releases. It asserts the charge arc is a clock, that each of the three doses scores the label its band deserves, that the substance goes active, that `stamina_restore` lands, and that walking off mid-hold drops the charge and scores nothing. 8 controller checks → 30.
Why: `docs/HANDOFF.md` §4 named this precisely: *"Every harness reaches into `Subs.take()` directly, so `_tick_eat`'s charge arc, the sweet-spot band, the abort, the pickup's `consumed()` and the SWEET SPOT / OVERDOSE / BARELY ANYTHING scoring have never been driven by a key."* That is the game's core skill expression — `_tick_eat`'s own comment calls letting go at the right moment *"its only real input-timing test"* — and it is why `stamina_restore` could be dead in six `.tres` files with every gate green.

**Grass, and the choice is load-bearing.** It is `infinite` in leg 1 so one pickup survives all three releases; it is in the tutorial shelf so it exists at leg 1; its band is wide (0.35–0.85) so three doses sit clear of both edges; and it restores 0.25 stamina.

**The holds are to a CHARGE, not to a frame count, and the first draft got that wrong in a way worth keeping.** `_eat_charge += delta / charge_time` looks like 1/84 per frame at 60 Hz, and the first dose measures exactly that — 0.202 in 17 frames. The second and third came in at 0.545 and 0.838 where the frame count predicted 0.607 and 0.952, and the harness called the game broken. **Grass sets `time_scale` to 0.88.** Once the first dose lands every `delta` is 12% shorter, so the arc is still a clock — in GAME time, which is the only clock the player is in. Holding to a target is immune; the clock is then checked separately against game time accumulated the same way.

**The stamina is set on the frame before the release, and that detail is the check.** `regen_ground` over a 91-frame hold adds more than the 0.25 being looked for, so a before/after spanning the whole hold would have passed on regen alone. Measured across the release frame: **+0.260** against a declared 0.25, the extra being two frames of regen.

Watched failing twice. Killing the restore line — the exact shape of the bug that left it dead — reports all three doses moving stamina 0.010 instead of 0.25. Removing the band's floor reports the 0.202 dose scoring SWEET SPOT instead of BARELY ANYTHING, and nothing else. `goose_controller.gd` is byte-identical to HEAD after both.
Refs: `tools/inputtest.gd::_eat_test`; `scripts/goose/goose_controller.gd::_tick_eat`; `Game.chaos_scored`, whose fourth argument is the only observable separating the three outcomes.

## D-046 · 2026-08-19 · The field that caused the worst bug in this project now has a gate
Status: Decided (agent)
Decision: `substancetest.gd` measures `input_lag` — ticks from the key going down to the bird first moving, against the sober baseline — and asserts it for the substances where it is separable. It also grows `_the_grid()`, which holds a **diagonal** under `grid_snap` and asserts the bird refuses to take it. 165 checks → 172.
Why: `docs/HANDOFF.md` §4 named both as having no behavioural coverage in any gate. `input_lag` is the field whose four-second ramp made **eleven of the sixteen substances unplayable** while every gate stayed green; this file counted it as satisfying the design rule and asserted nothing about it.

**Only two of the eleven laggards can be measured through motion, and that is a fact about `_wanted()`, not about the harness.** Drift is added to the stick AFTER the lag buffer is read, so under any drifting substance the bird is never still and "the first frame it moved" is frame one however stale the stick is. Measured: nine of eleven report 1 tick, and they are exactly the nine that drift. The other two land where the mechanism says they should — bars declares 0.10 and arrives 7 ticks after sober (0.117 s), robo declares 0.16 and arrives at 11 (0.183 s), each the declared value plus one to one and a half ticks of buffer rounding.

**Two is enough, because the bug was in the shared mechanism.** There is no per-substance lag code: one buffer in `_wanted()` serves all eleven, so the four-second ramp would show as bars arriving at 240 ticks instead of 8. What two cannot catch is a wrong number in one `.tres`, and `selftest` covers that statically. The nine are **printed as not asserted, with the reason**, rather than silently skipped.

**`grid_snap` needed a diagonal, and every existing channel holds forward.** A pure forward stick is already on an axis, so the snap is the identity and robo looked ordinary to all 22 channels. The check also **sets** the camera yaw rather than freezing whatever it found: `_raw_input()` rotates the stick before the snap, so the error is `|snappedf(a, PI/2) - a|` for `a = -PI/4 - yaw` — PI/4 at yaw 0 and **zero** at yaw -PI/4, where the diagonal already lies on a world axis. Measured 0.000 rad sober and **0.785 dosed**, which is PI/4 to three decimals.

**The first version of the diagonal reported 1.746 rad**, more than a right angle of error from a mechanic that can only produce 45°. It took a max over the sample window and was catching the bird MID-TURN — `_reset()` leaves it facing wherever it last faced and robo halves the turn rate. The peak of a turn is not a bearing; the last valid sample is. Another entry for the list in `tools/probe_common.gd`.

Both watched failing. Tripling the shared lag (`m.input_lag * 3.0`, the shape of the original bug) names bars at 20 ticks and robo at 33, with the allowed windows printed. Making the snap branch unreachable reports robo taking the diagonal at 0.000 rad and nothing else.
Refs: `tools/substancetest.gd::_the_grid`, `_diagonal`, `LAG_TOL`, `GRID_CLEAN`, `GRID_SNAPPED`; `scripts/goose/goose_controller.gd::_wanted`.

## D-045 · 2026-08-19 · The last three placement numbers, and the one that was twice as bad as recorded
Status: Decided (agent)
Decision: Suburbia's island lamp collider drops 0.6 m onto the grass; the recycling bin's chevron badge is computed from the tub's taper instead of a literal; and **both** goose visuals are lifted onto the capsule's contact point by `goose_controller.gd::_stand_visual()`. `geomtest.gd` gains pass 3, which drives the model pref and asserts the lowest vertex lands on the contact point.
Why: These were the last three entries in `docs/HANDOFF.md` §4's placement list, each recorded with both its numbers and none of them checkable.

**The lamp.** A 6 m box centred at 3.6 spans y 0.6 to 6.6 — floating 0.6 m off the grass and overhanging its own luminaire by the same. The MODEL was always right, which is why every render looked fine: `_model_body`'s offset was -3.6 to match the wrong centre. Every other post in the project passes minus HALF THE HEIGHT (`zone_strip_mall.gd` 8.0/-4.0, `zone_cottage.gd` `wall_h`/`-wall_h * 0.5`); this was the only one that passed minus the centre. Both move, so the model does not.

**The chevron.** The badge sat at a literal `z = -0.437` on a tub that tapers from `hz` 0.290 to 0.364, whose surface at the badge's height is 0.339 — 8.6 cm behind it. It is now `lerpf(0.290, 0.364, t) + 0.002`, read from the loft three lines above it. **A literal cannot follow a taper.** `MESH_BASELINE` moved 0.841 → 0.792 as a result, and the footprint gate stopped the commit until it did: nearly a tenth of that kind's measured depth was the bug, and correcting it took its declaration error from +5.1% to -1.0%.

**The feet, which were worse than recorded and worse in a second model nobody had mentioned.** HANDOFF estimated "5–10 cm" from reading constants. Measured: the lowpoly bird sinks **101 mm** and the classic bird **180 mm**, on every frame it stands. Each visual now declares `FOOT_DROP` — its lowest vertex below its own origin — and the controller lifts by `FOOT_DROP - CAPSULE_RADIUS`, scaled by `size` because macropsia scales the collider too and a fixed offset would re-bury a big goose. `0.34` is now `CAPSULE_RADIUS` rather than a literal inside `_build()`.

**Pass 3 goes through `Prefs.set_pref`, not through `.new()`.** A pass that instanced the visual scripts itself would measure `FOOT_DROP` and prove nothing about whether the controller applies it; the pref path is the one a player takes through the options menu, and it is what `_build_visual()` hangs off. Watched failing by setting the lowpoly `FOOT_DROP` to `CAPSULE_RADIUS`, which reproduces the original zero-lift bug exactly: *"the lowpoly goose stands 0.101 m into the ground"*, exit 1, classic unaffected.

**Feel is unchanged and that was checked, not assumed.** `_stand_visual()` writes `visual.position.y` and nothing else; all 13 feel windows report the same values as before the edit.
Refs: `scripts/world/zone_suburbia.gd::_central_island`; `scripts/world/prop_models.gd::_recycling_bin`; `scripts/goose/goose_controller.gd::_stand_visual`; `goose_visual.gd`/`goose_visual_lowpoly.gd` `FOOT_DROP`; `tools/geomtest.gd::_stance_pass`.

## D-044 · 2026-08-19 · The gate table checks itself against the gates
Status: Decided (agent)
Decision: `verify.ps1` gains a twelfth step. It keeps every gate's PASS line, reads the gate table in `docs/HANDOFF.md` §1, and requires **every integer in a doc cell to appear in that gate's PASS line**. The map is checked both ways: a gate this script runs with no row fails, and a row for a gate nothing runs fails.
Why: CLAUDE.md's rule is *"any number you write into a document gets a row in `docs/CLAIMS.md`, or gets deleted"* — and **the table that describes the gates broke it**. It said 148 substance checks when the gate printed 165, and 190 claims when doctest printed 189. Both were stale for a session and nothing could say so, because `doctest` recomputes from the **booted project** and cannot know what a gate prints without running it. This script has just run all eleven and is holding the answers.

**The rule is deliberately dumb, so it needs no per-gate configuration.** "22 metrics, 13 asserted" is satisfied by "22 measurements, 13 asserted, all in window"; a cell with no integers asserts nothing and is skipped — printed, not silent, so the gaps (`--rolltest`, `--loop-test`, this step's own row) are visible. 13 numbers are checked today.

**This makes it the twelfth gate, and `doctest` said so within a minute.** `verify_steps` counts `Pass "` in this script, and its comment already defined the term: *"a step that can report PASS is exactly what a gate is"*. CLAUDE.md's "11 gates" broke on the first run. It now says 12 **at the same line count** — 373, the ratchet's ceiling — by rewording rather than appending, which is the discipline the ceiling exists to force.

Watched failing twice, both times for real: the intended canary was doctest moving 189 → 195 while the table still said 189, which it named exactly. The unintended one was its own first draft matching **any** backticked table row, which swept up HANDOFF's document index and reported 26 failures politely explaining that nothing here runs `docs/MULTIPLAYER_SPEC.md`. Rows are now read only between the gate heading and the next heading.
Refs: `verify.ps1` step 12; `docs/HANDOFF.md` §1; `tools/doctest.gd::_live` "verify_steps"; `docs/CLAIMS.md` C-020, C-021.

## D-043 · 2026-08-19 · A pickup's model may not sit inside a solid, and the gate now says so
Status: Decided (agent)
Decision: `geomtest.gd` grows a second pass. For every `SubstancePickup` in every built zone it takes the world AABB of the meshes actually under it, after two frames, and asserts the centre of that box is outside every enabled `StaticBody3D` collider in the same zone. Six placements were wrong and all six are fixed: two berry sources at the strip mall's crabapple trunks, one at suburbia's, the cottage grass patch 0.5 m inside the cottage's west wall, leg 6's thermos inside the grain truck cab, and the truckstop coffee inside a fuel dispenser.
Why: **Pickups are placed by hand-written arithmetic against props placed by other hand-written arithmetic, and nothing had ever compared the two.** `zone_corn.gd` even carries a comment saying an earlier pickup had been found "INSIDE the collider" and moved — found by a human, once, by looking. The thermos two lines below it was still in the cab.

**Five of the six are one bug, not five.** A pickup was written at the prop's own anchor point as though the anchor were the prop's surface: `_source(Vector3(-12, 0.5, -8), ...)` next to `_static_box(Vector3(-12, 1.6, -8), Vector3(0.5, 3.2, 0.5))`. The sixth (leg 6) is the same mistake with a rotation on top — subtracting 1.3 m along **world** x from a truck yawed 0.14 rad lands 1.008 m along its **local** x, inside a half-width of 1.25.

**So the fixes bind the pickup to the prop rather than re-deriving a literal.** The strip mall gains `TREE_SPOTS` — the array `_trees()` already had, now shared — and `_at_the_foot_of()`, which offsets `FALLEN_FRUIT_R = 1.1` m away from `POND_CENTRE`; suburbia offsets along `h5.right`, the same direction `tree_pos` itself was pushed; leg 6 builds a `Transform3D` for the cab and places the thermos at local `(-1.60, 0.95, -2.16)`. A literal drifts away from its prop the first time anyone moves one. A reference cannot.

**Stated honestly, this is a visibility bug and not always a reachability one.** `setup()` gives every pickup a 1.6 m trigger sphere, wider than a tree trunk, so five of the six were still takeable — by a player who could not see what they were taking. That is the argument the assertion message carries.

**It was a report before it was a check, and that is why it is right.** The first run found nine and **three were the instrument** — it tested the Area3D origin, which is not where the art is: `breathe`/`sway` keep `setup()`'s 0.15 m lift, `bob` overwrites it, and a substance with no model falls back to 0.70 m. A fourth answer appears if you measure before the first `_process`. Measuring the mesh after two frames collapses all four. Recorded as entry 6 in `tools/probe_common.gd`; the boot zone never leaving the tree is entry 7, which had the same pass reporting leg 1's bread as buried in four zones that have never heard of it.

Watched failing by putting the truckstop cup back on the dispenser: *"1 of 74 … 0.36 m inside a solid at (-24.6, 1.2, 13.4) of 0.92 x 2.05 x 0.72"*, exit 1, and nothing else named.
Refs: `tools/geomtest.gd::_bury_pass`; `tools/probe_common.gd` entries 6–7; `scripts/world/zone_strip_mall.gd::_at_the_foot_of`; `zone_suburbia.gd`, `zone_cottage.gd`, `zone_corn.gd`, `zone_truckstop.gd`.

## D-042 · 2026-08-18 · The substance gate doses inside each substance's own band
Status: Decided (agent)
Decision: `substancetest.gd::_dose_for(res)` returns `clampf(DOSE, res.sweet_min, res.sweet_max)`, and every substance is asserted **not** to resolve `overdosed`.
Why: `DOSE = 0.6`'s own comment claimed it was *"inside the sweet band of every substance in the shelf, so `resolve()` returns quality 1.0"*. It was not. Acid's `sweet_max` is 0.55 and percs' is 0.58, so **two of the shelf were measured on the `overdosed` branch for the life of the gate** — where `resolve()` sets `bad = 1.6` and scales quality by `1.0 + (dose - sweet_max) * 1.5`. Every number the gate printed for those two was the substance at 1.6× its declared badness, and the printout never said so. Acid's measured drift moves 0.518 → 0.406 with the clamp in place.
**Clamping rather than choosing one universally-legal dose**, because inside the band the position does not matter: `resolve()` sets `quality = 1.0` anywhere between the bounds, so a clamped 0.45 and a clamped 0.55 resolve identically. A single universal dose works *today* — the shelf-wide legal band is **[0.45, 0.55]**, from nitrous' `sweet_min` and acid's `sweet_max` — but it is ten hundredths wide and the next substance could close it silently. Watched failing by removing the clamp: it names acid and percs and nothing else.
Refs: `tools/substancetest.gd`; `scripts/core/substance.gd::resolve`.

## D-041 · 2026-08-18 · Every placement group draws from its own seeded stream
Status: Decided (agent) — **retires F-002**
Decision: `zone_strip_mall.gd` and `zone_suburbia.gd` gain `_rng(tag)`, which returns a `RandomNumberGenerator` seeded by `hash("<zone>|<leg>|<tag>")`. Every build-time placement group — cats, people, props, cattails, parking, trees, garbage — draws from its own stream. `glidetest.gd::_the_layout_is_seeded()` builds **every zone twice with 137 global `randf()` calls burned in between** and requires every actor to land in the same place.
Why: F-002. Every builder drew from the one global RNG `main._ready()` seeds with `randomize()`, so where a cat stood was a function of **how many `randf()` calls happened before it**. Narrowing leg 1's shelf removed thirteen pickup constructions, moved every cat, camped one on the measuring pad, and turned four consecutive sober fingerprints red on a controller that was perfect. Adding a pickup can no longer move a cat, because the cats' stream does not know pickups exist.

**Only two zones needed it, which is why this was small.** The other four place their actors from fixed `spots[]` arrays and were already deterministic; the strip mall and suburbia were the only two that randomised, and the strip mall is the one every controller harness measures in. The check covers all six regardless — **50 actors across 6 zones** — so a future zone that starts randomising is caught the day it does.

**Burning the draws is the whole test.** A check that built the zone twice back to back would pass on the broken code too, because nothing would have consumed the stream in between. 137 is arbitrary and deliberately not round; what matters is that it is exactly what adding a pickup does. Watched failing by putting the cats back on the global stream: *"7 of 16 actors moved (worst 43.78 m)"*.

**Runtime randomness is untouched, on purpose.** The `randf()` calls in the other zones are sfx pitch jitter, bark cooldowns and wander targets — those SHOULD vary, and reseeding the global generator at build time (the one-line alternative) would have made them deterministic too. Per-group streams change only what is built.
Refs: `scripts/world/zone_strip_mall.gd::_rng`; `scripts/world/zone_suburbia.gd::_rng`; `tools/glidetest.gd::_the_layout_is_seeded`; retires `docs/RECENT_FAILURES.md` F-002.

## D-040 · 2026-08-18 · The results card's short-landing clock is THIS leg's
Status: Decided (agent — a bug fix, not a balance change)
Decision: `evaluate_leg()` returns `short_zone_base` beside `next_zone_base`, derived from `leg_seconds(leg)` rather than `leg_seconds(leg + 1)`, and `results_screen.gd::_short_clock()` reads it. `selftest.gd::_the_result_clocks()` drives all seven legs and asserts both.
Why: The card quotes two futures — *make the crossing and the next leg is X*, *land short and it is Y* — and **landing short does not advance the leg**. `main.gd::_on_migration_done()` only increments on `made_it`, so the player replays the leg they just flew out of. Both numbers came from the NEXT leg's clock. The canary that restores the old derivation fails on **four of the seven legs**, which is every leg whose clock differs from its neighbour's: leg 1 is 240 s against leg 2's 180, so failing flight 1 was advertised as a **120-second retry of a 240-second zone** — a full minute wrong, at the exact moment the player is deciding whether to risk the crossing.
The check asserts one thing about itself first: that at least one adjacent pair of legs has different clocks. Without that it would pass on the broken code too, and a route flattened to one clock would silently make it decorative.
Refs: `scripts/core/mission.gd::evaluate_leg`; `scripts/ui/results_screen.gd::_short_clock`; `tools/selftest.gd::_the_result_clocks`.

## D-039 · 2026-08-18 · A wedge closes both ends of its ridge, and a primitive is checked by Euler
Status: Decided (agent)
Decision: `LowPolyBuilder.wedge()` emits the missing seam triangle. `selftest.gd::_the_primitives_are_closed()` counts boundary edges — edges adjacent to an odd number of faces — and asserts a wedge leaves exactly its base ring open and nothing more.
Why: The fan switches from `tip_a` to `tip_b` halfway round the base, so the ridge meets the base at TWO seams; only the wrap was closed. **Every wedge in the project shipped with a triangular hole**: both of the cat's ears, both of the Ranger retriever's, and the human's nose. Measured both ways on the same file: with the seam open a wedge leaves `sides + 3` boundary edges (7, 8, 9 for a 4-, 5- and 6-gon) and with it closed exactly `sides` — those three edges are the missing triangle.
**And it survived a render pass, which is the part worth keeping.** A hole in a closed model does not read as a hole, it reads as one dark facet — exactly the way `CLAUDE.md` says an inside-out mesh "shades plausibly". *Looking at a picture is necessary and it is not sufficient.* The Euler count is the part that is sufficient, and `box()` is asserted alongside as the control: if the watertight primitive ever reports open edges then the COUNTER is broken and the wedge result beside it is worthless.
Refs: `scripts/goose/lowpoly_builder.gd::wedge`; `tools/selftest.gd::_the_primitives_are_closed`.

## D-038 · 2026-08-18 · The hitstop budget is a table, not a count in a comment
Status: Decided (agent)
Decision: `juice.gd::HITSTOP_SITES` lists every `Juice.hitstop()` in the game as `[path, seconds, strength, what]`, and `selftest.gd::_the_hitstops()` fails the build if the code and the table disagree **in either direction**.
Why: `juice.gd` opens with three rules it calls *"not negotiable"*, and the first said **"HITSTOP HAS EXACTLY FIVE CALL SITES in the whole game"** and named them. **There were eight.** The three it did not name — the Ranger's HAZED, a storey of BIG DOWN's glass, and the truck stop's diner window — are each argued at length where they sit, several of them explicitly against this very rule. So the SITES were fine and the RULE had rotted: a count in a comment cannot notice a fourth caller. That is `CLAUDE.md`'s banner failure mode, in the file most emphatic about not having it.
The check is symmetric on purpose: a call the table does not list fails, and a row with no call fails too — a table that can quietly describe a hitstop somebody deleted is the same rot wearing the other shoe. Both watched failing. **And the second canary found a limit in the check itself:** moving a declared 0.04 to 0.045 PASSED, because the comparison keys on two decimal places. Every value in the table is written to two places and there is no reason for a third, but the limit is now written down rather than discovered later.
Refs: `scripts/core/juice.gd`; `tools/selftest.gd::_the_hitstops`; `docs/HANDOFF.md` §4, which proposed exactly this.

## D-037 · 2026-08-18 · Bread is built, and it is a substance rather than a special case
Status: Decided (agent — the numbers are pacing and revertible; the mechanism is not)
Decision: `data/substances/bread.tres`, a seventeenth substance. `duration 20`, `chaos_mult 0.5`, every motion multiplier neutral, and one new export: **`blocks_dosing`**. While it is up, `Subs.take()` refuses everything else, the dose arc will not charge, and the HUD says FULL. It is on leg 1's `TUTORIAL_SHELF`, on the verge by the water, with a lawn sign beside it that is scenery rather than a chaos prop — wrecking the notice is a different joke from ignoring it.
Why: `docs/CAMPAIGN_SPEC.md` §2.1 has asked for it since the campaign was specced and calls it *"the perfect first-90-seconds lesson"*: **the obvious food is the trap**, delivered before the player has read a word. D-020 recorded it as deliberately unbuilt because it is a shelf-wide change; this is that change, done.

**It is a substance and not a timer, which is the whole reason it was cheap.** The first instinct is a `_full_until` clock on the controller. But "for twenty seconds you cannot dose, and your chaos is halved" is *exactly* what a Substance already is — `duration`, `chaos_mult`, and a mod the aggregator ORs across actives. So bread needed one export, one line in `resolve()`, one in `_empty_mods()`, one in `_aggregate()` and one refusal in `take()`. Everything else — the HUD strip, the timer, the tolerance, the Almanac entry, the unlock — it inherits for free.

**The refusal lives in `Subs.take()`, not only in the controller.** That is the API every path uses: the flock pen, the blanket share and every harness reach it directly, and a rule enforced only at the keyboard is not a rule. The controller *additionally* refuses to charge and says FULL, because a refusal the player cannot see reads as a broken control. `is_active(res.id)` lets bread top ITSELF up, so a second slice extends the fullness rather than being silently eaten for nothing.

**It is measured, not assumed.** `substancetest::_the_bread()` doses bread and asserts that another substance is refused, that `Subs.mods` actually carries the flag, that bread can top itself up, and that the block LIFTS when the actives clear — a block that never lifts is a soft-lock, not a lesson. Bread is NOT in `EXEMPT`; D-010 emptied that list because "an allowlist is where a real failure gets reclassified as an expected one", so `blocks_dosing` was added to the observable set and given its own channel, exactly as catnip is measured on the cats. Watched failing: with the refusal in `take()` disabled, *"with bread active, acid was still accepted."*

**What the numbers are.** `duration 20.0` and `chaos_mult 0.5` are §2.1's. `charge_time 0.5` and a sweet band of 0.05–1.0 are mine: **you cannot fail at eating bread**, which is the joke — the trap is not a skill test, it is the absence of one. `stamina_restore` is **0.0**, also mine: bread is real food and a refund would be defensible, but §2.1 does not ask for one and a trap with a consolation prize is a weaker lesson. All three are one-line reverts.

**The codex fact is a public-health notice rather than a fun fact**, and that is deliberate: bread genuinely causes angel wing in goslings, and the Almanac's whole claim is that every fact in it is true.

**What it cost, which is the argument D-020 made for deferring it:** the shelf went 16 → 17, and the claims gate immediately failed **five** rows across four documents from one new icon. That is the gate paying for itself on the first change big enough to test it.
Refs: `data/substances/bread.tres`; `scripts/core/substance_manager.gd::take`; `scripts/goose/goose_controller.gd::_tick_eat`; `tools/substancetest.gd::_the_bread`; `scripts/world/zone_strip_mall.gd`; supersedes the deferral in **D-020**.

## D-036 · 2026-08-18 · Eleven of fifteen props are declared the wrong size, and that is the human’s to fix
Status: **Open (human)**
Decision: **Unresolved, and deliberately not decided by an agent.** `tools/geomtest.gd` measured every prop the zones build against the footprint its builder declares. **Eleven of fifteen kinds are out by more than 6% on a horizontal axis.** The gate asserts that the MESHES do not drift and REPORTS the disagreement; it does not correct it.
Why: `prop_models*.gd::build()` sizes with `model.scale = want / footprint(kind)`, so a declaration that disagrees with the mesh makes every `size:` placement of that kind wrong by exactly that ratio, in every zone that asks for one. The measurements, with the spread across instances at **0.000 for fourteen of the fifteen kinds** — these are stable facts, not sampling noise:

| kind | declared (x, z) | mesh (x, z) | error |
|---|---|---|---|
| `hydrant` | 0.40, 0.40 | 0.286, 0.300 | **−28.5%, −25.0%** |
| `gnome` | 0.32, 0.32 | 0.244, 0.257 | **−23.7%, −19.8%** |
| `bench` | 1.80, 0.62 | 1.810, 0.506 | +0.6%, **−18.4%** |
| `stop_sign` | 0.72, 0.16 | 0.665, 0.280 | −7.6%, **+75.0%** |
| `lawn_sign` | 1.10, 0.08 | 1.060, 0.094 | −3.6%, **+17.8%** |
| `bbq` | 1.00, 0.55 | 0.880, 0.467 | **−12.0%, −15.0%** |
| `garbage_bag` | 0.48, 0.50 | 0.504, 0.454 | +5.0%, −9.1% |
| `patio_chair` | 0.60, 0.60 | 0.548, 0.577 | −8.6%, −3.8% |
| `mailbox` | 0.42, 0.60 | 0.384, 0.599 | −8.6%, −0.2% |
| `basketball` | 0.42, 0.42 | 0.390, 0.400 | −7.2%, −4.8% |
| `fence_panel` | 2.20, 0.16 | 2.288, 0.176 | +4.0%, **+10.0%** |

The four that are right — `minivan` +1.4%, `dumpster` +0.6%, `recycling_bin` +1.6%, `shopping_cart` −1.1% — are the big props somebody clearly measured. The wrong ones are the small props declared by eye.

**Why an agent must not just fix the table.** Correcting a declaration changes `model.scale` **non-uniformly**: `stop_sign` would go to (1.07, 1.01, **0.57**), squashing a model somebody authored to look right into the box its collider promises. Whether the prop should be squashed to fit its hitbox, or the hitbox resized to fit the prop, is a **look** — and `CLAUDE.md` is explicit that looks are the human’s. Nor can it be settled by a render an agent reads: the question is not "does it clip through the ground", it is "does a slightly squashed stop sign look right", and no file in this repo will ever have an opinion about that.

**To act on it:** change the FOOTPRINTS entry to the measured value, run `.\verify.ps1 -Shots`, and look at the zone. `geomtest` prints a copy-paste `MESH_BASELINE` block on every run for exactly this.
Refs: `tools/geomtest.gd`; `scripts/world/prop_models*.gd`; `docs/HANDOFF.md` §4, which has suspected `down_bale` of this for two sessions.

## D-035 · 2026-08-18 · The tenth gate opens the WAVs, and says what it cannot hear
Status: Decided (agent)
Decision: `tools/audiotest.gd`, step 6c of `verify.ps1`. **246 checks over 68 files.** A bed must loop and be long enough to be a bed; a one-shot must be short enough to be a one-shot; nothing may be silent or clipping; the sixteen layered music stems must share a length.
Why: `selftest::_the_assets()` proved a file EXISTS for every key the code asks for, and the bug that got past it is in the record — **the truck stop's "rain" was a 0.700 s goose hiss that never looped**, so the zone played 0.7 s of goose and then 174 s of silence. The file existed and the key resolved. **Named limits, both printed on every run:** it can say nothing about whether anything SOUNDS good, and 40 of the 68 files import as QOA, whose `data` holds compressed bytes, so the silence and clipping checks are skipped for those with a count.
**The floors are per family because a single one accused two healthy files.** The first version used one 3.0 s floor and immediately failed `dose_charge_loop` (1.000 s, because the dose arc is 1.1 s) and `swim_loop` (2.000 s, a paddle cycle). Lowering it to let them through would have let a 0.700 s hiss through too. So: `amb_*` ≥ 4.0, `*_loop` ≥ 0.25, `mus_*` ≥ 10.0, each argued in the file.
Watched failing twice, and the second is the one that matters: disabling `sfx.gd::_configure_loop_if_needed()` — the runtime fix that forces looping on `amb_`/`_loop` keys — failed **exactly the four files that depend on it** (`amb_parking_lot`, `dose_charge_loop`, `swim_loop`, `wind_loop`) and no others, because the other six beds and all sixteen stems loop from their `.import`.
Refs: `tools/audiotest.gd`; `verify.ps1` step 6c.

## D-034 · 2026-08-18 · Six unreachable objectives: three deleted, two moved, one re-gated
Status: Decided (agent — the two homes are design calls and revertible)
Decision: `selftest.gd::_the_objectives_are_reachable()` fails the build if an objective's leg gate excludes every leg `ROUTE` plays its zone on. It found **six**, and each was resolved on evidence rather than by lowering the gate:

| objective | was | resolution |
|---|---|---|
| `variety_pack` (strip_mall) | `from_leg 4`, zone plays 1–2 | **deleted** — cottage, stopover, corn and truckstop all declare it, which is exactly the "from leg 4 onward" the gate asks for |
| `variety_pack` (suburbia) | `from_leg 4`, zone plays 3 | **deleted**, same reason |
| `low_flying_aircraft` (suburbia) | `from_leg 5`, zone plays 3 | **deleted** — corn declares it and corn is leg 6, the band `mission.gd`'s escalation comment reserves the no-touching-the-ground constraint for |
| `night_flight` (cottage) | `from_leg 5`, zone plays 4 | **re-gated to 4** — unique, and night is cottage's own flavour |
| `no_brakes` (strip_mall) | `from_leg 3`, zone plays 1–2 | **moved to suburbia** — unique, and `mission.gd` promises the ten-second-window constraint at leg 3, which IS suburbia |
| `sustained_campaign` (strip_mall) | `from_leg 5`, zone plays 1–2 | **moved to corn** — the game's ONLY chain-length objective, and the leg-5 constraint it was meant to supply existed nowhere |

Why: `for_zone()`'s leg filter is correct; the DATA described legs the zones never reach. The gates read as run-progression numbers copied into each zone's block, which is why three of the six turned out to be redundant copies rather than mis-gated originals — lowering all six would have duplicated content that already appears at the right leg elsewhere. **The two homes are the judgement calls.** `sustained_campaign` went to the cut corn rather than the Stopover because the Stopover is the run's one recovery beat (`par_scale` 0.55, two required primaries) and a 10x chain primary fights the whole point of it; leg 6 is an open field with the highest prop density in the back half. Corn goes from 6 primaries to 7, which leaves `required_primaries(6)` at 4.
Refs: `tools/selftest.gd::_the_objectives_are_reachable`; `scripts/core/mission_defs.gd`; `scripts/core/mission_defs_corn.gd`; `scripts/core/mission_defs_cottage.gd`.

## D-033 · 2026-08-18 · Nine lawn signs are placed on the lawn
Status: Decided (agent)
Decision: Leg 1's lawn signs are rejection-sampled clear of the pond, the pond's centre and radius are constants the builder and the checker share, and `main.gd --loop-test` fails the run if any LAWN SIGN prop lands inside the water.
Why: The signs were sampled uniformly over x [-30, 30] × z [-30, -18]. **27.1% of that rectangle is inside the 11 m water cylinder** — measured over 2,000,000 samples, not estimated — so **2.4 of the 9 signs stood in the pond on an average run**, in the first zone the player ever sees. The canary that disables the rejection put 3 in the water on leg 1 and 2 on leg 2, which is the predicted average landing where it should. The rejection has a hard 24-try cap and a deterministic fallback, because a zone builder that can hang is a worse bug than a sign in a pond.
Refs: `scripts/world/zone_strip_mall.gd::_dry_xz`; `scripts/core/main.gd` shelf census.

## D-032 · 2026-08-18 · The share verb has a cooldown and only pays when it moves something
Status: Decided (agent — the 1.0 s is a pacing number and revertible)
Decision: `Flock.dose_flock()` returns how many birds it actually moved; `gg_share` pays only when that is non-zero, and is rate-limited by `SHARE_COOLDOWN := 1.0`.
Why: The verb paid **75 chaos and a combo link on every key press**, with no cooldown and no check that the dose landed. Once every bird sits at intox 1.0 the dose is a no-op — `clampf` eats it — and the player was still paid, forever, for a keypress that did nothing. The honk beside it has had a 0.22 s cooldown since it was written for exactly this reason. **1.0 s rather than 0.22** because the share is the bigger action: at 0.32 a press, a sober flock saturates in four, so this turns saturating the flock from four frames into four seconds — a decision instead of a mash — while leaving `share_the_wealth` (two shares) comfortably reachable. That number is pacing and a human may want it elsewhere; the two guards are not. `tools/inputtest.gd::_share_test` presses the key and counts SCORING EVENTS rather than chaos — the first version asserted an amount and failed on a correct build at 92, because `Game.score()` multiplies by the live combo. Watched failing on both guards at once: 3 fires instead of 1, and 1 fire instead of 0.
Refs: `scripts/goose/goose_controller.gd::_unhandled_input`; `scripts/core/flock_state.gd::dose_flock`; `tools/inputtest.gd`.

## D-031 · 2026-08-18 · The parser can stall on an undefined escape, and that is now a check
Status: Decided (agent)
Decision: `selftest.gd::_bad_escape()` scans every `.gd` for a backslash inside a string literal that is not one of GDScript's escapes, and fails the build naming the file and the character. `CLAUDE.md`'s hang section is rewritten to name **two** causes instead of one.
Why: `CLAUDE.md` documented the silent `--gate` stall — no output at all, no error, no exit — and attributed it to a local name reused inside one function. **That is not the only cause.** A RegEx written with `\*` in it stalled the gate with no repeated name anywhere in the file; the identical pattern written as a character class compiled in 25 s. One change, two runs, same file. The symptom is indistinguishable from a hung machine, which is why it is a check and not a paragraph — 71 new invariants, one per script, and watched failing on a deliberately bad file. **Named limit:** the scan only runs once the project boots, so the gate can still stall on the offending file before the scan reports it. It catches the second one, and the message tells you what to look for.
Refs: `tools/selftest.gd::_bad_escape`; `CLAUDE.md`.

## D-030 · 2026-08-18 · An overlay owns its own CanvasLayer, and no two share one
Status: Decided (agent)
Decision: `main.gd::_build_overlays()` no longer assigns `.layer` to anything it did not build itself; every overlay script sets its own in `_ready()`. `selftest.gd::_the_layers()` asserts that no two scripts under `scripts/ui` declare the same layer and that `main.gd` assigns none except `restart_prompt`, which it builds.
Why: `main.gd` set a layer immediately before `add_child()`, and `add_child()` runs the widget's `_ready()`, which sets it again. Seven of the eight agreed and were dead duplicates. The eighth did not: main said `almanac.layer = 20`, `almanac.gd` says 40, and **40 winning is the only reason the Almanac works** — it is opened FROM the pause menu at 30, so at 20 it would have rendered underneath the menu that opened it and read as a dead keypress. A contradiction resolved correctly by accident is still a contradiction. Watched failing on both halves: restoring the `almanac.layer = 20` line, and giving the control card the Almanac's 40.
Refs: `scripts/core/main.gd::_build_overlays`; `tools/selftest.gd::_the_layers`.

## D-029 · 2026-08-18 · `Substance.no_early_exit` is deleted, not wired
Status: Decided (agent)
Decision: The export, its `resolve()` key, its aggregation in `substance_manager.gd`, its Almanac line and the seven `.tres` entries are gone. `selftest.gd::_the_control_keys()` now fails if any key in `CONTROL_KEYS` is read only under `scripts/ui`.
Why: **D-018's test is "can it be honestly connected", and this one cannot.** `stamina_restore` was wired because it connected in one statement at the site the dose lands; `float_height` was deleted because there was no water surface to connect it to. `no_early_exit` is the second shape: there is **no verb in single-player that ends a trip**, so the flag described nothing, and `almanac.gd` printed *"Cannot end early — you finish the ride"* for acid and toad slime as though the other fourteen could be ended early. They cannot; nothing can. The only place the verb exists is `MULTIPLAYER_SPEC.md`'s "SOBER UP", and multiplayer is explicitly not next — that spec now records the deletion so it does not reference a field that is gone. **The worse half:** the key was in `selftest`'s `CONTROL_KEYS`, the list a substance satisfies the design rule with, so a future substance could have satisfied *"never only a number that goes up"* by setting a boolean that drew a sentence in a menu. That hole is what the new invariant closes; watched failing by putting the key back.
Refs: `scripts/core/substance.gd`; `scripts/ui/almanac.gd`; `tools/selftest.gd::_the_control_keys`; `docs/MULTIPLAYER_SPEC.md`.

## D-028 · 2026-08-18 · A reporting probe is held to a gate’s standard
Status: Decided (agent)
Decision: `tools/glidetest.gd` reports rather than asserts — D-005 and D-006 are the human’s — but it now **fails the run** on two things about ITSELF: every zone must drop exactly four boundary barriers and keep at least three standable surfaces, and `docs/FEEL_TARGETS.md` §5.1 must still publish the totals this run measures. It also prints what every walk threw away, per zone, per run.
Why: Its first published run counted the four invisible boundary walls every zone rings itself with — 80 m long, 1 m thick, 13 m up — as glide platforms **and** as the most dangerous drops in the game, and the resulting table went into `FEEL_TARGETS.md` §5.1 and was committed. It said 42 of 113 surfaces reachable today rising to 86 at 3:1, and "suburbia is the whole decision"; the true figures are **21 of 84 rising to 31**, and suburbia goes 0 → 1. **The conclusion was close to inverted.** The tell was in the output and unread: every zone reported *exactly* four hazardous surfaces and legs 1 and 3 named the same position. Three filters were tried — area (a wall’s top is 40 m²), capsule fit (it is a metre thick), and visibility, which was the dangerous one: `zone_suburbia.gd::_hide_meshes()` hides a body’s graybox "wherever the visual is replaced by a model that spans several colliders at once (the fence run, the trampoline’s ring of legs, **the roof plateau**)", so it discarded 73 of 158 surfaces including every landable roof. Shape works: nothing meant to be stood on is 30 m long and under 2 m wide. **A probe that publishes a number into a decision document is a gate whether or not it calls itself one.**
Refs: `tools/glidetest.gd`; `docs/FEEL_TARGETS.md` §5.1 and §5.2.

## D-027 · 2026-08-18 · The zone’s actors are held still for controller measurements, and only those
Status: Decided (agent)
Decision: `probe_common.gd::hold_actors()` disables every node in the `cat` and `npc` groups for the duration of a controller measurement. `feeltest` holds them for its whole run; `substancetest` holds them for each fingerprint and releases them, so `_the_cats()` still measures live cats. The retakes in both files **stay**.
Why: `HANDOFF` §4 warned that "a measurement taken in a dead world is measuring a different game", and that is right for gameplay metrics — which is why the hold is scoped to the channels that measure the CONTROLLER answering the stick, where a cat at 2.6 m/s is noise and not signal. Retaking was the previous remedy and it stopped working: **four consecutive sober fingerprints came back with off-axis errors of 0.775, 0.138, 0.462 and 1.211 rad while `turnrate` and `climb` were bit-identical (28.27, 1.73) in every one.** A cat was camped on the pad, so the disturbance was continuous and no number of retakes could find a quiet window. It started because editing the LAWN SIGNS moved the cats — `main._ready()` calls `randomize()` and every placement draws from one stream, so any zone-builder edit re-rolls every actor downstream (F-002). After the hold: sober noise **0.000 on every channel, zero retakes**, and `catnip` still measures 7 of 7 cats in frenzy, which is the proof the scoping is right. `feeltest` also gained a start-from-rest guard after one run measured `time_to_top` 0.17 s against an analytic `waddle_speed / waddle_accel` of 0.21; two runs since are bit-identical at 0.20 / 0.59 / 0.30.
Refs: `tools/probe_common.gd::hold_actors` (lesson 6); `tools/substancetest.gd::_fingerprint`; `tools/feeltest.gd::run`.

## D-026 · 2026-08-18 · `CLAUDE.md` has a line ratchet, and it can only go down
Status: Decided (agent)
Decision: `tools/doctest.gd::CLAUDE_MD_CEILING` fails the build if `CLAUDE.md` exceeds its current length. **To add a rule, take one out.** The target is 200; the ceiling starts at 379 and every session that cuts the file lowers it.
Why: `README_KIT.md` said the file was *"under 200 lines on purpose"*. It was 379, and nothing noticed — a line budget written in prose cannot count, which is the banner's own failure mode applied to the banner's own file. It matters more than tidiness: `CLAUDE.md` is loaded into every session **and every subagent**, and instruction adherence degrades with instruction COUNT rather than length, with silent omission as the dominant error — so the rules at the bottom are the ones that quietly stop being followed, and this file's bottom is "Scope discipline" and "Taste is the human's", the latter a human directive (D-002). The ratchet fired within an hour of being written: documenting `--doctest` pushed the file to 390, and paying for it meant compressing the dead-gates section (which `tools/gate.gd` already argues in full) and the architecture preamble. Net: 379 lines with a ninth gate documented. **Lower the ceiling with `[doctest] C-0NN claude_md_lines = N`, not with `wc -l`.** Trying to ratchet to 378 off a shell count turned the build red: the gate counts `split("
")` elements and a file with no trailing newline makes the two disagree by one. The gate is the authority on its own number, which is the point of having it.
Refs: `tools/doctest.gd::_the_budget()`; `README_KIT.md`.

## D-025 · 2026-08-18 · The failure log is capped at five and evicted only by conversion
Status: Decided (agent)
Decision: `docs/RECENT_FAILURES.md` holds at most **five** entries. An entry leaves only when it has been turned into an assertion, a hook or a deleted footgun, named in the same commit. Every entry carries a `**Retires when:**` line naming a specific artefact. `doctest.gd::_the_failure_log()` enforces the cap, the dating and the presence of that line.
Why: This is the Reflexion shape — write on failure only, store the diagnosis rather than the transcript, and hard-cap the buffer, because past a few entries reflections dilute each other instead of compounding. `CLAUDE.md` already carries a lessons list (the parser hang, the inside-out mesh, the tail-first goose, the input lag) and it is **unbounded and permanent**, in the one file loaded into every context. The cap is the forcing function: a sixth failure cannot be written until a fifth has been converted, which is the only way a lessons file ever gets smaller. **Named limit:** the gate can enforce the cap and the dating; it cannot verify that a deletion was a conversion. That is commit discipline, and saying so is better than implying coverage that does not exist.
Refs: `docs/RECENT_FAILURES.md`; `tools/doctest.gd`. Seeded with F-001 to F-003, all from this session.

## D-024 · 2026-08-18 · The ninth gate is pointed at the documents
Status: Decided (agent)
Decision: `docs/CLAIMS.md` lists every number this repo writes into a document and where it is written; `tools/doctest.gd` recomputes each from the booted project on every run and fails the build on disagreement. It also binds `feeltest.gd`'s thirteen `_assert_window` literals to the windows `docs/FEEL_TARGETS.md` argues for, and asserts that every gate flag `main.gd` dispatches is actually run by `verify.ps1`. Step 6b of `verify.ps1`. **176 claims at the first green run.**
Why: `docs/DECISIONS.md` was this project's answer to prose *decisions* rotting. Nothing answered prose *facts* rotting, and a survey found **seven** live instances the day this was written — three different texture counts across three files, a design bible reading "2 zones" against eight, a README calling the built stopover "the last placeholder in the route", and `CLAUDE.md`'s own line budget exceeded by 90%. None is a typo; each was true when written, sits in a well-written document beside sentences that are still true, and is therefore more persuasive than an obvious error (Xie et al., ICLR 2024: retrieved evidence is adopted in proportion to its *coherence*, not its correctness). **Nothing in `CLAIMS.md` stores an expected value** — the alternative shape, entries carrying counters or freshness stamps maintained by a reflection pass, needs a loop that runs every session and is trusted to be honest about its own work, and a hand-maintained freshness stamp is stale metadata about staleness. Watched failing on both paths: a wrong number (*"README.md says 41 before \" textures and\""*) and a moved marker (*"C-007's marker \" music stems\" appears 0 times"*). It also **found a real bug in itself** on its first run — the metric-name character class `[a-z_.]` silently dropped `ground.turn_180`, so it counted 12 windows where there are 13.
Refs: `tools/doctest.gd`; `docs/CLAIMS.md`; `verify.ps1` step 6b.

## D-023 · 2026-08-18 · Each flight gets its own shape, and flight 1 cannot take a bird
Status: Decided (agent)
Decision: `migration.gd::FLIGHTS` gives each of the seven crossings its own duration, opening quiet, spawn interval, hazard probability and hazard mix, lifted from `docs/ROUTE_DATA.md` §1.3. Flight 1 is `lethal: false`. Fields ROUTE_DATA declares that no code reads (`sky`, `ground`, `km`, `put_down`) are deliberately **not** copied in.
Why: `TARGET_DISTANCE := 2000.0` was the only termination test and nothing read the leg, so all seven crossings ran 85.3 s and spawned ~33 hazards out of a flat `randi() % 3` — half the game was one flight served seven times. Hazards per crossing are now **3.9 · 12.7 · 21.3 · 44.1 · 9.3 · 39.1 · 70.4**; the dip at flight 5 is the Stopover's recovery beat, which would mean nothing followed by the hardest crossing yet. Lethality on flight 1 is quoted design (`CAMPAIGN_SPEC.md` §2.1: *"not a nicety, it is the tutorial"*). The ramp shape is argued from Lomas et al. (n≈70,000: engagement tracks novelty and frequency of change rather than raw difficulty) rather than from a monotonic difficulty curve. The omitted fields follow **D-017**: an export nothing reads is `stamina_restore` waiting to happen.
Refs: `scripts/migration/migration.gd`; `tools/migtest.gd::_the_seven_flights`; `docs/ROUTE_DATA.md` §1.3.

## D-022 · 2026-08-18 · Leg 1 offers three substances; leg 2 offers all sixteen
Status: Decided (agent — revertible by one constant)
Decision: `zone_strip_mall.gd::TUTORIAL_SHELF` is `berries, double_double, grass`, and `FULL_SHELF_FROM_LEG` is 2. `_source()` is the only function in the file that may build a pickup, and it is gated on the leg's shelf.
Why: `CAMPAIGN_SPEC.md` §2.1 gives leg 1 three and §2.2 gives leg 2 *"all sixteen — this is where the lid comes off"*, with the spec's own intensity column going 2 → 4 across that boundary. The zone had no leg branch anywhere, so the first 420 seconds of the campaign were one place served twice at identical intensity. These three because the set is a tutorial rather than a sample: berries teaches that a substance is a control mutation and not a bonus, double_double is why the sweet spot is worth the risk, grass is `infinite` so the dose arc can be practised for free — and the set is **closed under the game's own mixing rule**, since `MAX_STACK` is 2, leg 1's `double_parked` primary requires two at once, and `berries|double_double` is THE WOBBLER. Bread, §2.1's fourth item, is **D-020**.
Refs: `scripts/world/zone_strip_mall.gd`; `tools/selftest.gd::_the_shelf`; `main.gd --loop-test`'s shelf census.

## D-021 · 2026-08-18 · The tutorial shelf offers one lag-free option and never the worst control
Status: Decided (agent)
Decision: `selftest.gd::_the_shelf()` asserts that at least one substance on leg 1's shelf has `input_lag == 0`, and that the shelf's worst `input_lag` is strictly below the shelf-wide worst. It does **not** forbid lag on leg 1.
Why: Two of the three tutorial substances add lag — berries 0.22 s and grass 0.10 s, against a shelf worst of toad_slime 0.28 and six substances at 0.00 — and that is deliberate: fermented berries ARE the drunk one and §2.1 names it. So the rule is not "no lag on leg 1", it is the two things that would actually break the lesson: the player needs one option that does not delay the stick, to learn the controls against and to compare the others to; and the first lesson may not be the least responsive control in the game. Local latency measures at roughly **twice** the performance impact of the same network latency (Liu & Claypool), and this project's most expensive bug ever was an input lag that made eleven of sixteen substances unplayable.
Refs: `tools/selftest.gd::_the_shelf`; `data/substances/*.tres`.

## D-020 · 2026-08-18 · Bread is specced for leg 1 and deliberately not built
Status: **Decided — BUILT, later the same day (see D-037)**
Decision: `CAMPAIGN_SPEC.md` §2.1 asks for bread as leg 1's fourth item — *"the obvious food is the trap"*, control mutation **you are full**, no dosing for 20 s, chaos ×0.5. Not built alongside the shelf split (D-022), and recorded rather than silently dropped.
Why: It is not just a `.tres`. It needs a generated icon (`selftest` fails a substance with no icon), an Almanac entry, a new control mutation in `_tick_eat`, and it changes the number **sixteen** that four gates count — `substancetest` doses all sixteen, `selftest` counts the shelf, `doctest` claims it, and the shelf census expects 16 on leg 2. That is a shelf-wide change and it does not belong inside a one-`if` leg branch. The design argument for it is strong and unaltered: it is the thesis of the whole game, delivered before the player has read a word.
Refs: `docs/CAMPAIGN_SPEC.md` §2.1; `scripts/world/zone_strip_mall.gd` header.

## D-019 · 2026-08-18 · Tolerance softens penalties, against the documented economy — recorded, not changed
Status: Open (human)
Decision: **Unresolved, and deliberately not decided by an agent.** `resolve()` picks `good` or `bad` per FIELD, but each of the four multipliers is a benefit on one side of 1.0 and a penalty on the other, so each scaling is right for only half its range.
Why: `docs/ARCHITECTURE.md` §3 and `substance.gd`'s own comment both say *"tolerance scales the good parts and never the bad ones — that asymmetry is the entire economy."* Measured at tolerance 3 (`tol = 0.488`): **eight substances have penalties softened** (percs' flap 0.80 → 0.90, speed 0.70 → 0.85; grass 0.78 → 0.89; plus bars, berries, gravy, robo, special_k, toad_slime) and **eight have benefits that never fade** (double_double's turn stays 1.50 at every tolerance, molly's 1.20, darts' 1.05; special_k's gravity stays 0.55, and four more). So the fourth percocet impairs you less than the first. The doc's own worked example — *"the fourth double-double gives you less speed and the same jitter"* — is one of the cases that is already correct.
**Recommendation if you want one:** select the scale by the DIRECTION of the declared value rather than by the field name, for `flap_mult`, `speed_mult` and `turn_mult` only. **Left open because** it makes six substances materially more punishing at tolerance and no instrument in this project can evaluate that; and because `gravity_mult` below 1.0 is genuinely ambiguous — floatier is a traversal *benefit* and a control *impairment* at once, which is a design call rather than arithmetic.
Refs: `scripts/core/substance.gd::resolve`; `docs/HANDOFF.md` §4.

## D-018 · 2026-08-18 · `Substance.stamina_restore` is wired, not deleted
Status: Decided (agent — revertible in one `if`)
Decision: `goose_controller.gd` now adds `res.stamina_restore` to the bird's stamina when a dose lands, flat and capped at 1.0. It was exported, set non-zero by **six** substances — bars 0.20, darts 0.20, double_double 0.40, grass 0.25, math 0.50, molly 0.30 — and read by **nothing**: not a key in `resolve()`, not named in any file under `scripts/`.
Why: The `.tres` files are this game's design record and six of them recorded a refund the player has never once received. Wired rather than deleted because the `float_height` precedent turns on *can it be honestly connected* — that dial went because there was no water surface to connect it to; this one connects in one statement at the exact site the dose lands, with substance and bird both in scope. **It is a balance change and nothing measures it**: `flap_cost` is 0.058, so math's 0.50 is about 8.6 extra flaps per dose. Revert by deleting the `if`.
Refs: `scripts/goose/goose_controller.gd::_tick_eat`; guarded by **D-017**.

## D-017 · 2026-08-18 · Every export on `Substance` must be connected to something
Status: Decided (agent)
Decision: `tools/selftest.gd::_the_substance_fields()` fails the build if an export on `Substance` is neither a key in `resolve()`'s returned Dictionary nor named by any file under `scripts/`. **No allowlist**, deliberately.
Why: `stamina_restore` (D-018) was dead for the life of the project and every gate passed, including the one that doses all sixteen substances and measures the bird — because they all reach into `Subs.take()` and none of them reads the export surface. The check is a floor, not a proof: naming a field anywhere counts, so it cannot false-fail, only false-pass. Watched fail on `stamina_restore` before the fix and pass after: **553 invariants**, up from 541.
Refs: `tools/selftest.gd`.

## D-016 · 2026-08-18 · A blown noise floor suppresses the ratio channels rather than reporting them
Status: Decided (agent)
Decision: When `substancetest.gd`'s two sober runs disagree, the two channels measured **as a ratio against sober** — peak turn rate and one-flap climb — are skipped for every substance, with a printed banner. Everything that stands on its own — drift, the macropsia pulse, `cannot_idle`, the clock, the cats — keeps running, and the build still fails on the one honest line.
Why: The file already printed *"nothing it reports about a substance can be trusted"* and then ran every ratio check anyway. On the red build that opened this session that turned **one** harness fault into **eight** failures, seven of which accused healthy substances of a broken `turn_mult` for being exactly 1/0.7 out. Canary-proven: forcing the floor to fail gives **1 of 109** instead of 8, and the one is true.
Refs: `tools/substancetest.gd`.

## D-015 · 2026-08-18 · The substance fingerprint is leashed to the pad
Status: Decided (agent)
Decision: The walk channel snaps the bird back to the pad, velocity intact, whenever it strays more than 6 m. The idle channel is deliberately **not** leashed — it sums path length and a teleport would be counted as travel.
Why: `PAD_RADIUS` is 9 m and its docstring sizes it for `feeltest`'s *"1.2 s of held forward at waddle_speed … about 5 m."* The substance fingerprint holds forward for **2.0 s** and not at `waddle_speed`: `math` measures 9.75 m/s = **18.5 m**, `fly_agaric` 11.8, `double_double` 11.4. On leg 1 the pad sits 21.5 m from an 11 m pond, leaving 10.5 m of grass and a 31° half-angle — measured **three failures in five runs**, against the ~40% the geometry predicts. Extending the pad was rejected: a 20 m clear ring may not exist in a zone, and a harness that fails on level design gets deleted. Nothing the walk measures reads position, so the leash is invisible to all three channels.
Refs: `tools/substancetest.gd::_fingerprint`.

## D-014 · 2026-08-18 · The dry-pad probe settles on a condition and rejects what it cannot answer
Status: Decided (agent)
Decision: `probe_common.gd` gains `_drop()`. Every pad probe now waits for the bird to reach the floor or the water instead of counting frames, the ring has **eight** spokes instead of four, a ring point the bird cannot floor is **rejected** rather than assumed dry, and the candidate is re-proven standing on its own centre before it is accepted. `substancetest.gd` also counts frames spent in water during a ground channel and names it a HARNESS FAULT — which `feeltest.gd` had done since it was written and this file never had.
Why: **This session opened on a red build.** The ring probed for water 6 frames after a 1 m teleport; ground gravity is 28 m/s², so that is 0.16 m of fall, and leg 1's pond is a cylinder that stops at y = 1.70 — a probe hovering at 2.16 over open water reported *dry*. The certified pad's ring point was **9.90 m from the pond centre against an 11 m radius**. The first sober fingerprint waded in and returned `speed 5.40` (`swim_speed` exactly) and `turnrate 19.79` (`28.27 × 0.7`, and the 0.7 lives only in `_tick_water()`). Seven substances were then accused of a broken `turn_mult`. Canary-proven by forcing the pad into the pond: **the old reproducibility guard passes** — both sober runs agree, being equally underwater — while the new counter fires 18 times.
Refs: `tools/probe_common.gd`; `tools/substancetest.gd`; `tools/feeltest.gd`.

## D-013 · 2026-08-18 · The Ranger's leg 6 exam stays unbuilt, blocked on a sound
Status: Open
Decision: `docs/BOSS_DESIGN.md` §2.1.4's exam is not built. Its propane cannon needs a bang, every sound in this game is generated by `tools/gen_audio.py`, and **no agent can hear the result.**
Why: The stated blocker in `boss_ranger.gd` ("leg 6 does not exist yet") was false — the corn field ships the standing corn, the stubble, the boundary and a combine that eats a row per pass, three of the four things §2.1.4 asks for. The real blocker is the audio, and it is a human one.
Refs: `scripts/world/boss_ranger.gd` header; `docs/BOSS_DESIGN.md` §2.1.4; `docs/HANDOFF.md` §3.

## D-012 · 2026-08-18 · Racking leaves one stock slot in four empty
Status: Decided (agent — revertible in one `continue`)
Decision: `prop_models_bigdown.gd::_racking()` skips one bale slot in four, chosen off the seeded wobble the stock already uses.
Why: The deck collider promises a clear full-width landing at every beam level; the mesh left **0.07 m at the aisle face and 0.17 m at the bay edges**, against a goose capsule **0.68 m wide and 1.10 m long**. The bird landed on the promised collider and was inside the bales, which breaks the "one level per flap" argument the 1.70 m beam pitch exists for. A factual collider-vs-mesh disagreement, not a taste call — but the *density* is a look, so the human may want a different fraction.
Refs: `scripts/world/prop_models_bigdown.gd`; first-ever interior render `--probe --leg:7 --goto:-2,5.5,-70`; `docs/HANDOFF.md` §4.

## D-011 · 2026-08-18 · Drift is gated on the drift vector, not the off-axis angle
Status: Decided (agent)
Decision: `substancetest.gd` asserts on `_drift`'s magnitude; the off-axis angle it produces is printed as corroboration and asserts nothing.
Why: `_drift` is built from sines seeded by an unseeded `randf()` and phased on wall-clock ms, so the angle a substance produces in any 2 s window is genuinely random — percs measured 0.15 to 0.99 rad across runs and the gate failed about one run in seven. Gating on the deterministic vector also *raised* coverage from 5 substances to all 13 that declare any drift.
Refs: `tools/substancetest.gd`; `docs/FEEL_TARGETS.md`.

## D-010 · 2026-08-18 · The substance EXEMPT list is empty, and catnip is measured on the cats
Status: Decided (agent)
Decision: No substance is exempt from the design rule. `catnip`'s only control mutation is `aggro_cats`, so `substancetest.gd::_the_cats()` measures the **cats** — all seven in leg 1 must enter `_frenzy` on a dose and leave it when the dose clears.
Why: The exemption was an admission in writing that if `aggro_cats` broke, nothing in the project would notice. An allowlist is where a real failure gets reclassified as an expected one.
Refs: `tools/substancetest.gd`.

## D-009 · 2026-08-18 · `fly.glide_ratio` is asserted as a regression guard, not an endorsement
Status: Decided (agent)
Decision: The window `[0.70, 1.10] : 1` is centred on today's behaviour so `glide_gravity`, `air_speed` or `max_fall` cannot move roof-to-roof traversal silently. It does **not** assert that 0.85 : 1 is the right glide — that is **D-006**.
Why: A metric can be worth locking against drift long before anyone has decided it is correct.
Refs: `tools/feeltest.gd`; `docs/FEEL_TARGETS.md` §5.1.

## D-008 · 2026-08-18 · The flock pen prompt sits at 1.66 m with render priority 4
Status: Decided (agent)
Decision: Raised from 1.03 m and given priority over the decorative name tags. `no_depth_test` stays **off**.
Why: At 1.03 it was below head height on a 1.3 m bird, so the geese in front drew their necks through it — the render read `[G] …AKE GOR… THE DD`. `no_depth_test` would have "fixed" it by letting the label shine through the strip mall wall, which tells the player their flock is inside the building. Verified by render: now reads `[G] MAKE TERRY THE DD`, whole.
Refs: `scripts/world/flock_pen.gd`. Evidence regenerates with
`godot --path . --rendering-driver opengl3 -- --probe --leg:1 --shots:1 --secs:2 --out:<dir>`
— `shots/` is gitignored, so the command is the durable artefact, not the PNG.

## D-007 · 2026-08-18 · The truck stop's closing beat stays proportional
Status: Open (human)
Decision: `_clock_scale()` leaves exactly **6.0% of the leg** as empty lot at every clock — 13.8 s at leg 7's 230 s, but 6.6 s at Mission's 110 s floor.
Why: A readable moment is arguably *absolute*, not proportional — a human needs roughly ten seconds to notice an empty lot whatever the clock says. Changing it is one line in `zone_truckstop.gd::_clock_scale()`. Not changed, because nothing specifies it and it is pacing.
Refs: `docs/HANDOFF.md` §4; `tools/selftest.gd::_the_rig_schedule()`.

## D-006 · 2026-08-18 · The glide is 0.85 : 1 and nobody has decided whether that is right
Status: Open (human)
Decision: Unresolved. One metre forward per metre down is a controlled fall, and `GEEKED_GEESE_DESIGN.md:130` promises *"chain it into a safe glide and you're fine."*
Why: Against changing it — the zones are 80 m across, and a 3:1 glide crosses one from a single flap stack, which trivialises the ground traversal the chaos scoring is built around, and silently invalidates "the goose cannot reach that" in eight zone builders. For changing it — flight between rooftops is the fantasy and thermals are a whole migration mechanic premised on altitude being worth something. **Taste. The human's.**
Refs: `docs/FEEL_TARGETS.md` §5.1; guarded by **D-009**.
**Costed 2026-08-18, not closed.** `tools/glidetest.gd` walked all seven built zones: **168 standable surfaces, 113 elevated, 42 of them (37%) glide-reachable today and 86 (76%) at 3:1.** The cost is not spread across the campaign, it is concentrated: legs 1, 2 and 6 are unchanged at every ratio tested, while **suburbia goes from 0 of its 21 elevated surfaces to 16** — the longest glide available in that zone today is 0.0 m. Suburbia is the leg that introduces height and it is built on getting between roofs costing flaps; widening the glide does not adjust that zone, it deletes its premise. Full table and the five named approximations: `docs/FEEL_TARGETS.md` §5.1.

## D-005 · 2026-08-18 · Every 20 m glide arrives at 20.9 m/s against a 13.0 hard-landing threshold
Status: Open (human)
Decision: Unresolved. Sober this is a 15-point "ROUGH LANDING" and a small shake — a reward. On any substance with `ragdoll_landings` it is an unavoidable faceplant on every descent from height, and nothing teaches flaring on approach.
Why: Either a good implicit lesson or an unfair one. That depends on playing it.
Refs: `docs/FEEL_TARGETS.md` §5.2.

## D-004 · 2026-08-17 · Leg 7 is 230 seconds
Status: Decided
Decision: `main.gd::ROUTE` leg 7 goes 180 → 230 s, which is what `docs/BOSS_DESIGN.md` §2.2.2 has always asked for.
Why: The comment forbidding it described a constraint `zone_truckstop.gd::_clock_scale()` had already removed. BIG DOWN needed no change — `DOCK_OPENS_WITH` (118 s left) puts the truck-stop phase at t=112, the 110 s §2.2.2 specifies, to within two seconds. The constraint is now `selftest.gd::_the_rig_schedule()`, checked on every clock the leg can legally be dealt.
Refs: `scripts/core/main.gd`; `tools/selftest.gd`.

## D-003 · 2026-08-17 · The flap SETS the climb; it does not add to it
Status: Decided
Decision: `_flap()` uses `maxf(velocity.y, power)` rather than `maxf(velocity.y, 0.0) + power`.
Why: The old form compounded — **7.36 m of climb in the first second of a held flap and 23.66 m in the third**, unbounded, because the 0.30 s cooldown only lets gravity take 3.3 m/s back against a power of 6.08. There is a `max_fall` in the controller and there has never been a `max_rise`. The fix leaves the single flap bit-for-bit unchanged at **1.73 m**, which is the level-per-flap BIG DOWN's 1.70 m racking pitch was built around.
Refs: `scripts/goose/goose_controller.gd`; `docs/FEEL_TARGETS.md` §4.

## D-002 · 2026-08-17 · Taste is the human's; everything measurable is the agent's
Status: Decided (human directive)
Decision: Agents no longer end a session by asking the human to go and play the game. Feel splits in two: **response** (time to top speed, stop distance, whether a held button converges) is arithmetic and is the agent's to measure, decide and record; **taste** (is a waddling goose funny) stays the human's permanently. Deferring taste no longer means stopping — make the call, log it here, keep going.
Why: `HANDOFF` §3 said "Play it" at the top of the list for two sessions running, everything behind it was blocked on one person having a free evening, and nothing behind it moved. The honesty rule is unchanged: **never claim you felt it.**
Refs: `CLAUDE.md`; `docs/HANDOFF.md` §3; `docs/FEEL_TARGETS.md` §0.

## D-001 · 2026-08-17 · The project is under git
Status: Decided
Decision: `main` holds the untouched baseline; work happens on branches. `_to_delete/` (90 MB of superseded zips and stale `.godot` caches) is gitignored, **not** deleted — that is the human's call.
Why: There was no `.git` at all, despite `VIBECODING_BRIEFING.md` making "commit before every task; `git reset --hard` instead of debugging a bad run" one of its six headline rules. The undo it describes had never existed. It was used within hours — twice, to isolate a parser stall by `git stash push <file>`.
Refs: `.gitignore`; `docs/SESSION_PROTOCOL.md`.
