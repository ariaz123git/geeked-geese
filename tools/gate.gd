extends RefCounted
## THE COMPILE GATE — the real one.
##
## For most of this project's life the documented gate was:
##
##     godot --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|ERROR:"
##
## **That gate does not work.** `--import` scans and imports *assets*. It does
## not compile GDScript. A file containing the single most common error in this
## codebase —
##
##     var x := some_dictionary.key      # Cannot infer the type of "x"
##
## — passes it silently and then fails to load at runtime, which in Godot means
## the node it was attached to quietly does nothing. Verified 2026-08-04 by
## dropping exactly that file into scripts/world/ and watching the gate print
## nothing. Every "verified clean" claim made against that command was worthless.
##
## The other obvious candidate is also wrong:
##
##     godot --headless --check-only --script <file>
##
## It parses in isolation, so every script touching an autoload reports
## `Compile Error: Identifier not found: Subs` — a false failure on most of the
## project. (CLAUDE.md already warned about this; it just didn't have a
## replacement.)
##
## So the gate has to run **inside the booted project**, where the autoload
## singletons are registered and identifier resolution is the real one. That is
## what this does: it walks every .gd, .tres and .tscn in the project and forces
## a cache-bypassing load of each, which is a full parse + compile. A script
## that cannot compile returns null and prints its real error.
##
## Run it:
##     godot --headless --path . -- --gate 2>&1 | grep '^\[gate\]'   # ${PIPESTATUS[0]}
## Exit code 0 = clean, 1 = something did not compile. Every line the gate itself
## writes is prefixed `[gate]`, including the list of failing paths, so the
## filtered form is the one to read day to day; drop the filter to see the
## engine's own error text for a failure.
##
## **Expected noise.** Parsing `scripts/ui/briefing.gd` makes the engine print 26
## × `ERROR: Parameter "method" is null.` It is an artefact of the detached-parse
## method below meeting that file's `const Briefing_Caps := Caps` inner-class
## alias; the file compiles (`reload()` returns OK), loads normally at boot, and
## prints nothing during a real run. Bisected 2026-08-04 — removing the alias
## makes the file stop parsing entirely, so it is load-bearing. This is exactly
## the kind of output that teaches people to skim a gate, hence the `grep`.
##
## Add `--gate-verbose` to print each path before it is parsed; that is how the
## above was attributed, and how to attribute the next one.
##
## DirAccess (rather than ResourceLoader.list_directory) is deliberate and
## allowed: this file is dev tooling that never ships in an export, which is the
## exception CLAUDE.md carves out.

const SKIP_DIRS := [".godot", ".git", "_to_delete", "addons"]

## THERE IS NO ESCAPE HATCH IN THIS GATE, AND THERE USED TO APPEAR TO BE ONE.
##
## `const EXPECTED_FAILURES := {}` sat here with a docstring describing how an
## entry would excuse a file — and `run()` never consulted it. So did
## `_is_abstract_ok()`, called from nowhere. A maintainer who followed the
## docstring and added an entry would have watched the gate keep failing with no
## explanation, which is the worst of both worlds: the appearance of a hole and
## none of the behaviour.
##
## Both deleted rather than wired up, on the strength of the docstring's own
## argument: **an entry would have been a hole in the gate, not a fix.** If a
## file genuinely cannot load standalone, that is a fact about the file.


static func run(tree: SceneTree, verbose: bool = false) -> void:
	var scripts: Array[String] = []
	var resources: Array[String] = []
	_walk("res://", scripts, resources)
	scripts.sort()
	resources.sort()

	var failed: Array[String] = []

	print("[gate] compiling %d scripts..." % scripts.size())
	for p in scripts:
		# Parse into a DETACHED GDScript rather than through ResourceLoader.
		#
		# `ResourceLoader.load(p, "Script", CACHE_MODE_IGNORE)` looks like the
		# right call and is not: it replaces the cache entry for scripts that
		# are *currently executing* — main.gd, every autoload — and the engine
		# segfaults partway through the walk. (CACHE_MODE_IGNORE_DEEP instead
		# re-parses the preload graph exponentially and never returns.)
		#
		# Reading the source and calling reload() on a fresh GDScript touches
		# neither the cache nor the running instances, so every file in the
		# project can be checked including the one running the check.
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			failed.append(p + "  (unreadable)")
			continue
		var src := f.get_as_text()
		f.close()
		var gd := GDScript.new()
		gd.source_code = _strip_class_name(src)
		# Deliberately NOT setting gd.resource_path. Claiming a path that a
		# live cached resource already owns makes the engine abort on shutdown.
		# Every preload in this project is absolute (`res://...`), so the parse
		# resolves fine without it, and the failure list below prints the path
		# anyway.
		if verbose:
			print("[gate] >> ", p)
		if gd.reload() != OK:
			failed.append(p)

	print("[gate] loading %d resources..." % resources.size())
	for p in resources:
		var res2: Resource = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res2 == null:
			failed.append(p)

	if failed.is_empty():
		print("[gate] PASS — %d scripts, %d resources, 0 failures" % [scripts.size(), resources.size()])
		tree.quit(0)
		return

	print("[gate] FAIL — %d file(s) did not load:" % failed.size())
	for p in failed:
		print("[gate]   %s" % p)
	tree.quit(1)


## Remove the `class_name` declaration, keeping everything else on that line and
## keeping the line itself so reported line numbers still match the file.
##
## Necessary because the parse copy is a second, detached script: the real one
## is already registered under that global name, so leaving the declaration in
## makes every `class_name`'d file in the project fail with `Class "Cat" hides a
## global script class` — nine false failures, which would have made this gate
## exactly as useless as the one it replaces.
static func _strip_class_name(src: String) -> String:
	var re := RegEx.new()
	re.compile("(?m)^[ \\t]*class_name[ \\t]+[A-Za-z_][A-Za-z0-9_]*[ \\t]*")
	return re.sub(src, "", true)


static func _walk(dir_path: String, scripts: Array[String], resources: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name) if dir_path != "res://" else "res://" + name
		if d.current_is_dir():
			if not SKIP_DIRS.has(name):
				_walk(full, scripts, resources)
		else:
			if name.ends_with(".gd"):
				scripts.append(full)
			elif name.ends_with(".tres") or name.ends_with(".tscn"):
				resources.append(full)
		name = d.get_next()
	d.list_dir_end()
