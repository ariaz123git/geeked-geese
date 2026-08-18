extends CanvasLayer
## THE BIRD BRAIN ALMANAC — the codex.
##
## Hard design rule: this never interrupts play. It is only ever opened
## deliberately (from the pause menu) via open(), and closed via close().
## Nothing in this file calls open() on its own.

signal closed()

var _subs = null      # Node, /root/Subs
var _unlocks = null   # Node, /root/Unlocks
var _tex = null       # Node, /root/Tex   (may be absent, guard every call)

var _open := false
var _ids: Array = []          # StringName, all library ids, sorted by display name
var _selected_index := -1
var _rows: Dictionary = {}    # StringName -> Button (list row)

var _backdrop: ColorRect
var _header_lbl: Label
var _scroll: ScrollContainer
var _list_box: VBoxContainer

var _icon_holder: Control
var _name_lbl: Label
var _mimics_lbl: Label
var _blurb_lbl: RichTextLabel
var _fact_lbl: RichTextLabel
var _mech_lbl: RichTextLabel
var _tol_lbl: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 40
	_subs = get_node_or_null("/root/Subs")
	_unlocks = get_node_or_null("/root/Unlocks")
	_tex = get_node_or_null("/root/Tex")
	_build_ui()
	visible = false


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	_build_list()
	_update_header()
	var keep := _selected_index
	_selected_index = -1
	if keep >= 0 and keep < _ids.size() and _is_unlocked(_ids[keep]):
		_select_index(keep)
	else:
		_move_selection(1)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


# ============================================================ data / list

func _is_unlocked(id) -> bool:
	if _unlocks != null:
		return bool(_unlocks.is_unlocked(id))
	if _subs != null and _subs.tolerance.has(id):
		return true
	return false


func _sort_by_display_name(a, b) -> bool:
	var na := ""
	var nb := ""
	if _subs != null:
		var ra = _subs.library.get(a, null)
		var rb = _subs.library.get(b, null)
		if ra != null:
			na = String(ra.display_name)
		if rb != null:
			nb = String(rb.display_name)
	return na < nb


func _build_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	_rows.clear()

	_ids = []
	if _subs != null:
		_ids = _subs.library.keys()
		_ids.sort_custom(_sort_by_display_name)

	for id in _ids:
		if _subs == null:
			continue
		var res = _subs.library[id]
		var unlocked := _is_unlocked(id)
		var row := _make_row(id, res, unlocked)
		_list_box.add_child(row)
		_rows[id] = row


func _update_header() -> void:
	var total := 0
	var count := 0
	if _subs != null:
		total = int(_subs.library.size())
	if _unlocks != null:
		count = _unlocks.unlocked_count()
	else:
		for id in _ids:
			if _is_unlocked(id):
				count += 1
	_header_lbl.text = "ALMANAC — %d / %d DISCOVERED" % [count, total]


# ============================================================ selection

func _move_selection(dir: int) -> void:
	if _ids.is_empty():
		_show_empty_detail()
		return
	var n := _ids.size()
	var idx := _selected_index
	for i in range(n):
		idx = (idx + dir + n) % n
		if _is_unlocked(_ids[idx]):
			_select_index(idx)
			return
	_show_empty_detail()


func _select_index(idx: int) -> void:
	if idx < 0 or idx >= _ids.size():
		return
	var id = _ids[idx]
	if not _is_unlocked(id):
		return

	if _selected_index >= 0 and _selected_index < _ids.size():
		var old_id = _ids[_selected_index]
		var old_row: Control = _rows.get(old_id, null)
		if old_row != null:
			old_row.add_theme_stylebox_override("normal", _row_style(Color(0, 0, 0, 0)))

	_selected_index = idx
	var row: Control = _rows.get(id, null)
	if row != null:
		row.add_theme_stylebox_override("normal", _row_style(Color(1.0, 0.85, 0.3, 0.18)))
		if _scroll != null:
			_scroll.ensure_control_visible(row)
	_show_detail(id)


func _on_row_pressed(id) -> void:
	var idx: int = _ids.find(id)
	if idx >= 0:
		_select_index(idx)


# ============================================================ detail pane

func _show_detail(id) -> void:
	if _subs == null:
		return
	var res = _subs.library.get(id, null)
	if res == null:
		return

	_name_lbl.text = String(res.display_name).to_upper()
	_mimics_lbl.text = "MIMICS: %s" % String(res.mimics)
	_blurb_lbl.text = "[i]%s[/i]" % _bbcode_escape(String(res.blurb))
	_fact_lbl.text = _bbcode_escape(String(res.codex_fact))
	_mech_lbl.text = _bbcode_escape(_mechanics_text(res))

	var tol := 0
	if _subs.tolerance.has(id):
		tol = int(_subs.tolerance[id])
	if tol > 0:
		var plural := "" if tol == 1 else "s"
		_tol_lbl.text = "TOLERANCE: %d dose%s taken on this bird — diminishing returns, escalating downside." % [tol, plural]
		_tol_lbl.visible = true
	else:
		_tol_lbl.text = ""
		_tol_lbl.visible = false

	for c in _icon_holder.get_children():
		c.queue_free()
	var icon_tex: Texture2D = null
	if _tex != null:
		icon_tex = _tex.icon_for(id)
	if icon_tex != null:
		var tr := TextureRect.new()
		# EXPAND_KEEP_SIZE (the default) makes a TextureRect demand the
		# texture's full 128px regardless of custom_minimum_size, which blew the
		# list rows apart. IGNORE_SIZE lets the container drive the size.
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture = icon_tex
		tr.custom_minimum_size = Vector2(64, 64)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_holder.add_child(tr)
	else:
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(64, 64)
		cr.color = res.tint
		_icon_holder.add_child(cr)


func _show_empty_detail() -> void:
	_name_lbl.text = "???"
	_mimics_lbl.text = ""
	_blurb_lbl.text = "[i]Nothing discovered yet. Go eat something.[/i]"
	_fact_lbl.text = ""
	_mech_lbl.text = ""
	_tol_lbl.visible = false
	if _icon_holder != null:
		for c in _icon_holder.get_children():
			c.queue_free()


func _bbcode_escape(s: String) -> String:
	return s.replace("[", "[lb]")


## Plain-language description of every mutation field that differs from its
## neutral default. Only fields that actually change something get a line.
func _mechanics_text(res) -> String:
	var lines: Array = []

	var input_lag: float = res.input_lag
	if input_lag > 0.001:
		lines.append("Input lag: %.2fs" % input_lag)

	var drift: float = res.drift
	if drift > 0.001:
		lines.append("Drift: +%.0f%%" % (drift * 100.0))

	var flap_mult: float = res.flap_mult
	if absf(flap_mult - 1.0) > 0.001:
		lines.append("Flap power x%.2f" % flap_mult)

	var speed_mult: float = res.speed_mult
	if absf(speed_mult - 1.0) > 0.001:
		lines.append("Speed x%.2f" % speed_mult)

	var gravity_mult: float = res.gravity_mult
	if absf(gravity_mult - 1.0) > 0.001:
		lines.append("Gravity x%.2f" % gravity_mult)

	var turn_mult: float = res.turn_mult
	if absf(turn_mult - 1.0) > 0.001:
		lines.append("Turning x%.2f" % turn_mult)

	var time_scale: float = res.time_scale
	if absf(time_scale - 1.0) > 0.001:
		lines.append("Time scale x%.2f" % time_scale)

	var scale_amp: float = res.scale_amp
	if scale_amp > 0.001:
		var scale_period: float = res.scale_period
		lines.append("Size pulses (amplitude %.2f, every %.0fs)" % [scale_amp, scale_period])

	if bool(res.ragdoll_landings):
		lines.append("Landings ragdoll")
	if bool(res.cannot_idle):
		lines.append("Can't hold still")
	if bool(res.smash_through):
		lines.append("Smashes through props on contact")
	if bool(res.grid_snap):
		lines.append("Movement snaps to 90°")
	if bool(res.hud_amnesia):
		lines.append("HUD blanks out")

	var camera_detach: float = res.camera_detach
	if camera_detach > 0.001:
		lines.append("Camera detaches")

	if bool(res.no_fall_damage):
		lines.append("No fall damage")
	if bool(res.aggro_cats):
		lines.append("Cats nearby go berserk")
	if bool(res.no_early_exit):
		lines.append("Cannot end early — you finish the ride")

	var duration: float = res.duration
	var comedown: float = res.comedown
	lines.append("Duration %.0fs / comedown %.0fs" % [duration, comedown])

	var tol_gain: int = int(res.tolerance_gain)
	lines.append("Tolerance +%d per dose" % tol_gain)

	var out := ""
	for i in range(lines.size()):
		out += "• " + String(lines[i])
		if i < lines.size() - 1:
			out += "\n"
	return out


# ============================================================ building UI

func _row_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


func _make_row(id, res, unlocked: bool) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not unlocked
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	btn.add_theme_stylebox_override("normal", _row_style(Color(0, 0, 0, 0)))
	btn.add_theme_stylebox_override("hover", _row_style(Color(1, 1, 1, 0.06)))
	btn.add_theme_stylebox_override("pressed", _row_style(Color(1, 1, 1, 0.10)))
	btn.add_theme_stylebox_override("disabled", _row_style(Color(0, 0, 0, 0)))
	btn.add_theme_stylebox_override("focus", _row_style(Color(0, 0, 0, 0)))

	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 10)
	btn.add_child(hb)

	var row_icon_holder := Control.new()
	row_icon_holder.custom_minimum_size = Vector2(32, 32)
	row_icon_holder.clip_contents = true
	row_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(row_icon_holder)

	var icon_tex: Texture2D = null
	if unlocked and _tex != null:
		icon_tex = _tex.icon_for(id)
	if icon_tex != null:
		var tr := TextureRect.new()
		# EXPAND_KEEP_SIZE (the default) makes a TextureRect demand the
		# texture's full 128px regardless of custom_minimum_size, which blew the
		# list rows apart. IGNORE_SIZE lets the container drive the size.
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture = icon_tex
		tr.custom_minimum_size = Vector2(32, 32)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_icon_holder.add_child(tr)
	else:
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(32, 32)
		cr.color = res.tint if unlocked else Color(0.12, 0.12, 0.15)
		row_icon_holder.add_child(cr)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.clip_text = true
	if unlocked:
		name_lbl.text = String(res.display_name)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	else:
		name_lbl.text = "???"
		name_lbl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.48))
	vb.add_child(name_lbl)

	var mimics_lbl := Label.new()
	mimics_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mimics_lbl.add_theme_font_size_override("font_size", 12)
	mimics_lbl.clip_text = true
	if unlocked:
		mimics_lbl.text = String(res.mimics)
		mimics_lbl.add_theme_color_override("font_color", Color(0.62, 0.64, 0.72))
	else:
		mimics_lbl.text = "undiscovered"
		mimics_lbl.add_theme_color_override("font_color", Color(0.32, 0.32, 0.38))
	vb.add_child(mimics_lbl)

	if unlocked:
		btn.pressed.connect(_on_row_pressed.bind(id))

	return btn


func _section_header(txt: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", col)
	return lbl


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.03, 0.88)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 12)
	main_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(main_vb)

	_header_lbl = Label.new()
	_header_lbl.text = "ALMANAC — 0 / 0 DISCOVERED"
	_header_lbl.add_theme_font_size_override("font_size", 26)
	_header_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_header_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_header_lbl.add_theme_constant_override("outline_size", 4)
	main_vb.add_child(_header_lbl)

	main_vb.add_child(_rule())

	var body_hb := HBoxContainer.new()
	body_hb.add_theme_constant_override("separation", 22)
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vb.add_child(body_hb)

	# ---------- left pane: the list ----------
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(320, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_sb := StyleBoxFlat.new()
	left_sb.bg_color = Color(0.07, 0.07, 0.10, 0.94)
	left_sb.set_corner_radius_all(10)
	left_sb.set_content_margin_all(8)
	left_panel.add_theme_stylebox_override("panel", left_sb)
	body_hb.add_child(left_panel)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list_box)

	# ---------- right pane: the detail ----------
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_sb := StyleBoxFlat.new()
	right_sb.bg_color = Color(0.09, 0.09, 0.13, 0.94)
	right_sb.set_corner_radius_all(10)
	right_sb.set_content_margin_all(24)
	right_panel.add_theme_stylebox_override("panel", right_sb)
	body_hb.add_child(right_panel)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(right_scroll)

	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right_vb)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	right_vb.add_child(top_row)

	_icon_holder = Control.new()
	_icon_holder.custom_minimum_size = Vector2(64, 64)
	_icon_holder.clip_contents = true
	top_row.add_child(_icon_holder)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_col)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 30)
	_name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	_name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_name_lbl.add_theme_constant_override("outline_size", 4)
	name_col.add_child(_name_lbl)

	_mimics_lbl = Label.new()
	_mimics_lbl.add_theme_font_size_override("font_size", 15)
	_mimics_lbl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.82))
	name_col.add_child(_mimics_lbl)

	_blurb_lbl = RichTextLabel.new()
	_blurb_lbl.bbcode_enabled = true
	_blurb_lbl.fit_content = true
	_blurb_lbl.scroll_active = false
	_blurb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blurb_lbl.add_theme_font_size_override("normal_font_size", 16)
	_blurb_lbl.add_theme_color_override("default_color", Color(0.83, 0.85, 0.92))
	right_vb.add_child(_blurb_lbl)

	right_vb.add_child(_rule())

	right_vb.add_child(_section_header("WHAT'S ACTUALLY TRUE", Color(0.55, 0.85, 0.98)))

	_fact_lbl = RichTextLabel.new()
	_fact_lbl.bbcode_enabled = true
	_fact_lbl.fit_content = true
	_fact_lbl.scroll_active = false
	_fact_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fact_lbl.custom_minimum_size = Vector2(560, 0)
	_fact_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fact_lbl.add_theme_font_size_override("normal_font_size", 18)
	_fact_lbl.add_theme_color_override("default_color", Color(0.95, 0.96, 0.99))
	right_vb.add_child(_fact_lbl)

	right_vb.add_child(_rule())

	right_vb.add_child(_section_header("MECHANICS", Color(0.95, 0.75, 0.35)))

	_mech_lbl = RichTextLabel.new()
	_mech_lbl.bbcode_enabled = true
	_mech_lbl.fit_content = true
	_mech_lbl.scroll_active = false
	_mech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mech_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mech_lbl.add_theme_font_size_override("normal_font_size", 15)
	_mech_lbl.add_theme_color_override("default_color", Color(0.85, 0.87, 0.92))
	right_vb.add_child(_mech_lbl)

	_tol_lbl = Label.new()
	_tol_lbl.add_theme_font_size_override("font_size", 14)
	_tol_lbl.add_theme_color_override("font_color", Color(0.96, 0.48, 0.42))
	_tol_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tol_lbl.visible = false
	right_vb.add_child(_tol_lbl)


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1.0, 1.0, 1.0, 0.12)
	r.custom_minimum_size = Vector2(0, 1)
	return r
