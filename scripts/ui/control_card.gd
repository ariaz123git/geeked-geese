extends CanvasLayer
## THE CONTROLS REFERENCE — both schemes, one screen, no scrolling.
##
## The safety net. Research is unambiguous that a meaningful share of players
## skip or blink through anything you show them up front, so the answer is not
## a longer tutorial, it's a reference they can get to in one keypress from the
## pause menu, forever.
##
## Deliberately NOT a settings screen, NOT scrollable, NOT paginated. If a
## scheme ever grows past what fits here, that's a signal about the scheme.
##
## Opened from the pause menu (see ONBOARDING_NOTES for the six-line patch) or
## from anywhere via open(). Mirrors the Almanac's handoff contract exactly:
## open(), close(), is_open(), and a `closed` signal.

signal closed()

const BRIEF := preload("res://scripts/ui/briefing.gd")
const DEFS := preload("res://scripts/ui/briefing_defs.gd")

const ACCENT_GROUND := Color(0.99, 0.78, 0.28)
const ACCENT_AIR := Color(0.55, 0.78, 0.98)

var _open := false
var _paused_by_us := false
var _restore_mouse: int = Input.MOUSE_MODE_VISIBLE

var _backdrop: ColorRect
var _card: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Above the pause menu (30) and the Almanac (40) — this is opened from them.
	layer = 41
	visible = false

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.035, 0.90)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_card = RefPanel.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.build()
	add_child(_card)

	get_viewport().size_changed.connect(_reflow)
	_reflow()


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	_restore_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Openable straight from gameplay as well as from the pause menu, so only
	# pause if somebody else hasn't already.
	_paused_by_us = not get_tree().paused
	if _paused_by_us:
		get_tree().paused = true
	_reflow()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false
		Input.mouse_mode = _restore_mouse
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var is_key := event is InputEventKey or event is InputEventJoypadButton
	for a in ["ui_cancel", "ui_accept", "gg_skip"]:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			get_viewport().set_input_as_handled()
			close()
			return
	if is_key:
		get_viewport().set_input_as_handled()


func _reflow() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var vs := get_viewport().get_visible_rect().size
	var want: Vector2 = _card.card_size
	var s: float = minf(1.0, minf((vs.y - 24.0) / want.y, (vs.x - 24.0) / want.x))
	_card.size = want
	_card.pivot_offset = Vector2.ZERO
	_card.scale = Vector2(s, s)
	_card.position = ((vs - want * s) * 0.5).round()


# ============================================================ the panel

class RefPanel extends Control:

	const CAPS := preload("res://scripts/ui/briefing.gd")
	const CONTENT := preload("res://scripts/ui/briefing_defs.gd")

	const PAD := 34.0
	const W := 960.0
	const COL_GAP := 40.0
	const ROW_GAP := 9.0
	const CAP_H := 30.0
	const CAP_FS := 14
	const ROW_FS := 16

	var card_size := Vector2(W, 480)

	var _key_col := 0.0
	var _panel_sb: StyleBoxFlat


	func build() -> void:
		var widest := 0.0
		for list in [CONTENT.reference_ground(), CONTENT.reference_flight()]:
			var rows: Array = list
			for r in rows:
				var row: Dictionary = r
				var keys: Array = row.get("keys", [])
				widest = maxf(widest, CAPS.Caps.block_width(keys, CAP_FS))
		_key_col = widest

		_panel_sb = StyleBoxFlat.new()
		_panel_sb.bg_color = Color(0.055, 0.06, 0.085, 0.985)
		_panel_sb.set_corner_radius_all(16)
		_panel_sb.border_width_left = 1
		_panel_sb.border_width_right = 1
		_panel_sb.border_width_bottom = 1
		_panel_sb.border_width_top = 5
		_panel_sb.border_color = Color(0.78, 0.80, 0.88)
		_panel_sb.shadow_color = Color(0, 0, 0, 0.55)
		_panel_sb.shadow_size = 18

		card_size = Vector2(W, _walk(false))
		custom_minimum_size = card_size
		size = card_size


	func _draw() -> void:
		draw_style_box(_panel_sb, Rect2(Vector2.ZERO, card_size))
		_walk(true)


	func _col_height(rows: Array, f: Font) -> float:
		var h: float = f.get_ascent(17) + f.get_descent(17) + 12.0
		for r in rows:
			h += CAP_H + ROW_GAP
		return h


	func _walk(do_draw: bool) -> float:
		var f: Font = CAPS.Caps.font()
		var inner := W - PAD * 2.0
		var y := PAD

		if do_draw:
			draw_string(f, Vector2(PAD, y + f.get_ascent(32)), "CONTROLS",
				HORIZONTAL_ALIGNMENT_LEFT, inner, 32, Color(1, 1, 1))
			draw_string(f, Vector2(PAD, y + f.get_ascent(32)),
				"the scheme changes when the ground does",
				HORIZONTAL_ALIGNMENT_RIGHT, inner, 15, Color(0.58, 0.61, 0.69))
		y += f.get_ascent(32) + f.get_descent(32) + 10.0

		if do_draw:
			draw_rect(Rect2(PAD, y, inner, 1.0), Color(1, 1, 1, 0.13), true)
		y += 18.0

		var col_w := (inner - COL_GAP) * 0.5
		var ground: Array = CONTENT.reference_ground()
		var flight: Array = CONTENT.reference_flight()

		var h1 := _column(do_draw, Vector2(PAD, y), col_w, "ON FOOT",
			"the parking lot", ACCENT_GROUND, ground, f)
		var h2 := _column(do_draw, Vector2(PAD + col_w + COL_GAP, y), col_w, "IN THE AIR",
			"the migration", ACCENT_AIR, flight, f)
		y += maxf(h1, h2)

		# The one rule that isn't a keypress.
		y += 18.0
		var note := "The point of the V gets no draft and burns out twice as fast. Hand it off with Q — but only a sober, rested goose can take it."
		var nh: float = f.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, inner - 26.0, 14).y
		var box_h := nh + 22.0
		if do_draw:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(ACCENT_AIR.r, ACCENT_AIR.g, ACCENT_AIR.b, 0.10)
			sb.set_corner_radius_all(9)
			sb.border_width_left = 4
			sb.border_color = ACCENT_AIR
			draw_style_box(sb, Rect2(Vector2(PAD, y), Vector2(inner, box_h)))
			draw_multiline_string(f, Vector2(PAD + 18.0, y + 11.0 + f.get_ascent(14)), note,
				HORIZONTAL_ALIGNMENT_LEFT, inner - 30.0, 14, -1, Color(0.90, 0.92, 0.97))
		y += box_h

		y += 16.0
		if do_draw:
			draw_string(f, Vector2(PAD, y + f.get_ascent(13)),
				"Gamepad:  left stick move  ·  A flap/climb  ·  RB dive/drop  ·  B honk  ·  X eat  ·  Y share / hand off",
				HORIZONTAL_ALIGNMENT_LEFT, inner, 13, Color(0.55, 0.58, 0.66))
			draw_string(f, Vector2(PAD, y + f.get_ascent(13)), "ESC to close",
				HORIZONTAL_ALIGNMENT_RIGHT, inner, 13, Color(0.75, 0.78, 0.85))
		y += f.get_ascent(13) + f.get_descent(13)

		return y + PAD * 0.8


	func _column(do_draw: bool, at: Vector2, col_w: float, title: String, sub: String,
			accent: Color, rows: Array, f: Font) -> float:
		var y := at.y

		if do_draw:
			draw_string(f, Vector2(at.x, y + f.get_ascent(18)), title,
				HORIZONTAL_ALIGNMENT_LEFT, col_w, 18, accent)
			draw_string(f, Vector2(at.x, y + f.get_ascent(18)), sub,
				HORIZONTAL_ALIGNMENT_RIGHT, col_w, 13, Color(0.50, 0.53, 0.61))
		y += f.get_ascent(18) + f.get_descent(18) + 5.0
		if do_draw:
			draw_rect(Rect2(at.x, y, col_w, 2.0), Color(accent.r, accent.g, accent.b, 0.45), true)
		y += 13.0

		var text_x := at.x + _key_col + 18.0
		var text_w := col_w - _key_col - 18.0
		for r in rows:
			var row: Dictionary = r
			var keys: Array = row.get("keys", [])
			var text: String = String(row.get("text", ""))
			if do_draw:
				CAPS.Caps.draw_block(self, Vector2(at.x, y), keys, CAP_FS, CAP_H, accent)
				var base: float = y + (CAP_H + f.get_ascent(ROW_FS) - f.get_descent(ROW_FS)) * 0.5 - 1.0
				draw_multiline_string(f, Vector2(text_x, base), text, HORIZONTAL_ALIGNMENT_LEFT,
					text_w, ROW_FS, -1, Color(0.88, 0.90, 0.95))
			y += CAP_H + ROW_GAP

		return y - at.y
