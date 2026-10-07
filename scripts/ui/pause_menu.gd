extends CanvasLayer
## Pause + settings.
##
## Opens on ui_cancel (Escape / Start). Everything here is built in code —
## dark translucent panel, generous padding, no default Godot theme look.
##
## IMPORTANT for the integrator: this node does NOT re-capture the mouse on
## close. It only releases it (MOUSE_MODE_VISIBLE) on open, and on close
## emits `resumed(recapture_mouse)` with whatever the mouse mode was before
## it opened — the caller decides whether/how to recapture. This matters:
## a keyboard-and-mouse player alt-tabbing back mid pause shouldn't get their
## cursor yanked into MOUSE_MODE_CAPTURED against their will.

signal resumed(recapture_mouse: bool)
signal almanac_requested()
signal controls_requested()
signal flock_requested()
signal restart_requested()

## RESTART IS A LANDMINE NOW. A run is eight legs and about forty-five minutes,
## so the button that throws it away asks twice. The first press arms it and
## relabels it; the second within this window does it. Reverting on its own
## means an armed button never sits there waiting to be leant on.
const RESTART_ARM_SECS := 3.0

const CONTROLS := {
	"Move": "WASD / Left Stick",
	"Flap": "Space / A",
	"Dive": "Shift / RB",
	"Honk": "H or F / B",
	"Eat / dose (hold)": "E / X",
	"Share": "Q / Y",
	"Name the DD (at the pen)": "G / LB",
	"Objectives": "Tab / Back",
	"Restart": "R",
	"Skip / continue": "Enter / A",
	"Pause": "Esc / Start",
	"Camera": "J / K / Right Stick",
}

var _prefs = null  # Node, /root/Prefs

var _open := false
## Set true by hide_for_overlay() when a caller (e.g. the Almanac) wants to
## take over the screen while we stay logically "open" (game still paused).
## While true we ignore ui_cancel entirely and let the overlay own it.
var _suppressed := false
var _was_mouse_captured := false
var _showing_settings := false

var _main_panel: PanelContainer
var _settings_panel: PanelContainer
var _best_lbl: Label
var _restart_btn: Button
var _resume_btn: Button
var _settings_btn: Button
var _model_opt: OptionButton
var _restart_armed := 0.0
var _main_scroll: ScrollContainer
var _main_vb: VBoxContainer

var _slider_refs: Dictionary = {}    # StringName -> HSlider
var _quick_volume: HSlider = null    ## the main screen's master volume, D-089
var _checkbox_refs: Dictionary = {}  # StringName -> CheckBox
## Every focusable row of the settings panel, top to bottom. See `_chain_focus`.
var _settings_order: Array[Control] = []


func _ready() -> void:
	# ALWAYS, NOT WHEN_PAUSED, AND THE DIFFERENCE IS THE WHOLE MENU.
	#
	# `process_mode` gates `_input()` exactly as it gates `_process()`. Under
	# PROCESS_MODE_WHEN_PAUSED this node is inert whenever the tree is running
	# — and the only thing that pauses the tree is `_open_menu()`, below. So
	# the menu could close itself and could never open itself, and Escape did
	# nothing for the life of the project. The human found it by pressing
	# Escape; twelve gates were green at the time, because not one of them had
	# ever sent an input event through the viewport.
	#
	# `tools/inputtest.gd::_pause_menu_test()` is the check, and it presses the
	# key through `Input.parse_input_event()` rather than calling `open()`.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_prefs = get_node_or_null("/root/Prefs")
	_build_ui()
	visible = false


func _input(event: InputEvent) -> void:
	if _suppressed:
		return
	if event.is_action_pressed("ui_cancel"):
		if _open:
			_close()
		else:
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	# On either panel: the main screen has a volume slider too (D-089), and this
	# only ever moves a focused slider inside this menu.
	if _open:
		_step_focused_slider(event)


## A PAD OR AN ARROW KEY MOVES A SLIDER ONE TWENTIETH OF ITS RANGE.
##
## Left alone, a focused Slider moves by its `step` — 0.01 on every 0..1 row
## here — so measured with a pad it was 95 to 100 presses end to end, and pad
## buttons do not auto-repeat the way a held key does. Godot 4.7 has no separate
## keyboard step to set: `custom_step` was Godot 3, and the first draft of this
## fix assigned it and raised on every row (the compile gate passed it, because
## a property write on a native type is resolved at run time). Raising `step`
## instead would coarsen the mouse drag and knock Field of view's 68° default off
## its grid. So the menu takes left / right itself, before the slider sees them.
## Echoes count, so a held arrow key still sweeps. D-056.
func _step_focused_slider(event: InputEvent) -> void:
	var dir := 0.0
	if event.is_action_pressed("ui_right", true):
		dir = 1.0
	elif event.is_action_pressed("ui_left", true):
		dir = -1.0
	if dir == 0.0:
		return
	var s := get_viewport().gui_get_focus_owner() as HSlider
	if s == null or not is_ancestor_of(s):
		return
	var nudge: float = maxf(s.step, snappedf((s.max_value - s.min_value) / 20.0, s.step))
	s.value = clampf(s.value + dir * nudge, s.min_value, s.max_value)
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _open


## Open it from code. The menu normally opens itself off ui_cancel; this exists
## for the render probe, which has no keyboard.
func open() -> void:
	_open_menu()


## Ticks every frame now that `process_mode` is ALWAYS, and the early return is
## what keeps that free: `_restart_armed` is only ever set while the menu is up,
## so this is a single float compare per frame the rest of the time. It used to
## lean on WHEN_PAUSED for the same effect, which cost the game its pause menu.
func _process(delta: float) -> void:
	if _restart_armed <= 0.0:
		return
	# Wall-clock: a substance can leave Engine.time_scale at 0.35 and a
	# three-second confirmation window that is secretly nine is a trap.
	_restart_armed = maxf(0.0, _restart_armed - delta / maxf(Engine.time_scale, 0.05))
	if _restart_armed <= 0.0:
		_disarm_restart()


## Hide our visuals while keeping the game paused, handing the screen to an
## overlay opened from one of our buttons (the Almanac). Call show_after_
## overlay() when that overlay reports closed().
func hide_for_overlay() -> void:
	_suppressed = true
	visible = false


func show_after_overlay() -> void:
	_suppressed = false
	visible = true
	_show_main()
	_refresh_settings_display()
	_focus(_resume_btn)


func _open_menu() -> void:
	if _open:
		return
	_open = true
	_disarm_restart()
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_show_main()
	_refresh_settings_display()
	_best_lbl.text = "BEST CHAOS: %d" % _best_chaos()
	visible = true
	_focus(_resume_btn)


func _close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	resumed.emit(_was_mouse_captured)


## THE MENU TAKES FOCUS WHEN IT OPENS.
##
## Nothing had focus when the menu opened, and the D-pad only moves focus once
## something has it — so on a pad not one button in here could be pressed. On a
## keyboard the arrows did nothing either. RESUME takes it on open, which also
## makes Space or A a one-press resume. D-055.
##
## There is deliberately no matching release on close, and that was measured
## rather than assumed. The worry was real — a focused Button answers
## `ui_accept`, which is Space, the flap, so an armed RESTART RUN still holding
## focus behind a closed menu would be one flap from ending the run. But Godot
## 4.7.1 releases a Control's focus when its CanvasLayer hides: an explicit
## release was written, disabled as a canary, and `inputtest` still saw nothing
## focused after the close. A release that changes nothing is not a guard.
func _focus(c: Control) -> void:
	if c == null or not is_instance_valid(c) or not visible:
		return
	c.grab_focus.call_deferred()


func _show_main() -> void:
	_disarm_restart()
	_showing_settings = false
	_main_panel.visible = true
	_settings_panel.visible = false
	# The first screen has a VOLUME slider of its own (D-089); without this it
	# showed what Settings' Master row had just replaced, until the menu reopened.
	_refresh_settings_display()
	_fit_main_panel()


## A ScrollContainer reports no minimum height in the direction it scrolls, so
## inside a CenterContainer the panel would collapse to its padding. Ask the
## content how tall it wants to be and grant that, up to what the window has.
func _fit_main_panel() -> void:
	if _main_scroll == null or _main_vb == null:
		return
	if not is_inside_tree():
		return
	var want: float = _main_vb.get_combined_minimum_size().y
	var room: float = get_viewport().get_visible_rect().size.y - 96.0
	_main_scroll.custom_minimum_size.y = minf(want, maxf(200.0, room))


func _show_settings() -> void:
	_showing_settings = true
	_main_panel.visible = false
	_settings_panel.visible = true
	_refresh_settings_display()
	_focus(_model_opt)


## BACK, from settings. Focus returns to the button that went there, so a pad
## player walking the menu is not thrown back to the top of it.
func _back_from_settings() -> void:
	_show_main()
	_focus(_settings_btn)


## Two presses, not one. The first arms and relabels; the second inside
## RESTART_ARM_SECS actually throws the run away. The same two-press contract as
## the `R` key in main.gd, with a LONGER window on purpose: R's is 1.5 s
## (`RESTART_CONFIRM_MS`) because it is pressed mid-play, where an armed restart
## should not linger into the next stretch of flight; this one is pressed on a
## paused menu, and the button has just turned into a warning the player has to
## read before pressing it again. This comment used to say the two "behave
## identically"; they never did (D-061 found it, D-080 says why it stays).
func _on_restart_pressed() -> void:
	if _restart_armed > 0.0:
		_disarm_restart()
		restart_requested.emit()
		_close()
		return
	_restart_armed = RESTART_ARM_SECS
	if _restart_btn != null and is_instance_valid(_restart_btn):
		_restart_btn.text = "PRESS AGAIN — THIS ENDS THE RUN"
		_style_button(_restart_btn, Color(0.95, 0.30, 0.28))
		_restart_btn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.68))


func _disarm_restart() -> void:
	_restart_armed = 0.0
	if _restart_btn == null or not is_instance_valid(_restart_btn):
		return
	_restart_btn.text = "RESTART RUN"
	_style_button(_restart_btn, Color(0.95, 0.55, 0.3))
	_restart_btn.remove_theme_color_override("font_color")


func _best_chaos() -> int:
	if _prefs == null:
		return 0
	return int(_prefs.get_pref(&"best_chaos", 0))


# ============================================================ building UI

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.03, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_main_panel = _build_main_panel()
	center.add_child(_main_panel)

	_settings_panel = _build_settings_panel()
	center.add_child(_settings_panel)

	_show_main()


func _frame_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.95)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 1.0, 1.0, 0.12)
	return sb


func _header_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	return lbl


func _menu_button(title: String, callback: Callable, accent: Color = Color(0.5, 0.65, 0.95)) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.custom_minimum_size = Vector2(0, 46)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 19)
	btn.pressed.connect(callback)
	_style_button(btn, accent)
	return btn


## Flat panel + a coloured left accent bar per action, so the menu reads as
## something built for this game instead of stock Godot buttons.
func _style_button(btn: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.14, 0.19, 0.92)
	normal.set_corner_radius_all(8)
	normal.border_width_left = 4
	normal.border_color = accent
	normal.set_content_margin_all(10)
	normal.content_margin_left = 18
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.19, 0.205, 0.27, 0.96)
	hover.set_corner_radius_all(8)
	hover.border_width_left = 4
	hover.border_color = accent.lightened(0.15)
	hover.set_content_margin_all(10)
	hover.content_margin_left = 18
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.09, 0.095, 0.13, 0.96)
	pressed.set_corner_radius_all(8)
	pressed.border_width_left = 4
	pressed.border_color = accent.darkened(0.2)
	pressed.set_content_margin_all(10)
	pressed.content_margin_left = 18
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.13, 0.14, 0.19, 0.92)
	focus.set_corner_radius_all(8)
	focus.border_width_left = 4
	focus.border_width_top = 1
	focus.border_width_right = 1
	focus.border_width_bottom = 1
	focus.border_color = accent.lightened(0.3)
	focus.set_content_margin_all(10)
	focus.content_margin_left = 18
	btn.add_theme_stylebox_override("focus", focus)


func _build_main_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_stylebox_override("panel", _frame_stylebox())

	# The panel's content is taller than a 720p window — six buttons, a nine-row
	# control table and a score line — so it ran off the bottom of the screen and
	# took BEST CHAOS and half the control reference with it. It scrolls now, and
	# _fit_main_panel() caps the height to the window on open so the scroll only
	# ever engages when it is actually needed.
	_main_scroll = ScrollContainer.new()
	_main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_main_scroll)

	# The vertical scrollbar is drawn OVER the right edge of the content, so the
	# buttons need to stop short of it or their accent frames run underneath.
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 12)
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_scroll.add_child(gutter)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 11)
	gutter.add_child(vb)
	_main_vb = vb

	vb.add_child(_header_label("PAUSED"))

	_resume_btn = _menu_button("RESUME", _close, Color(0.35, 0.85, 0.55))
	vb.add_child(_resume_btn)
	vb.add_child(_menu_button("ALMANAC", func(): almanac_requested.emit(), Color(0.55, 0.75, 0.95)))
	# The controls reference is the safety net for anyone who skipped the
	# briefing cards, so it sits on the top level of the menu, not buried in
	# settings. This is the whole reason a player can pause mid-flight and
	# find out what Q does.
	vb.add_child(_menu_button("CONTROLS", func(): controls_requested.emit(), Color(0.45, 0.85, 0.85)))
	# The flock is the run's score and the only thing the ending is made of, so
	# checking on it sits next to the codex rather than inside settings. Same
	# hand-off pattern as ALMANAC: we hide, it opens, we come back.
	vb.add_child(_menu_button("FLOCK", func(): flock_requested.emit(), Color(0.55, 0.92, 0.62)))
	_settings_btn = _menu_button("SETTINGS", _show_settings, Color(0.85, 0.75, 0.35))
	vb.add_child(_settings_btn)
	_restart_btn = _menu_button("RESTART RUN", _on_restart_pressed, Color(0.95, 0.55, 0.3))
	vb.add_child(_restart_btn)
	vb.add_child(_menu_button("QUIT", func(): get_tree().quit(), Color(0.9, 0.35, 0.35)))
	vb.add_child(_volume_row())

	vb.add_child(_rule())

	var controls_header := Label.new()
	controls_header.text = "CONTROLS"
	controls_header.add_theme_font_size_override("font_size", 14)
	controls_header.add_theme_color_override("font_color", Color(0.55, 0.78, 0.96))
	vb.add_child(controls_header)

	for action in CONTROLS.keys():
		var key_label: String = CONTROLS[action]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var a := Label.new()
		a.text = String(action)
		a.custom_minimum_size = Vector2(180, 0)
		a.add_theme_font_size_override("font_size", 13)
		a.add_theme_color_override("font_color", Color(0.82, 0.84, 0.89))
		row.add_child(a)

		var b := Label.new()
		b.text = key_label
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Color(0.56, 0.58, 0.63))
		row.add_child(b)

		vb.add_child(row)

	vb.add_child(_rule())

	_best_lbl = Label.new()
	_best_lbl.text = "BEST CHAOS: 0"
	_best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_lbl.add_theme_font_size_override("font_size", 17)
	_best_lbl.add_theme_color_override("font_color", Color(0.99, 0.82, 0.25))
	vb.add_child(_best_lbl)

	return panel


## VOLUME, ON THE FIRST SCREEN ESC OPENS (D-089).
##
## Settings has had Master, SFX and Music sliders for weeks, and the human still
## asked for "a volume slider in settings" — they are one press deeper than a
## player looks. So the master volume sits here too, under the buttons, where it
## is on screen at 720p before the menu scrolls. It is the same `master_volume`
## pref the Settings row writes, and `_refresh_settings_display()` keeps the two
## in step whenever either panel is shown (`_show_main`, `_show_settings`,
## `_open_menu`; inputtest drives both directions). Arrow keys and the D-pad move it a
## twentieth at a time, through `_step_focused_slider()`.
func _volume_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = "VOLUME"
	lbl.custom_minimum_size = Vector2(96, 0)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(180, 24)
	if _prefs != null:
		slider.value = float(_prefs.get_pref(&"master_volume", 1.0))
	row.add_child(slider)

	var val := Label.new()
	val.custom_minimum_size = Vector2(48, 0)
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	val.text = "%d%%" % roundi(slider.value * 100.0)
	row.add_child(val)

	slider.value_changed.connect(func(v: float):
		val.text = "%d%%" % roundi(v * 100.0)
		if _prefs != null:
			_prefs.set_pref(&"master_volume", v)
	)
	_quick_volume = slider
	return row


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1.0, 1.0, 1.0, 0.12)
	r.custom_minimum_size = Vector2(0, 2)
	return r


func _build_settings_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _frame_stylebox())

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	vb.add_child(_header_label("SETTINGS"))

	_model_row(vb)
	vb.add_child(_rule())
	_slider_row(vb, "Mouse sensitivity", &"mouse_sensitivity", 0.05, 1.0, 0.01, "%.2f")
	_checkbox_row(vb, "Invert Y", &"invert_y")
	_slider_row(vb, "Field of view", &"fov", 50.0, 100.0, 1.0, "%.0f°")
	vb.add_child(_rule())
	_slider_row(vb, "Master volume", &"master_volume", 0.0, 1.0, 0.01, "%.2f")
	_slider_row(vb, "SFX volume", &"sfx_volume", 0.0, 1.0, 0.01, "%.2f")
	_slider_row(vb, "Music volume", &"music_volume", 0.0, 1.0, 0.01, "%.2f")
	vb.add_child(_rule())
	_slider_row(vb, "Screen shake", &"screen_shake", 0.0, 1.0, 0.01, "%.2f")
	_slider_row(vb, "FX intensity", &"fx_intensity", 0.0, 1.0, 0.01, "%.2f")
	_checkbox_row(vb, "Show hints", &"show_hints")

	vb.add_child(_rule())

	var back_btn := _menu_button("BACK", _back_from_settings)
	vb.add_child(back_btn)
	_settings_order.append(back_btn)
	_chain_focus(_settings_order)

	return panel


## THE D-PAD WALKS THE ROWS IN THE ORDER THEY ARE DRAWN.
##
## Godot picks a focus neighbour geometrically when none is set, and on this
## panel geometry chose wrong: a CheckBox sits at the left of its row and a
## slider in the middle of the next, so D-pad down from Mouse sensitivity went
## straight to Field of view. Walked with a pad on 2026-09-25 the order was
## art style, six sliders, BACK — INVERT Y AND SHOW HINTS COULD NOT BE REACHED
## AT ALL. `inputtest.gd::_settings_walk()` holds the order now. D-056.
func _chain_focus(order: Array[Control]) -> void:
	for i in order.size():
		var c: Control = order[i]
		if i > 0:
			c.focus_neighbor_top = c.get_path_to(order[i - 1])
			c.focus_previous = c.focus_neighbor_top
		if i < order.size() - 1:
			c.focus_neighbor_bottom = c.get_path_to(order[i + 1])
			c.focus_next = c.focus_neighbor_bottom


## Goose model picker. Both meshes expose an identical API, so switching is a
## live rebuild with no reload — the change is visible the moment you close the
## menu. Also swaps the cats and the people, because a faceted goose standing
## next to smooth-primitive humans looks like a bug rather than a style.
func _model_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "Art style"
	lbl.custom_minimum_size = Vector2(170, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("Low-poly (faceted)")
	opt.add_item("Classic (smooth)")
	var prefs := get_node_or_null("/root/Prefs")
	var cur := "lowpoly"
	if prefs:
		cur = str(prefs.get_pref(&"goose_model", "lowpoly"))
	opt.selected = 1 if cur == "classic" else 0
	_model_opt = opt
	_settings_order.append(opt)
	opt.item_selected.connect(func(i: int):
		var p2 := get_node_or_null("/root/Prefs")
		if p2:
			p2.set_pref(&"goose_model", "classic" if i == 1 else "lowpoly"))
	row.add_child(opt)

	var note := Label.new()
	note.text = "Cats and people follow the goose. Takes effect immediately."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	parent.add_child(note)


func _slider_row(parent: Control, title: String, key: StringName, min_v: float, max_v: float, step: float, fmt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(170, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	_settings_order.append(slider)
	slider.custom_minimum_size = Vector2(190, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var initial: float = min_v
	if _prefs != null:
		initial = float(_prefs.get_pref(key, min_v))
	slider.value = initial
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = fmt % initial
	val_lbl.custom_minimum_size = Vector2(55, 0)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float):
		val_lbl.text = fmt % v
		if _prefs != null:
			_prefs.set_pref(key, v)
	)

	_slider_refs[key] = slider


func _checkbox_row(parent: Control, title: String, key: StringName) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var cb := CheckBox.new()
	cb.text = title
	cb.add_theme_font_size_override("font_size", 14)
	cb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))

	var initial := false
	if _prefs != null:
		initial = bool(_prefs.get_pref(key, false))
	cb.button_pressed = initial
	row.add_child(cb)
	_settings_order.append(cb)

	cb.toggled.connect(func(v: bool):
		if _prefs != null:
			_prefs.set_pref(key, v)
	)

	_checkbox_refs[key] = cb


func _refresh_settings_display() -> void:
	if _prefs == null:
		return
	for key in _slider_refs.keys():
		var s: HSlider = _slider_refs[key]
		s.value = float(_prefs.get_pref(key, s.value))
	for key in _checkbox_refs.keys():
		var cb: CheckBox = _checkbox_refs[key]
		cb.button_pressed = bool(_prefs.get_pref(key, cb.button_pressed))
	if _quick_volume != null and is_instance_valid(_quick_volume):
		_quick_volume.value = float(_prefs.get_pref(&"master_volume", _quick_volume.value))
