extends SceneTree
## Headless project validator for Godot 4.7.x
##
##   godot --headless --no-header --path . --script tools/validate_project.gd
##
## Loads every .gd and every .tscn in the project, instantiates each scene, adds it
## to the tree (which runs _ready and resolves @onready $NodePaths), then frees it.
##
## Exit 0 = everything compiled, loaded and instantiated.
##
## IMPORTANT: exit code alone is NOT sufficient. Some breakage — a dangling
## ext_resource, a missing $NodePath — only surfaces as printed errors while the
## process still exits 0. Your build script MUST also fail on any "ERROR:" or
## "SCRIPT ERROR:" appearing on stderr. verify.ps1 does this.
##
## Why not `--check-only`? It reports a false failure on every script that
## references an autoload (autoloads are not registered at that point in startup),
## and it passes typo'd method names unless warnings-as-errors is configured.
## This script runs after autoloads exist, so it has neither problem.

## NOTE ON DirAccess: game code must use ResourceLoader.list_directory(), because
## DirAccess returns *.remap names in an exported build. This file is editor-only
## tooling that never ships and only ever runs against an unexported source tree,
## so DirAccess is correct here. Do not "fix" it.

const SKIP_DIRS: Array[String] = ["addons", ".godot", ".git", "test", "shots"]

var _failures: Array[String] = []


func _initialize() -> void:
	@warning_ignore("unsafe_cast")
	var self_path: String = (get_script() as Script).resource_path

	var scripts: Array[String] = []
	var scenes: Array[String] = []
	_scan("res://", scripts, scenes)

	for p: String in scripts:
		if p == self_path:
			continue  # loading the running MainLoop script crashes Godot 4.7.1
		if ResourceLoader.load(p, "Script", ResourceLoader.CACHE_MODE_IGNORE) == null:
			_failures.append("SCRIPT FAILED TO LOAD: " + p)

	for p: String in scenes:
		var ps: PackedScene = ResourceLoader.load(p, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		if ps == null:
			_failures.append("SCENE FAILED TO LOAD: " + p)
			continue
		if not ps.can_instantiate():
			_failures.append("SCENE CANNOT INSTANTIATE: " + p)
			continue
		var inst: Node = ps.instantiate()
		if inst == null:
			_failures.append("SCENE INSTANTIATE RETURNED NULL: " + p)
			continue
		root.add_child(inst)
		await process_frame
		await physics_frame
		inst.queue_free()
		await process_frame

	print("--- checked %d scripts, %d scenes ---" % [scripts.size(), scenes.size()])

	if _failures.is_empty():
		print("VALIDATION OK")
		quit(0)
		return  # quit() only schedules the exit; it does not halt execution

	for f: String in _failures:
		printerr(f)
	print("VALIDATION FAILED: %d problem(s)" % _failures.size())
	quit(1)


func _scan(dir_path: String, scripts: Array[String], scenes: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var fname: String = d.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full: String = dir_path.path_join(fname)
			if d.current_is_dir():
				if not SKIP_DIRS.has(fname):
					_scan(full, scripts, scenes)
			elif fname.ends_with(".gd"):
				scripts.append(full)
			elif fname.ends_with(".tscn"):
				scenes.append(full)
		fname = d.get_next()
	d.list_dir_end()
