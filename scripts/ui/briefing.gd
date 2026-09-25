extends CanvasLayer
## THE BRIEFING CARD — the controls onboarding.
##
## The problem this solves: the migration flight has a completely different
## control scheme from the zone and it used to start the instant the zone clock
## hit zero, with the key list printed in 13px in the bottom-left corner of a
## screen you could not pause to read.
##
## The fix is the least fashionable one and the correct one: show the scheme
## once, before the phase starts, on a card the player closes themselves.
##
## Design rules baked into this file, from the research (see ONBOARDING_NOTES):
##   * NEVER GATE THE FUN. Four different inputs dismiss this, one of them is a
##     button you can click with a mouse you didn't have a second ago. A player
##     who doesn't care is back in the game in under two seconds.
##   * SHOW, DON'T LIST. Keys are drawn as key-caps, not typed as "SPACE —
##     flap". A wall of monospace is exactly the thing nobody reads.
##   * ONE HARD MECHANIC GETS A PICTURE. Lead rotation is animated, because no
##     sentence has ever successfully explained why the bird at the point of a
##     V has to be swapped out.
##   * ONCE, EVER. First-run gating persists through Prefs. The recap that
##     replaces it on later legs closes itself on a timer.
##
## INTEGRATOR NOTES:
##   * Add this to Main AFTER the pause menu. Godot delivers _input() in reverse
##     tree order, so the last-added node sees Escape first — that's what stops
##     the pause menu from opening underneath the card.
##   * layer must be above the HUD (2) and the overlays (20/21) but below the
##     pause menu (30). 25 is the number.
##   * This pauses and unpauses the tree itself, and hands the mouse back in
##     whatever mode it found it.

signal dismissed

## Persisted through Prefs. See ONBOARDING_NOTES for the one-line prefs.gd
## change that makes this survive a settings save; the disk fallback below
## means it works even without it.
const PREF_SEEN := &"seen_briefings"
const PREFS_CONFIG_PATH := "user://geeked_geese.cfg"
const PREFS_SECTION := "prefs"

## Every one of these closes the card: Enter, Space, Escape, pad A, pad B and
## pad Start between them, which is what `docs/ONBOARDING_NOTES.md` rule 1
## promises.
##
## This comment used to say "ui_cancel is Escape/pad-B" — true of older engine
## defaults and false in Godot 4.7.1, where `ui_cancel` is Escape alone. So B
## did nothing to a card for as long as anyone can tell, while the rule said it
## closed every one. `gg_honk` is in the list now, which also means the card's
## own button — labelled HONK on the first one — and the honk key agree.
## `tools/inputtest.gd::_gamepad_walk()` closes the flight card with B to hold it.
const DISMISS_ACTIONS := ["ui_accept", "ui_cancel", "gg_skip", "gg_flap", "gg_honk"]

## Long enough that a key already held when the card opens can't eat it, short
## enough that nobody notices.
const INPUT_LOCKOUT := 0.22

var _prefs: Node = null
var _open := false
var _lockout := 0.0
var _auto_left := 0.0
var _auto_total := 0.0
var _restore_mouse: int = Input.MOUSE_MODE_VISIBLE
var _pending_key: StringName = &""

var _backdrop: ColorRect
var _card: Control = null


func _ready() -> void:
	# ALWAYS, not WHEN_PAUSED: this node owns the paused state, so it has to
	# keep running across the moment it flips it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	visible = false
	_prefs = get_node_or_null("/root/Prefs")
	_hydrate_seen()

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.035, 0.88)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	get_viewport().size_changed.connect(_reflow)


# ============================================================ public API

func is_open() -> bool:
	return _open


## Show unconditionally. Nothing is written to Prefs.
func show_now(data: Dictionary) -> void:
	_present(data, &"")


## Show only if this key has never been dismissed before, on any run, ever.
## Returns true if the card is now up (so the caller knows whether to await).
##
##   if brief.show_once(&"flight_first_run", Defs.flight_first_run()):
##       await brief.dismissed
func show_once(key: StringName, data: Dictionary) -> bool:
	if _open:
		return false
	if has_seen(key):
		return false
	var gated: bool = bool(data.get("respects_show_hints", false))
	if gated and _prefs != null and not bool(_prefs.get_pref(&"show_hints", true)):
		# Player turned hints off in Settings. Believe them.
		_mark_seen(key)
		return false
	_present(data, key)
	return true


func has_seen(key: StringName) -> bool:
	return _seen_list().has(String(key))


## Dev / "replay the intro" hook. Pass a key to forget just that one.
func reset_seen(key: StringName = &"") -> void:
	if key == &"":
		_write_seen([])
		return
	var arr: Array = _seen_list()
	arr.erase(String(key))
	_write_seen(arr)


## Close it from code (e.g. the phase got cancelled out from under us).
func force_close() -> void:
	if _open:
		_dismiss()


# ============================================================ presentation

func _present(data: Dictionary, key: StringName) -> void:
	if _open:
		return
	_pending_key = key
	_clear_card()
	_build_card(data)
	_open = true
	visible = true
	_lockout = INPUT_LOCKOUT
	_auto_total = float(data.get("auto_dismiss", 0.0))
	_auto_left = _auto_total
	_restore_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _build_card(data: Dictionary) -> void:
	_card = CardPanel.new()
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_card.setup(data)
	add_child(_card)

	# The dismiss button. It is a real Button because a card that can only be
	# closed with a key is a trap for someone who just picked up a mouse.
	var btn := Button.new()
	btn.text = String(data.get("button", "GOT IT"))
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", _card.btn_fs)
	var accent: Color = _card.accent
	_style_button(btn, accent)
	btn.pressed.connect(func():
		if _lockout <= 0.0:
			_dismiss())
	_card.add_child(btn)
	btn.position = _card.button_rect.position
	btn.size = _card.button_rect.size

	_reflow()


func _reflow() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var vs := get_viewport().get_visible_rect().size
	var want: Vector2 = _card.card_size
	# Safety net for tiny viewports: shrink rather than run off the screen.
	var s: float = minf(1.0, minf((vs.y - 24.0) / want.y, (vs.x - 24.0) / want.x))
	_card.size = want
	_card.pivot_offset = Vector2.ZERO
	_card.scale = Vector2(s, s)
	_card.position = ((vs - want * s) * 0.5).round()


func _clear_card() -> void:
	if _card and is_instance_valid(_card):
		_card.queue_free()
	_card = null


func _style_button(btn: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		var lift := 0.0
		if state == "hover":
			lift = 0.10
		elif state == "pressed":
			lift = -0.06
		sb.bg_color = Color(0.15, 0.16, 0.21, 0.96).lightened(maxf(lift, 0.0))
		sb.set_corner_radius_all(9)
		sb.border_width_left = 4
		sb.border_color = accent
		sb.set_content_margin_all(8)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))


# ============================================================ loop + input

func _process(delta: float) -> void:
	if not _open:
		return
	# Re-assert every frame. If anything else in the project unpauses while a
	# briefing is up, the phase behind the card starts ticking unwatched.
	if not get_tree().paused:
		get_tree().paused = true

	# Wall-clock, not scaled — substances can leave time_scale anywhere.
	var real := delta / maxf(Engine.time_scale, 0.05)

	if _lockout > 0.0:
		_lockout = maxf(0.0, _lockout - real)

	if _auto_total > 0.0:
		_auto_left = maxf(0.0, _auto_left - real)
		if _card and is_instance_valid(_card):
			_card.set_auto(_auto_left, _auto_total)
		if _auto_left <= 0.0:
			_dismiss()


func _input(event: InputEvent) -> void:
	if not _open:
		return

	var is_key := event is InputEventKey or event is InputEventJoypadButton

	if _lockout > 0.0:
		# Swallow keys only. Mouse events must reach the button, and marking a
		# mouse click handled here would make the button unclickable.
		if is_key:
			get_viewport().set_input_as_handled()
		return

	for a in DISMISS_ACTIONS:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			get_viewport().set_input_as_handled()
			_dismiss()
			return

	# Nothing else gets through to the paused phase, and critically the pause
	# menu never opens behind the card.
	if is_key:
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _pending_key != &"":
		_mark_seen(_pending_key)
		_pending_key = &""
	_clear_card()
	get_tree().paused = false
	Input.mouse_mode = _restore_mouse
	dismissed.emit()


# ============================================================ persistence

## Prefs.load_prefs() only restores keys present in Prefs.DEFAULTS, and
## save_prefs() writes only what's in its dictionary — so a key it doesn't know
## about round-trips to disk once and is then dropped by the next settings
## save. Reading the config directly on boot and pushing the value back into
## Prefs fixes that without touching prefs.gd.
func _hydrate_seen() -> void:
	if _prefs == null:
		return
	var v = _prefs.get_pref(PREF_SEEN, null)
	if v is Array:
		return
	_prefs.set_pref(PREF_SEEN, _disk_seen())


func _disk_seen() -> Array:
	var cf := ConfigFile.new()
	if cf.load(PREFS_CONFIG_PATH) != OK:
		return []
	var v = cf.get_value(PREFS_SECTION, String(PREF_SEEN), [])
	if v is Array:
		return v
	return []


func _seen_list() -> Array:
	if _prefs == null:
		return _disk_seen()
	var v = _prefs.get_pref(PREF_SEEN, null)
	if v is Array:
		return v
	return _disk_seen()


func _write_seen(arr: Array) -> void:
	if _prefs != null:
		_prefs.set_pref(PREF_SEEN, arr)
		return
	var cf := ConfigFile.new()
	cf.load(PREFS_CONFIG_PATH)
	cf.set_value(PREFS_SECTION, String(PREF_SEEN), arr)
	cf.save(PREFS_CONFIG_PATH)


func _mark_seen(key: StringName) -> void:
	var arr: Array = _seen_list().duplicate()
	var s := String(key)
	if not arr.has(s):
		arr.append(s)
	_write_seen(arr)


# ============================================================ key-cap drawing
#
# Shared with control_card.gd. Static only — nothing here touches the tree.

class Caps extends RefCounted:

	const MIN_W := 34.0
	const PAD_X := 11.0
	const GAP := 6.0

	static func font() -> Font:
		return ThemeDB.fallback_font

	static func cap_width(label: String, fs: int) -> float:
		var f := font()
		var tw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		return maxf(MIN_W, tw + PAD_X * 2.0)

	## Total width of a whole row of caps, e.g. W A S D.
	static func block_width(keys: Array, fs: int) -> float:
		var w := 0.0
		for i in keys.size():
			var label: String = String(keys[i])
			w += cap_width(label, fs)
			if i < keys.size() - 1:
				w += GAP
		return w

	static func _cap_box(accent: Color, hot: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.17, 0.22).lerp(accent.darkened(0.45), 0.35 + 0.5 * hot)
		sb.set_corner_radius_all(6)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		# Fat bottom border: that's the whole trick that makes a rectangle read
		# as a physical key rather than a text box.
		sb.border_width_bottom = 3
		sb.border_color = Color(0.62, 0.65, 0.74).lerp(accent, 0.35 + 0.55 * hot)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(0, 1)
		return sb

	static func draw_cap(ci: CanvasItem, pos: Vector2, label: String, fs: int, h: float,
			accent: Color, hot: float = 0.0) -> float:
		var f := font()
		var w := cap_width(label, fs)
		ci.draw_style_box(_cap_box(accent, hot), Rect2(pos, Vector2(w, h)))
		# Baseline centred on the cap, minus one pixel for the fat bottom edge.
		var base: float = pos.y + (h + f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - 1.0
		var col := Color(0.93, 0.95, 1.0).lerp(Color.WHITE, hot)
		ci.draw_string(f, Vector2(pos.x, base), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
		return w

	static func draw_block(ci: CanvasItem, pos: Vector2, keys: Array, fs: int, h: float,
			accent: Color, hot: float = 0.0) -> float:
		var x := pos.x
		for k in keys:
			var label: String = String(k)
			x += draw_cap(ci, Vector2(x, pos.y), label, fs, h, accent, hot) + GAP
		return x - pos.x - GAP


# ============================================================ the card itself

class CardPanel extends Control:

	var data: Dictionary = {}
	var accent := Color(0.99, 0.78, 0.28)
	var compact := false

	var card_size := Vector2(840, 400)
	var button_rect := Rect2()
	var btn_fs := 17

	var _auto_left := 0.0
	var _auto_total := 0.0

	# Geometry, resolved in setup() from `compact`.
	var _pad := 32.0
	var _w := 840.0
	var _title_fs := 34
	var _sub_fs := 15
	var _flav_fs := 17
	var _row_fs := 17
	var _cap_fs := 15
	var _cap_h := 32.0
	var _lab_fs := 12
	var _call_fs := 15
	var _pad_fs := 13
	var _row_gap := 10.0
	var _gutter := 20.0

	var _key_col := 0.0      ## width reserved for the key-cap column
	var _text_w := 0.0       ## wrap width for row descriptions
	var _side_diagram := false
	var _diag_w := 320.0
	var _diag_h := 150.0
	var _diag_pos := Vector2.ZERO
	var _diagram: Control = null
	var _panel_sb: StyleBoxFlat


	func setup(d: Dictionary) -> void:
		data = d
		accent = d.get("accent", Color(0.99, 0.78, 0.28))
		compact = bool(d.get("compact", false))

		if compact:
			_pad = 24.0
			_w = 540.0
			_title_fs = 26
			_sub_fs = 13
			_flav_fs = 14
			_row_fs = 15
			_cap_fs = 13
			_cap_h = 27.0
			_lab_fs = 11
			_call_fs = 13
			_pad_fs = 12
			_row_gap = 8.0
			btn_fs = 15

		var diagram: String = String(d.get("diagram", ""))
		_side_diagram = diagram != "" and not compact
		if diagram == "dose_arc":
			_diag_w = 330.0
			_diag_h = 104.0
		else:
			_diag_w = 344.0
			_diag_h = 162.0

		# A card with a diagram needs a second column; one without would just be
		# a lot of empty carpet on the right.
		if not compact:
			_w = 872.0 if _side_diagram else 700.0

		# Key column is as wide as the widest cap block, so every description
		# in the card starts on the same x. Ragged columns read as noise.
		var rows: Array = d.get("rows", [])
		var widest := 0.0
		for r in rows:
			var row: Dictionary = r
			var keys: Array = row.get("keys", [])
			widest = maxf(widest, Briefing_Caps.block_width(keys, _cap_fs))
		_key_col = widest

		var inner := _w - _pad * 2.0
		var rows_w: float = inner - (_diag_w + 26.0) if _side_diagram else inner
		_text_w = maxf(120.0, rows_w - _key_col - _gutter)

		_panel_sb = StyleBoxFlat.new()
		_panel_sb.bg_color = Color(0.055, 0.06, 0.085, 0.985)
		_panel_sb.set_corner_radius_all(16)
		_panel_sb.border_width_left = 1
		_panel_sb.border_width_right = 1
		_panel_sb.border_width_bottom = 1
		_panel_sb.border_width_top = 5
		_panel_sb.border_color = accent
		_panel_sb.shadow_color = Color(0, 0, 0, 0.55)
		_panel_sb.shadow_size = 18

		var h := _walk(false)
		card_size = Vector2(_w, h)
		custom_minimum_size = card_size
		size = card_size

		if diagram != "":
			if diagram == "v_formation":
				_diagram = VDiagram.new()
			else:
				_diagram = DoseDiagram.new()
			_diagram.accent = accent
			_diagram.size = Vector2(_diag_w, _diag_h)
			_diagram.position = _diag_pos
			_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_diagram.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_diagram)


	func set_auto(left: float, total: float) -> void:
		_auto_left = left
		_auto_total = total
		queue_redraw()


	func _draw() -> void:
		draw_style_box(_panel_sb, Rect2(Vector2.ZERO, card_size))
		_walk(true)


	## Single source of truth for layout. Called once with do_draw=false to
	## measure and once per frame with true to paint — so the two can never
	## disagree about where anything is.
	func _walk(do_draw: bool) -> float:
		var f := Briefing_Caps.font()
		var inner := _w - _pad * 2.0
		var x := _pad
		var y := _pad

		# ---- title
		var title: String = String(data.get("title", ""))
		if title != "":
			if do_draw:
				draw_string(f, Vector2(x, y + f.get_ascent(_title_fs)), title,
					HORIZONTAL_ALIGNMENT_LEFT, inner, _title_fs, Color(1, 1, 1))
			y += f.get_ascent(_title_fs) + f.get_descent(_title_fs) + 2.0

		# ---- subtitle
		var sub: String = String(data.get("subtitle", ""))
		if sub != "":
			if do_draw:
				draw_string(f, Vector2(x, y + f.get_ascent(_sub_fs)), sub,
					HORIZONTAL_ALIGNMENT_LEFT, inner, _sub_fs, accent.lerp(Color.WHITE, 0.25))
			y += f.get_ascent(_sub_fs) + f.get_descent(_sub_fs) + 4.0

		# ---- flavour
		var flav: String = String(data.get("flavour", ""))
		if flav != "":
			y += 4.0
			var fh: float = f.get_multiline_string_size(flav, HORIZONTAL_ALIGNMENT_LEFT, inner, _flav_fs).y
			if do_draw:
				draw_multiline_string(f, Vector2(x, y + f.get_ascent(_flav_fs)), flav,
					HORIZONTAL_ALIGNMENT_LEFT, inner, _flav_fs, -1, Color(0.70, 0.73, 0.80))
			y += fh

		# ---- rule
		y += 14.0
		if do_draw:
			draw_rect(Rect2(x, y, inner, 1.0), Color(1, 1, 1, 0.13), true)
		y += 15.0

		# ---- rows (+ side diagram sharing the band)
		var band_top := y
		var rows: Array = data.get("rows", [])
		for r in rows:
			var row: Dictionary = r
			var keys: Array = row.get("keys", [])
			var text: String = String(row.get("text", ""))
			if do_draw:
				Briefing_Caps.draw_block(self, Vector2(x, y), keys, _cap_fs, _cap_h, accent)
			var tw: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				_text_w, _row_fs).y
			var tx := x + _key_col + _gutter
			if do_draw:
				var base: float = y + (_cap_h + f.get_ascent(_row_fs) - f.get_descent(_row_fs)) * 0.5 - 1.0
				draw_multiline_string(f, Vector2(tx, base), text, HORIZONTAL_ALIGNMENT_LEFT,
					_text_w, _row_fs, -1, Color(0.88, 0.90, 0.95))
			y += maxf(_cap_h, tw) + _row_gap
		if not rows.is_empty():
			y -= _row_gap

		if _side_diagram:
			# Centred in the rows band rather than top-aligned: a short diagram
			# hanging off the top of a tall key list reads as a mistake.
			var band_h: float = maxf(y - band_top, _diag_h)
			_diag_pos = Vector2(_w - _pad - _diag_w, band_top + (band_h - _diag_h) * 0.5)
			y = band_top + band_h
		elif String(data.get("diagram", "")) != "":
			y += 14.0
			_diag_pos = Vector2(x + (inner - _diag_w) * 0.5, y)
			y += _diag_h

		# ---- callout
		var callout: Dictionary = data.get("callout", {})
		if not callout.is_empty():
			y += 16.0
			var label: String = String(callout.get("label", ""))
			var text: String = String(callout.get("text", ""))
			var box_pad := 13.0
			var text_w := inner - box_pad * 2.0 - 6.0
			var lh: float = f.get_ascent(_lab_fs) + f.get_descent(_lab_fs)
			var th: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				text_w, _call_fs).y
			var box_h := box_pad * 2.0 + lh + 4.0 + th
			if do_draw:
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
				sb.set_corner_radius_all(9)
				sb.border_width_left = 4
				sb.border_color = accent
				draw_style_box(sb, Rect2(Vector2(x, y), Vector2(inner, box_h)))
				var tx := x + box_pad + 6.0
				draw_string(f, Vector2(tx, y + box_pad + f.get_ascent(_lab_fs)), label,
					HORIZONTAL_ALIGNMENT_LEFT, text_w, _lab_fs, accent)
				draw_multiline_string(f, Vector2(tx, y + box_pad + lh + 4.0 + f.get_ascent(_call_fs)),
					text, HORIZONTAL_ALIGNMENT_LEFT, text_w, _call_fs, -1, Color(0.92, 0.94, 0.98))
			y += box_h

		# ---- gamepad line
		var pad_line: String = String(data.get("gamepad", ""))
		if pad_line != "":
			y += 12.0
			if do_draw:
				draw_string(f, Vector2(x, y + Briefing_Caps.font().get_ascent(_pad_fs)), pad_line,
					HORIZONTAL_ALIGNMENT_LEFT, inner, _pad_fs, Color(0.55, 0.58, 0.66))
			y += f.get_ascent(_pad_fs) + f.get_descent(_pad_fs)

		# ---- button band
		y += 18.0
		var btn_h := 42.0 if not compact else 36.0
		var btn_label: String = String(data.get("button", "GOT IT"))
		var btn_w: float = maxf(140.0, f.get_string_size(btn_label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			btn_fs).x + 56.0)
		button_rect = Rect2(Vector2(_w - _pad - btn_w, y), Vector2(btn_w, btn_h))

		if do_draw:
			# The escape hatch, spelled out. Nobody is ever trapped here.
			var hint := "ENTER  ·  SPACE  ·  ESC"
			var hb: float = y + (btn_h + f.get_ascent(_pad_fs) - f.get_descent(_pad_fs)) * 0.5
			draw_string(f, Vector2(x, hb), hint, HORIZONTAL_ALIGNMENT_LEFT, inner, _pad_fs,
				Color(0.50, 0.53, 0.61))
			if _auto_total > 0.0:
				var frac: float = clampf(_auto_left / _auto_total, 0.0, 1.0)
				var bar_y := y + btn_h + 9.0
				draw_rect(Rect2(x, bar_y, inner, 2.0), Color(1, 1, 1, 0.08), true)
				draw_rect(Rect2(x, bar_y, inner * frac, 2.0), accent, true)

		y += btn_h
		if _auto_total > 0.0:
			y += 11.0

		return y + _pad * 0.8


# ============================================================ diagrams
#
# There is no video here and no room for one. These are schematics drawn with
# _draw(), which is the only honest way to animate a rule.

class VDiagram extends Control:
	## THE LEAD ROTATION LOOP.
	##
	## Six geese in a V, seen from above, flying up the screen. The goose at the
	## point has a stamina bar that visibly empties while everyone behind it
	## fills. A [Q] cap flares, the point peels out to the left and drops into
	## the near-left slot, and the goose that was there slides up to take the
	## point. Then it starts burning instead. Loops forever.
	##
	## Everything is a pure function of the loop phase, so it never drifts and
	## never needs resetting.

	var accent := Color(0.55, 0.78, 0.98)

	const T_HOLD := 3.4
	const T_CUE := 0.7
	const T_SWAP := 1.25
	const T_SETTLE := 1.35
	const PERIOD := T_HOLD + T_CUE + T_SWAP + T_SETTLE

	const LEAD_COL := Color(1.0, 0.72, 0.24)
	const DRAFT_COL := Color(0.80, 0.85, 0.95)
	## Bird glyph scale. At 1.0 the geese render as specks and the whole thing
	## reads as a dotted line rather than a formation — the first render proved
	## it. This is the single most important number in the diagram.
	const GOOSE := 1.5

	var _t := 0.0

	func _process(delta: float) -> void:
		_t = fmod(_t + delta / maxf(Engine.time_scale, 0.05), PERIOD)
		queue_redraw()

	## Slot 0 is the point. Odd slots left, even slots right — same rule the
	## flight itself uses, so the picture matches the thing.
	func _slot(i: int) -> Vector2:
		var cx := size.x * 0.5
		var top := 27.0
		if i == 0:
			return Vector2(cx, top)
		var rank: int = (i + 1) / 2
		var side := -1.0 if i % 2 == 1 else 1.0
		var sx: float = minf(48.0, (size.x * 0.5 - 22.0) / 3.0)
		return Vector2(cx + side * float(rank) * sx, top + float(rank) * 30.0)

	static func _bez(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
		var iu := 1.0 - u
		return a * (iu * iu) + c * (2.0 * iu * u) + b * (u * u)

	static func _ease(u: float) -> float:
		return u * u * (3.0 - 2.0 * u)

	## Where the two swapping birds are at time t. Everyone else is parked.
	func _pos_a(t: float) -> Vector2:
		var p0 := _slot(0)
		var p1 := _slot(1)
		if t < T_HOLD + T_CUE:
			return p0
		if t < T_HOLD + T_CUE + T_SWAP:
			var u := _ease((t - T_HOLD - T_CUE) / T_SWAP)
			# Peels forward and out to the left before dropping back in — the
			# shape of the move is the explanation.
			return _bez(p0, p0 + Vector2(-64.0, -22.0), p1, u)
		return p1

	func _pos_b(t: float) -> Vector2:
		var p0 := _slot(0)
		var p1 := _slot(1)
		if t < T_HOLD + T_CUE:
			return p1
		if t < T_HOLD + T_CUE + T_SWAP:
			var u := _ease((t - T_HOLD - T_CUE) / T_SWAP)
			return _bez(p1, (p0 + p1) * 0.5 + Vector2(16.0, 8.0), p0, u)
		return p0

	func _lead_mix(t: float) -> float:
		# 0 = A still holds the point, 1 = B has it.
		var s := T_HOLD + T_CUE
		if t < s + T_SWAP * 0.4:
			return 0.0
		if t > s + T_SWAP * 0.75:
			return 1.0
		return _ease((t - s - T_SWAP * 0.4) / (T_SWAP * 0.35))

	func _draw() -> void:
		var t := _t
		var f := Briefing_Caps.font()

		var pa := _pos_a(t)
		var pb := _pos_b(t)
		var mix := _lead_mix(t)

		# Where every bird is right now, by slot index.
		var pts: Array[Vector2] = []
		for i in 6:
			pts.append(_slot(i))
		pts[0] = pb
		pts[1] = pa

		# --- draft chain. Drawn on the STATIC slot geometry, not on the birds:
		# the corridor of air belongs to the formation, not to whoever happens
		# to be sitting in it this second.
		var chain := [[0, 1], [0, 2], [1, 3], [2, 4], [3, 5]]
		for link in chain:
			var pair: Array = link
			var ai: int = pair[0]
			var bi: int = pair[1]
			_dashed(_slot(ai), _slot(bi), Color(0.62, 0.86, 1.0, 0.46), t)

		# --- the route the point is about to take, ghosted in as soon as the
		# cue fires. Without it a still frame of the swap looks like a bug.
		if t >= T_HOLD:
			var fade := 1.0
			var done := T_HOLD + T_CUE + T_SWAP
			if t > done:
				fade = 1.0 - clampf((t - done) / (T_SETTLE * 0.6), 0.0, 1.0)
			var p0 := _slot(0)
			var p1 := _slot(1)
			var ctrl := p0 + Vector2(-64.0, -22.0)
			var prev := p0
			for k in range(1, 15):
				var u := float(k) / 14.0
				var q := _bez(p0, ctrl, p1, u)
				if k % 2 == 0:
					draw_line(prev, q, Color(1.0, 0.78, 0.36, 0.55 * fade), 1.8)
				prev = q

		# --- the geese. Index 0 is bird B (starts in the near-left slot),
		# index 1 is bird A (starts at the point); 2..5 never move.
		for i in 6:
			var p: Vector2 = pts[i]
			var is_lead := false
			var burn := 0.0
			var stam := 0.86
			if i == 0 or i == 1:
				# The two that swap carry the story, so they get real numbers.
				var a_is_lead := 1.0 - mix
				if i == 1:
					# This is bird A (the outgoing lead) once the swap resolves.
					stam = _stam_a(t)
					burn = a_is_lead
					is_lead = a_is_lead > 0.5
				else:
					stam = _stam_b(t)
					burn = mix
					is_lead = mix > 0.5
			var col: Color = DRAFT_COL.lerp(LEAD_COL, burn if (i == 0 or i == 1) else 0.0)
			var ang := 0.0
			if i == 0:
				ang = _heading(pb, t, true)
			elif i == 1:
				ang = _heading(pa, t, false)
			_goose(p, ang, col, is_lead)
			_stam_bar(p + Vector2(-10.0, 15.0), stam, burn)

		# --- the [Q] cap, dim until it matters
		var hot := 0.0
		if t >= T_HOLD and t < T_HOLD + T_CUE + T_SWAP * 0.6:
			hot = 0.55 + 0.45 * sin(t * 16.0)
		Briefing_Caps.draw_cap(self, Vector2(0, 2), "Q", 13, 24.0, accent, hot)
		# The label is always there, just dim — a lone key-cap floating in the
		# corner with no caption reads as a stray element until it fires.
		draw_string(f, Vector2(38, 19), "hand off", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(1, 1, 1, 0.26 + 0.62 * hot))

		draw_string(f, Vector2(0, size.y - 2), "the point burns  ·  the draft pays",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(0.60, 0.63, 0.72))

	func _stam_a(t: float) -> float:
		var s := T_HOLD + T_CUE + T_SWAP
		if t < s:
			return lerpf(0.90, 0.20, clampf(t / s, 0.0, 1.0))
		return lerpf(0.20, 0.40, clampf((t - s) / T_SETTLE, 0.0, 1.0))

	func _stam_b(t: float) -> float:
		var s := T_HOLD + T_CUE + T_SWAP
		if t < s:
			return lerpf(0.80, 0.97, clampf(t / s, 0.0, 1.0))
		return lerpf(0.97, 0.80, clampf((t - s) / T_SETTLE, 0.0, 1.0))

	## Face along the direction of travel. Sampled rather than solved — a bird
	## that keeps pointing north while sliding sideways looks broken.
	##
	## Clamped hard: the first render had the peeling goose rotated ninety
	## degrees mid-arc, which read as a dead bird falling rather than a bird
	## banking out of the point. Geese bank, they don't pirouette.
	func _heading(p: Vector2, t: float, is_b: bool) -> float:
		var t2: float = minf(t + 0.06, PERIOD)
		var q: Vector2 = _pos_b(t2) if is_b else _pos_a(t2)
		var d := q - p
		if d.length() < 0.6:
			return 0.0
		return clampf(atan2(d.x, -d.y), -0.62, 0.62)

	func _goose(p: Vector2, ang: float, col: Color, is_lead: bool) -> void:
		var base := PackedVector2Array([
			Vector2(0, -10), Vector2(2.8, -3.0), Vector2(11, 5.5), Vector2(3.4, 2.6),
			Vector2(0, 8), Vector2(-3.4, 2.6), Vector2(-11, 5.5), Vector2(-2.8, -3.0),
		])
		var pts := PackedVector2Array()
		var c := cos(ang)
		var s := sin(ang)
		for v in base:
			var vx: float = v.x * GOOSE
			var vy: float = v.y * GOOSE
			pts.append(Vector2(vx * c - vy * s, vx * s + vy * c) + p)
		if is_lead:
			# A soft halo so the point is unmistakable at a glance.
			draw_circle(p, 20.0, Color(col.r, col.g, col.b, 0.16))
		draw_colored_polygon(pts, col)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(0.04, 0.05, 0.08, 0.85), 1.5)

	func _stam_bar(p: Vector2, v: float, burn: float) -> void:
		var w := 20.0
		draw_rect(Rect2(p.x - 0.5, p.y - 0.5, w + 1.0, 4.0), Color(0, 0, 0, 0.7), true)
		var col := Color(0.40, 0.85, 0.52).lerp(Color(0.96, 0.42, 0.26), burn)
		if v < 0.35:
			col = Color(0.96, 0.35, 0.28)
		draw_rect(Rect2(p.x, p.y, w * clampf(v, 0.0, 1.0), 3.0), col, true)

	## Airflow, drawn as dashes that crawl backwards down the chain.
	func _dashed(a: Vector2, b: Vector2, col: Color, t: float) -> void:
		var d := b - a
		var len := d.length()
		if len < 4.0:
			return
		var dir := d / len
		var step := 7.0
		var off := fmod(t * 26.0, step)
		var x := off
		while x < len - 14.0:
			var p0 := a + dir * (x + 12.0)
			var p1 := a + dir * minf(x + 15.5, len - 12.0)
			if p1.distance_to(p0) > 0.5:
				draw_line(p0, p1, col, 1.6)
			x += step


class DoseDiagram extends Control:
	## A miniature of the HUD's own sweet-spot arc, with the needle sweeping.
	## Teaching with the exact widget the player is about to look at beats
	## teaching with a diagram of it.

	var accent := Color(0.55, 0.92, 0.55)
	var _t := 0.0

	const SWEET_MIN := 0.46
	const SWEET_MAX := 0.72

	func _process(delta: float) -> void:
		_t = fmod(_t + delta / maxf(Engine.time_scale, 0.05), 3.2)
		queue_redraw()

	func _draw() -> void:
		var f := Briefing_Caps.font()
		var c := Vector2(size.x * 0.5, size.y - 24.0)
		var r := minf(56.0, size.x * 0.28)
		var a0 := PI
		var a1 := TAU

		draw_arc(c, r, a0, a1, 48, Color(0, 0, 0, 0.6), 13.0)
		draw_arc(c, r, lerpf(a0, a1, SWEET_MIN), lerpf(a0, a1, SWEET_MAX), 24,
			Color(0.35, 0.92, 0.48, 0.9), 13.0)
		draw_arc(c, r, lerpf(a0, a1, SWEET_MAX), a1, 20, Color(0.92, 0.30, 0.26, 0.6), 13.0)

		# Charge sweeps up, holds a beat in the green, then commits.
		var u: float = clampf(_t / 2.0, 0.0, 1.0)
		var charge: float = lerpf(0.0, 0.60, u) if _t < 2.0 else 0.60
		var flash: float = 0.0
		if _t > 2.0 and _t < 2.55:
			flash = 1.0 - (_t - 2.0) / 0.55
		if _t > 2.55:
			charge = 0.0
		var ang := lerpf(a0, a1, clampf(charge, 0.0, 1.0))
		if charge > 0.001:
			var v := Vector2(cos(ang), sin(ang))
			draw_line(c + v * (r - 11.0), c + v * (r + 7.0), Color.WHITE, 3.0)

		var msg := "HOLD  E" if _t < 2.0 else "RELEASE"
		var col := Color(0.92, 0.94, 1.0)
		if flash > 0.0:
			col = Color(0.45, 1.0, 0.55)
			msg = "SWEET SPOT"
		draw_string(f, Vector2(0, size.y - 3.0), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, col)
		# Labels flank the ends of the arc they describe. Floating them at the
		# top of the box (round one) made them read as a separate caption.
		draw_string(f, Vector2(0, c.y + 4.0), "nothing", HORIZONTAL_ALIGNMENT_RIGHT,
			c.x - r - 10.0, 11, Color(0.55, 0.58, 0.66))
		draw_string(f, Vector2(c.x + r + 10.0, c.y + 4.0), "overdose", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, Color(0.86, 0.42, 0.36))


## Inner classes can't see each other by bare name from a nested scope, so the
## cap renderer gets one alias that everything below uses.
const Briefing_Caps := Caps
