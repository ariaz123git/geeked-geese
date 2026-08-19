extends RefCounted
## THE CLAIMS GATE — the ninth, and the first one that checks the DOCUMENTS
## against the project instead of the project against itself.
##
##     godot --headless --path . -- --doctest 2>&1 | grep '^\[doctest\]'
##
## ═══════════════════════════════════════════════════════════════════════════
## WHY THIS EXISTS, AND WHY IT IS DIFFERENT FROM THE OTHER EIGHT
## ═══════════════════════════════════════════════════════════════════════════
##
## `CLAUDE.md`'s banner names this project's most expensive failure mode:
##
##   > **A constraint recorded as prose keeps applying after it stops being
##   > true**, which has now cost this project three separate blockages.
##
## Three was the count when the banner was written. A survey this session found
## **seven more**, all of the same shape and none of them constraints — they are
## *facts*, and a fact rots exactly as silently as a rule:
##
##   | where | says | actually |
##   |---|---|---|
##   | `docs/ARCHITECTURE.md` §5 | 35 textures, 12 HUD icons, 40 SFX | 39, 16, 39 |
##   | `README.md` §1 | 35 textures and 40 sounds | 39 and 68 |
##   | `README.md` §4 | six zones | eight |
##   | `README.md` | leg 5 "the last placeholder in the route" | built |
##   | `README.md` | "every zone still borrows the parking-lot loop" | seven beds |
##   | `GEEKED_GEESE_DESIGN.md` | "playable, 16 substances, 2 zones" | 8 zones |
##   | `README_KIT.md` | CLAUDE.md is "under 200 lines on purpose" | 379 |
##
## Every one of those is coherent, adjacent to the truth, and therefore worse
## than an obvious error: work on retrieval-augmented models (Xie et al., ICLR
## 2024) finds that a model adopts external evidence in proportion to how
## COHERENT it is, not how correct. A confidently-wrong number in a well-written
## document is the most persuasive thing in the repo.
##
## The other eight gates check that the GAME is right. This one checks that what
## the repo SAYS about the game is right, and it does it the only way that
## cannot itself rot: by recomputing every number from the booted project on
## every run. There is no stored expected value anywhere in this file.
##
## ═══════════════════════════════════════════════════════════════════════════
## WHY A LIVE VALUE AND NOT A COUNTER
## ═══════════════════════════════════════════════════════════════════════════
##
## The obvious alternative — the shape ACE (agentic context engineering) uses,
## and the shape a "self-improving" system is usually drawn as — is a playbook
## of entries carrying `helpful: N / harmful: N` counters that some reflector
## increments. That needs a reflector loop that runs every session and is
## trusted to be honest about its own work. There is no such loop here, and a
## hand-maintained counter is stale metadata ABOUT staleness.
##
## A live value recomputed from the project needs no maintenance at all, cannot
## be gamed by the thing it measures, and fails loudly the first time anyone
## edits either side. That is the whole design.
##
## ═══════════════════════════════════════════════════════════════════════════
## THE THREE THINGS IT CHECKS
## ═══════════════════════════════════════════════════════════════════════════
##
##   1. **CLAIMS** — `docs/CLAIMS.md` lists facts, where each is written down,
##      and the marker string the prose puts after the number. Every listed file
##      must carry the live value. A marker that appears zero times, or more
##      than once, is a failure too: the first means the prose moved and the row
##      has gone blind, the second means the row is checking an arbitrary one of
##      two sentences.
##   2. **THE FEEL WINDOWS** — every `_assert_window()` literal in
##      `tools/feeltest.gd` must match the window `docs/FEEL_TARGETS.md` argues
##      for, and every asserted metric must HAVE an argument in that file. Two
##      copies of thirteen windows existed with nothing comparing them; the file
##      that carries the reasoning could drift from the file that carries the
##      enforcement, which is precisely what D-004 and the banner describe.
##   3. **THE BUDGET AND THE WIRING** — `CLAUDE.md` may not grow past its
##      ratchet, and every gate flag `main.gd` dispatches must actually be run
##      by `verify.ps1`.
##
## ═══════════════════════════════════════════════════════════════════════════
## HOW TO ADD A CLAIM
## ═══════════════════════════════════════════════════════════════════════════
##
## One row in `docs/CLAIMS.md` and one `match` case in `_live()`. It is a strict
## append — no row is ever rewritten in place, which is the same delta
## discipline `docs/DECISIONS.md` uses and for the same reason.
##
## **A key `_live()` cannot compute returns -1 and FAILS the build** rather than
## being skipped. A check that silently does nothing is the failure this project
## rates worst, and `selftest.gd::_the_docs()` already uses this exact guard.

const CLAIMS_DOC := "res://docs/CLAIMS.md"
const DOC_CLAUDE := "res://CLAUDE.md"
const DOC_FEEL := "res://docs/FEEL_TARGETS.md"
const SRC_FEELTEST := "res://tools/feeltest.gd"
const SRC_MAIN := "res://scripts/core/main.gd"
const VERIFY := "res://verify.ps1"

## THE RATCHET. `README_KIT.md` said CLAUDE.md was "under 200 lines on purpose";
## it was 379, and nothing noticed because a line budget written in prose cannot
## count. 200 is the target Anthropic's own guidance gives and it is where this
## should end up; the ceiling below is TODAY'S SIZE, so the file can shrink
## toward 200 and can never grow again.
##
## **Lower this number whenever you cut the file. Never raise it.** If a session
## needs to add a rule, it takes one out — which is the forcing function the
## budget exists to be.
const CLAUDE_MD_CEILING := 374
const CLAUDE_MD_TARGET := 200

## `docs/RECENT_FAILURES.md` holds at most this many. See `_the_failure_log()`
## and the file's own header for why the number is the whole point.
const FAILURE_LOG_CAP := 5

static var _fails: Array[String] = []
static var _checks := 0


static func run(tree: SceneTree, main: Node) -> void:
	_fails.clear()
	_checks = 0

	_the_claims(main)
	_the_feel_windows()
	_the_budget()
	_the_wiring()
	_the_failure_log()

	if _fails.is_empty():
		print("[doctest] PASS — %d claims hold" % _checks)
		tree.quit(0)
		return
	print("[doctest] FAIL — %d of %d claims broken:" % [_fails.size(), _checks])
	for f in _fails:
		print("[doctest]   %s" % f)
	tree.quit(1)


static func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


# ───────────────────────────────────────────────────────────────── the claims

static func _the_claims(main: Node) -> void:
	var doc := _read_text(CLAIMS_DOC)
	_ok(doc != "", "docs/CLAIMS.md is unreadable — the claims gate has nothing to check")
	if doc == "":
		return

	var rows := _parse_rows(doc)
	_ok(rows.size() >= 5,
		"docs/CLAIMS.md parsed %d rows. The ```claims block is missing or its format changed — this gate has gone blind." % rows.size())

	var seen_ids := {}
	for row in rows:
		var id: String = row.id
		var key: String = row.key
		var marker: String = row.marker
		var files: Array = row.files

		_ok(not seen_ids.has(id), "docs/CLAIMS.md has two rows with id %s" % id)
		seen_ids[id] = true
		_ok(row.since.length() == 10 and row.since.count("-") == 2,
			"%s has an unparseable `since` of \"%s\" — use YYYY-MM-DD." % [id, row.since])

		var live := _live(key, main)
		_ok(live >= 0,
			("%s names the key \"%s\" and this gate cannot compute it. THIS CHECK HAS GONE BLIND — "
			+ "add a case to doctest.gd::_live() or delete the row; do not leave it skipping.") % [id, key])
		if live < 0:
			continue

		if files.is_empty():
			# A fact with no prose carrying it cannot rot. The row is still
			# useful — it keeps the live value computable and printed — but it
			# asserts nothing about a document, and it says so rather than
			# quietly counting as a passing check.
			print("[doctest] %s %s = %d (no document carries it)" % [id, key, live])
			continue

		for one_file in files:
			var path: String = "res://" + str(one_file)
			var text := _read_text(path)
			_ok(text != "", "%s lists %s and the file is unreadable." % [id, one_file])
			if text == "":
				continue
			# CLAIMS.md CHECKING ITSELF HAS TO SKIP ITS OWN TABLE. The markers
			# are written out in the ```claims block, so every self-referential
			# row counted two hits — the machine-readable row and the prose
			# sentence it points at — and failed as "two sentences carry this
			# fact". The block is data, not prose; only the prose is checked.
			if path == CLAIMS_DOC:
				text = _without_block(text)
			var hits := _count(text, marker)
			_ok(hits == 1,
				("%s's marker %s appears %d times in %s. %s") % [id, _q(marker), hits, one_file,
					("The prose moved or was deleted — fix the row or delete it."
						if hits == 0
						else "Two sentences carry this fact and the row checks an arbitrary one of them; make the marker specific.")])
			if hits != 1:
				continue
			var written := _int_before(text, marker)
			_ok(written == live,
				("%s %s: the project has %d; %s says %d before %s.")
					% [id, key, live, one_file, written, _q(marker)])


## The document with its machine-readable block removed, so a row that points at
## CLAIMS.md is checked against its prose and not against its own table.
static func _without_block(doc: String) -> String:
	var open_at := doc.find("```claims")
	if open_at < 0:
		return doc
	var close_at := doc.find("```", doc.find("\n", open_at))
	if close_at < 0:
		return doc
	return doc.substr(0, open_at) + doc.substr(close_at + 3)


## Rows out of the ```claims fenced block. Everything outside it is prose this
## gate deliberately ignores, so the file can explain itself to a human.
static func _parse_rows(doc: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var open_at := doc.find("```claims")
	if open_at < 0:
		return out
	var body_at := doc.find("\n", open_at)
	var close_at := doc.find("```", body_at)
	if body_at < 0 or close_at < 0:
		return out
	for raw in doc.substr(body_at, close_at - body_at).split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var cells := line.split("|")
		if cells.size() < 5:
			continue
		var files: Array[String] = []
		for chunk in cells[4].split(","):
			var one := chunk.strip_edges()
			# An em dash means "no document carries this".
			if one != "" and one != "—" and one != "-":
				files.append(one)
		out.append({
			"id": cells[0].strip_edges(),
			"since": cells[1].strip_edges(),
			"key": cells[2].strip_edges(),
			"marker": cells[3].strip_edges().trim_prefix("\"").trim_suffix("\""),
			"files": files,
		})
	return out


## THE ONLY PLACE A NUMBER IN THIS PROJECT IS ALLOWED TO COME FROM.
##
## Every one of these is recomputed from the booted project or from the file
## tree. Nothing here reads another document, because a document checked against
## a document is two copies of a guess.
static func _live(key: String, main: Node) -> int:
	match key:
		"gd_scripts":
			return _walk(".gd").size()
		"png_textures":
			return _walk_dir("res://textures", ".png").size()
		"surface_textures":
			# The 23 that are not substance icons. `CLAUDE.md` counts textures
			# this way and `docs/HANDOFF.md` counts the total; both are true and
			# both are now checked, which is cheaper than making them agree on
			# a wording.
			var surfaces := 0
			for one in _walk_dir("res://textures", ".png"):
				if not one.get_file().begins_with("icon_"):
					surfaces += 1
			return surfaces
		"substance_icons":
			var icons := 0
			for one in _walk_dir("res://textures", ".png"):
				if one.get_file().begins_with("icon_"):
					icons += 1
			return icons
		"wav_files":
			return _walk_dir("res://audio", ".wav").size()
		"music_stems":
			return _prefixed("res://audio", ".wav", "mus_")
		"ambience_beds":
			return _prefixed("res://audio", ".wav", "amb_")
		"sfx_clips":
			return (_walk_dir("res://audio", ".wav").size()
				- _prefixed("res://audio", ".wav", "mus_")
				- _prefixed("res://audio", ".wav", "amb_"))
		"substances":
			var subs := main.get_node_or_null("/root/Subs")
			return -1 if subs == null else int(subs.library.size())
		"route_legs":
			var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
			return route.size()
		"flight_entries":
			var mig := load("res://scripts/migration/migration.gd")
			if mig == null:
				return -1
			var fl: Array = mig.get_script_constant_map().get("FLIGHTS", [])
			return fl.size()
		"autoloads":
			var n := 0
			for prop in ProjectSettings.get_property_list():
				if str(prop.get("name", "")).begins_with("autoload/"):
					n += 1
			return n
		"feel_windows":
			return _feeltest_windows().size()
		"claude_md_lines":
			return _read_text(DOC_CLAUDE).split("\n").size()
		"verify_steps":
			# One `=== name ===` banner per gate in verify.ps1. This is the only
			# honest count of "how many gates are there": `tool_flags` misses
			# --loop-test, which is not a tool flag but is unarguably a gate.
			# One `Pass "<name>"` verdict per gate. Counting the `=== name ===`
			# banners instead would also catch the first-run asset import and
			# the optional render step, neither of which is a gate; a step that
			# can report PASS is exactly what a gate is.
			return _count(_read_text(VERIFY), "Pass \"")
		_:
			return -1


# ────────────────────────────────────────────────────────── the feel windows

## THE FILE THAT CARRIES THE ARGUMENT AND THE FILE THAT CARRIES THE ENFORCEMENT.
##
## `tools/feeltest.gd` holds thirteen windows as inline literals:
##
##     _assert_window("ground.top_speed", top, "m/s", 3.0, 6.0, "...")
##
## `docs/FEEL_TARGETS.md` §2 holds the same thirteen as markdown, WITH the
## argument for each bound:
##
##     | `ground.top_speed` | 3.0–6.0 m/s | **4.20** | Zones are ~80 m across… |
##
## Two copies of the same thirteen numbers and nothing compared them. The
## argument is the more valuable half — it is what lets a future session
## DISAGREE with a window rather than merely obey it — and it was the half free
## to drift.
##
## `tools/migtest.gd`'s windows are deliberately not bound here: FEEL_TARGETS §6
## argues them in prose rather than in a table, so there is nothing to parse.
## Named so the omission is a known one rather than an oversight.
static func _the_feel_windows() -> void:
	var code := _feeltest_windows()
	var doc := _read_text(DOC_FEEL)
	_ok(code.size() >= 10,
		"parsed %d _assert_window() calls out of tools/feeltest.gd — this check has gone blind, fix the parse." % code.size())
	_ok(doc != "", "docs/FEEL_TARGETS.md is unreadable")
	if doc == "" or code.size() < 10:
		return

	for metric in code.keys():
		var want: Vector2 = code[metric]
		var band := _doc_window(doc, str(metric))
		_ok(band.x <= band.y,
			("tools/feeltest.gd asserts `%s` in [%.2f, %.2f] and docs/FEEL_TARGETS.md §2 has no row for it. "
			+ "A window the build enforces with no written argument is a number nobody can disagree with.")
				% [metric, want.x, want.y])
		if band.x > band.y:
			continue
		_ok(is_equal_approx(band.x, want.x) and is_equal_approx(band.y, want.y),
			("`%s`: feeltest.gd enforces [%.2f, %.2f] and docs/FEEL_TARGETS.md §2 argues for [%.2f, %.2f]. "
			+ "One of them moved without the other.") % [metric, want.x, want.y, band.x, band.y])


## metric -> Vector2(lo, hi), read off feeltest.gd's `_assert_window` literals.
static func _feeltest_windows() -> Dictionary:
	var out := {}
	var src := _read_text(SRC_FEELTEST)
	if src == "":
		return out
	var re := RegEx.new()
	# name, <anything to the unit string>, unit, lo, hi. The value argument is
	# an arbitrary expression, so it is skipped non-greedily rather than parsed.
	re.compile("_assert_window\\(\"([a-z0-9_.]+)\",.*?\"[^\"]*\",\\s*(-?[0-9.]+),\\s*(-?[0-9.]+)")
	for m in re.search_all(src):
		out[m.get_string(1)] = Vector2(float(m.get_string(2)), float(m.get_string(3)))
	return out


## The window FEEL_TARGETS.md §2 argues for a metric, or an inverted Vector2 if
## the metric has no row. The table cell reads `3.0–6.0 m/s` with an EN DASH,
## and `1–3 ticks` with no decimal point, so both forms have to parse.
static func _doc_window(doc: String, metric: String) -> Vector2:
	var at := doc.find("| `" + metric + "` |")
	if at < 0:
		return Vector2(1.0, 0.0)
	var line_end := doc.find("\n", at)
	if line_end < 0:
		line_end = doc.length()
	var cells := doc.substr(at, line_end - at).split("|")
	if cells.size() < 3:
		return Vector2(1.0, 0.0)
	var re := RegEx.new()
	re.compile("(-?[0-9]+(?:\\.[0-9]+)?)\\s*[–—-]\\s*(-?[0-9]+(?:\\.[0-9]+)?)")
	var m := re.search(cells[2])
	if m == null:
		return Vector2(1.0, 0.0)
	return Vector2(float(m.get_string(1)), float(m.get_string(2)))


# ─────────────────────────────────────────────────────── the budget and wiring

static func _the_budget() -> void:
	var lines := _read_text(DOC_CLAUDE).split("\n").size()
	_ok(lines <= CLAUDE_MD_CEILING,
		("CLAUDE.md is %d lines against a ceiling of %d. It is loaded into every session and every "
		+ "subagent, and instruction adherence degrades with instruction COUNT — the dominant error "
		+ "is silent omission, so the rules at the bottom are the ones that stop being followed. "
		+ "To add a rule, take one out, or convert one to an assertion. Target is %d.")
			% [lines, CLAUDE_MD_CEILING, CLAUDE_MD_TARGET])
	if lines < CLAUDE_MD_CEILING:
		print("[doctest] CLAUDE.md is %d lines; the ratchet is %d and the target is %d. Lower the ratchet in doctest.gd."
			% [lines, CLAUDE_MD_CEILING, CLAUDE_MD_TARGET])


## A GATE THAT IS DOCUMENTED AND NEVER RUN IS NOT A GATE.
##
## `selftest.gd::_the_docs()` already checks that every flag `main.gd` dispatches
## is mentioned in CLAUDE.md. That proves it is *written down*. This proves it is
## *executed*: the flag has to appear in `verify.ps1`, which is the only thing
## anyone actually runs.
##
## The reverse direction — verify.ps1 naming a flag main.gd does not dispatch —
## needs no check here, because that step would run a probe that does nothing and
## fail on its own missing pass line.
static func _the_wiring() -> void:
	var main_src := _read_text(SRC_MAIN)
	var verify := _read_text(VERIFY)
	_ok(verify != "", "verify.ps1 is unreadable")
	var flags := _tool_flags(main_src)
	_ok(flags.size() >= 4,
		"could not parse main.gd's `tool_flags` — this check has gone blind, fix the parse")
	if verify == "":
		return
	for one_flag in flags:
		_ok(verify.contains(one_flag),
			("main.gd dispatches the gate flag `%s` and verify.ps1 never runs it. A gate that is "
			+ "documented and not executed is worse than no gate: it is a claim of coverage.") % one_flag)


## THE CAP IS THE MECHANISM, SO SOMETHING HAS TO ENFORCE IT.
##
## `docs/RECENT_FAILURES.md` holds at most five entries, and an entry may only
## leave by being converted into a check that makes the failure impossible. Both
## halves are load-bearing: without the cap the file grows into a second
## `CLAUDE.md` that nobody reads to the bottom of, and without the conversion
## rule the cap is satisfied by deleting the oldest lesson unlearned.
##
## This can enforce the cap and the dating. It cannot enforce that a deletion
## was a conversion — that is a commit-message discipline, stated in the file
## itself. Named here so the limit of the check is visible rather than assumed.
static func _the_failure_log() -> void:
	var text := _read_text("res://docs/RECENT_FAILURES.md")
	_ok(text != "", "docs/RECENT_FAILURES.md is unreadable")
	if text == "":
		return
	# THE FILE'S OWN TEMPLATE IS NOT AN ENTRY. Its "how to write one" section
	# shows the heading format inside a fenced block, and the first version of
	# this check counted it — 4 headings, 3 parsing — which is the same
	# self-reference trap `_the_claims()` hits on CLAIMS.md's table. Fenced
	# blocks are examples, not content.
	text = _without_fences(text)
	var re := RegEx.new()
	re.compile("(?m)^### (F-[0-9]+) · ([0-9]{4}-[0-9]{2}-[0-9]{2}) · (.+)$")
	var entries := re.search_all(text)
	_ok(entries.size() <= FAILURE_LOG_CAP,
		("docs/RECENT_FAILURES.md holds %d entries against a cap of %d. The cap is the forcing "
		+ "function: a sixth failure cannot be written until a fifth has been turned into an "
		+ "assertion, a hook, or a deleted footgun. Convert one — do not raise this.")
			% [entries.size(), FAILURE_LOG_CAP])
	# A heading that does not parse is an entry the cap cannot see, which is the
	# same class of bug as a check that cannot fail.
	var headings := 0
	for line in text.split("\n"):
		if line.begins_with("### "):
			headings += 1
	_ok(headings == entries.size(),
		("docs/RECENT_FAILURES.md has %d `### ` headings and %d of them parse as "
		+ "`### F-00N · YYYY-MM-DD · title`. An entry the cap cannot count is an entry the cap "
		+ "does not bound.") % [headings, entries.size()])
	for e in entries:
		var id := e.get_string(1)
		var body_at := text.find(e.get_string(0)) + e.get_string(0).length()
		var next_at := text.find("\n### ", body_at)
		var body := text.substr(body_at, (next_at - body_at) if next_at > 0 else -1)
		_ok(body.contains("**Retires when:**"),
			("%s has no `**Retires when:**` line. An entry that cannot name the check that would "
			+ "retire it is not a lesson, it is a grievance — put it in docs/HANDOFF.md §4 with "
			+ "its arithmetic instead.") % id)


# ───────────────────────────────────────────────────────────────────── helpers

static func _tool_flags(src: String) -> Array[String]:
	var out: Array[String] = []
	var at := src.find("tool_flags")
	if at < 0:
		return out
	var open_b := src.find("[", at)
	var close_b := src.find("]", open_b)
	if open_b < 0 or close_b < 0:
		return out
	for chunk in src.substr(open_b + 1, close_b - open_b - 1).split(","):
		var one := chunk.strip_edges().replace("\"", "").strip_edges()
		if one.begins_with("--"):
			out.append(one)
	return out


## The integer immediately preceding `marker`. Same rule as
## `selftest.gd::_int_before()`, which has shipped against " GDScript files"
## since it was written — deliberately a second copy rather than a shared
## helper, because the two gates must be able to disagree about a number
## without one of them being unable to boot.
static func _int_before(text: String, marker: String) -> int:
	var at := text.find(marker)
	if at < 0:
		return -1
	var digits := ""
	var i := at - 1
	while i >= 0:
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			digits = ch + digits
		elif digits != "":
			break
		elif ch != " ":
			break
		i -= 1
	return int(digits) if digits != "" else -1


## Markdown with every ``` fenced block removed. A fenced block in a document is
## an example of the format, not an instance of it.
static func _without_fences(text: String) -> String:
	var out := ""
	var inside := false
	for line in text.split("\n"):
		if line.begins_with("```"):
			inside = not inside
			continue
		if not inside:
			out += line + "\n"
	return out


static func _count(text: String, needle: String) -> int:
	if needle == "":
		return 0
	var n := 0
	var at := text.find(needle)
	while at >= 0:
		n += 1
		at = text.find(needle, at + needle.length())
	return n


static func _q(s: String) -> String:
	return "\"" + s + "\""


## Every file in the project with `suffix`, skipping the engine's own cache.
static func _walk(suffix: String) -> Array[String]:
	return _walk_dir("res://", suffix)


static func _walk_dir(root: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var stack: Array[String] = [root]
	while not stack.is_empty():
		var here: String = stack.pop_back()
		var d := DirAccess.open(here)
		if d == null:
			continue
		d.list_dir_begin()
		var name := d.get_next()
		while name != "":
			if name.begins_with("."):
				name = d.get_next()
				continue
			var path := here.path_join(name)
			if d.current_is_dir():
				if name != "addons":
					stack.append(path)
			elif name.ends_with(suffix):
				out.append(path)
			name = d.get_next()
		d.list_dir_end()
	return out


static func _prefixed(root: String, suffix: String, prefix: String) -> int:
	var n := 0
	for one in _walk_dir(root, suffix):
		if one.get_file().begins_with(prefix):
			n += 1
	return n


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var body := f.get_as_text()
	f.close()
	return body
