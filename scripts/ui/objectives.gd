extends CanvasLayer
## Per-zone challenge checklist HUD.
##
## Small, quiet, top-left. Gives the sandbox some direction without ever
## nagging — no popups, no forced camera, just a short list that ticks
## itself off. Hidden entirely if the player has turned hints off.

signal objective_done(id: StringName)

var _game = null  # Node, /root/Game
var _sfx = null   # Node, /root/Sfx
var _prefs = null # Node, /root/Prefs

var _objectives: Array = []  # Array[Dictionary] duck-typed
var _rows: Dictionary = {}   # StringName -> RichTextLabel

var _list_box: VBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	layer = 3
	_game = get_node_or_null("/root/Game")
	_sfx = get_node_or_null("/root/Sfx")
	_prefs = get_node_or_null("/root/Prefs")

	_build_ui()

	if _prefs != null:
		_prefs.pref_changed.connect(_on_pref_changed)
	_refresh_visibility()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(18, 76)
	root.custom_minimum_size = Vector2(300, 0)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.07, 0.32)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	_list_box = VBoxContainer.new()
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_box.add_theme_constant_override("separation", 3)
	_panel.add_child(_list_box)


## list: Array of Dictionaries like
## {"id": &"smash_carts", "text": "Wreck 8 shopping carts", "target": 8, "reward": 250}
func setup(list: Array) -> void:
	_objectives.clear()
	_rows.clear()
	for child in _list_box.get_children():
		child.queue_free()

	for entry in list:
		var obj: Dictionary = {
			"id": entry.get("id", &""),
			"text": String(entry.get("text", "")),
			"target": maxi(1, int(entry.get("target", 1))),
			"reward": int(entry.get("reward", 0)),
			"progress": 0,
			"done": false,
		}
		_objectives.append(obj)

		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.custom_minimum_size = Vector2(280, 0)
		rtl.add_theme_font_size_override("normal_font_size", 14)
		rtl.add_theme_color_override("default_color", Color(0.92, 0.94, 0.98, 0.78))
		rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
		rtl.add_theme_constant_override("outline_size", 3)
		_list_box.add_child(rtl)
		_rows[obj.id] = rtl

	_redraw_all()


func progress(id: StringName, amount: int = 1) -> void:
	for obj in _objectives:
		if obj.id != id:
			continue
		if obj.done:
			return
		obj.progress = mini(obj.target, int(obj.progress) + amount)
		if obj.progress >= obj.target:
			obj.done = true
			_redraw_row(obj)
			_on_complete(obj)
		else:
			_redraw_row(obj)
		return


func all_done() -> bool:
	if _objectives.is_empty():
		return false
	for obj in _objectives:
		if not obj.done:
			return false
	return true


func reset() -> void:
	for obj in _objectives:
		obj.progress = 0
		obj.done = false
	_redraw_all()


func _on_complete(obj: Dictionary) -> void:
	var id: StringName = obj.id
	_flash(id)
	if _game != null:
		_game.score(int(obj.reward), "OBJECTIVE")
	if _sfx != null:
		_sfx.play(&"score_blip_hi")
	objective_done.emit(id)


func _flash(id: StringName) -> void:
	var lbl: RichTextLabel = _rows.get(id, null)
	if lbl == null:
		return
	lbl.modulate = Color(1.5, 1.4, 0.75, 1.0)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.65)


func _redraw_all() -> void:
	for obj in _objectives:
		_redraw_row(obj)


func _redraw_row(obj: Dictionary) -> void:
	var lbl: RichTextLabel = _rows.get(obj.id, null)
	if lbl == null:
		return
	var box := "☑" if obj.done else "☐"
	var line := "%s %s  %d/%d" % [box, String(obj.text), int(obj.progress), int(obj.target)]
	if obj.done:
		lbl.text = "[color=#8a8f9c][s]%s[/s][/color]" % line
	else:
		lbl.text = line


func _on_pref_changed(key: StringName, _value) -> void:
	if key == &"show_hints":
		_refresh_visibility()


func _refresh_visibility() -> void:
	var show_it := true
	if _prefs != null:
		show_it = bool(_prefs.get_pref(&"show_hints", true))
	visible = show_it
