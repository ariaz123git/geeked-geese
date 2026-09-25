extends CanvasLayer
## Mission HUD. Replaces scripts/ui/objectives.gd.
##
## ── THE PROBLEM THIS SOLVES ──────────────────────────────────────────────
## The player is a goose travelling at speed with a camera that detaches, lags,
## tilts and occasionally turns the world purple. They are NOT looking at the
## top-left corner. Anything the objective list needs to communicate has to
## survive being seen in peripheral vision, at an angle, through a shader.
##
## ── WHAT PERIPHERAL VISION IS ACTUALLY GOOD AT ───────────────────────────
## Research on HUDs read off-fovea is consistent about three things:
##   1. The periphery detects MOTION and LUMINANCE CONTRAST well, and reads
##      small text and fine hue differences badly.
##   2. CROWDING is the dominant failure mode — adjacent clutter destroys
##      legibility far more than small size does.
##   3. Big, stark elements with strong brightness separation from the scene
##      behind them survive; subtle ones vanish.
##
## Applied here, concretely:
##   • Every row carries its own dark backing plate and every glyph is drawn as
##     a SHAPE, not a font character. Shapes read at the edge of vision; 14px
##     Unicode checkboxes do not (and can't tofu out on a missing glyph).
##   • Progress is a BAR as well as a number. Bar length is a size cue, which
##     the periphery gets for free; "6/8" requires foveating.
##   • State is never encoded by hue alone — a finished row changes glyph
##     (outline square to filled square with a tick), fills its bar, dims, and
##     gains a strikethrough. Four redundant channels, because peripheral
##     colour discrimination is the first thing to go.
##   • Change is announced with MOTION: bars slide, completed rows punch and
##     then physically collapse out of the list.
##   • Crowding is managed by keeping the list short and by removing completed
##     rows entirely after their moment. The panel gets SMALLER as you succeed,
##     which is the opposite of what a checklist does to you.
##
## ── PRIMARY vs BONUS ─────────────────────────────────────────────────────
## Required work is big, bright, and wears a gold accent stripe. Optional work
## is two-thirds the size, half the brightness, no stripe, and prefixed with a
## small plus. That size difference is doing design work, not decoration:
## optional content only stops feeling mandatory if it visibly reads as
## secondary at a glance.
##
## ── HIDDEN OBJECTIVES ────────────────────────────────────────────────────
## Never listed, never hinted, never counted — until the first one fires. Then
## a banner takes the lower third of the screen for two seconds and a discovery
## counter appears in the header. Showing "0 of 10 secrets" up front would tell
## the player they are already failing at something they cannot see, which is
## precisely the anxiety this system exists to avoid.

const KIND_PRIMARY := 0
const KIND_BONUS := 1
const KIND_HIDDEN := 2

enum Mode { FULL, COMPACT, OFF }

const PANEL_W := 420.0
const ROW_H_PRIMARY := 34.0
const ROW_H_BONUS := 26.0
const IDLE_FADE_AFTER := 10.0   ## seconds of no progress before the panel dims
const SETTLE_TIME := 2.2        ## how long a completed row lingers before it goes

## Bonus objectives are shown two at a time and REPLENISH as you clear them,
## rather than all being listed up front.
##
## This is the single most important number on the panel. Leg 4 has four
## bonuses; listing all of them next to five primaries produced a nine-row wall
## that read as homework — the exact failure the research on open-world
## checklists describes, reproduced faithfully on the first render test.
##
## Showing a rolling two means the player never sees the full set, so there is
## no set to feel behind on, and clearing one is rewarded with a new one
## appearing rather than with a shorter to-do list. Optional content should
## feel like a supply, not a backlog.
const MAX_BONUS_ROWS := 2

const C_GOLD := Color(0.99, 0.80, 0.30)
const C_PRIMARY := Color(0.97, 0.98, 1.00)
const C_BONUS := Color(0.74, 0.79, 0.88)
const C_HIDDEN := Color(1.00, 0.62, 0.86)
const C_DONE := Color(0.55, 0.60, 0.68)
const C_PLATE := Color(0.03, 0.035, 0.06, 0.55)

var mode: int = Mode.FULL

var _mission: Node = null
var _prefs: Node = null
var _sfx: Node = null

var _root: Control
var _panel: PanelContainer
var _col: VBoxContainer
var _header: Control
var _banner: Control
var _rows: Dictionary = {}        ## StringName -> ObjRow
var _idle := 0.0
var _hidden_seen := 0
var _hidden_total := 0
var _bonus_queue: Array = []   ## bonus rows waiting for a free slot
var _host_visible := true      ## see set_host_visible()


func _ready() -> void:
	layer = 3
	_mission = get_node_or_null("/root/Mission")
	_prefs = get_node_or_null("/root/Prefs")
	_sfx = get_node_or_null("/root/Sfx")
	_ensure_action()
	_build()
	_wire()
	_refresh_visibility()
	if _mission != null and _mission.has_method("visible_objectives"):
		var list: Array = _mission.visible_objectives()
		if not list.is_empty():
			setup(list)


## The toggle is registered here rather than in project.godot for the same
## reason Game registers its own actions: version-proof, and visible in a diff.
func _ensure_action() -> void:
	if InputMap.has_action("gg_objectives"):
		return
	InputMap.add_action("gg_objectives")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	InputMap.action_add_event("gg_objectives", ev)


func _wire() -> void:
	if _prefs != null and _prefs.has_signal("pref_changed"):
		_prefs.pref_changed.connect(_on_pref_changed)
	if _mission == null:
		return
	if _mission.has_signal("objectives_ready"):
		_mission.objectives_ready.connect(setup)
	if _mission.has_signal("objective_progressed"):
		_mission.objective_progressed.connect(_on_progressed)
	if _mission.has_signal("objective_completed"):
		_mission.objective_completed.connect(_on_completed)
	if _mission.has_signal("hidden_revealed"):
		_mission.hidden_revealed.connect(_on_hidden)


# ══════════════════════════════════════════════════════════════════ BUILD

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = Vector2(18, 76)
	holder.custom_minimum_size = Vector2(PANEL_W, 0)
	_root.add_child(holder)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	# Darker and more opaque than the old list. The zone is overcast grey and
	# the trip shader washes the whole frame — a 32%-alpha plate disappears
	# into both. Contrast is the entire job here.
	sb.bg_color = Color(0.02, 0.025, 0.045, 0.62)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 9.0
	sb.border_width_left = 3
	sb.border_color = C_GOLD * Color(1, 1, 1, 0.55)
	_panel.add_theme_stylebox_override("panel", sb)
	holder.add_child(_panel)

	_col = VBoxContainer.new()
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_theme_constant_override("separation", 5)
	_panel.add_child(_col)

	_header = HeaderRow.new()
	_header.custom_minimum_size = Vector2(PANEL_W - 20.0, 18.0)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_header)

	_banner = Banner.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)


## list: Array of row Dictionaries from Mission.visible_objectives().
func setup(list: Array) -> void:
	for id in _rows.keys():
		var r: Control = _rows[id]
		if is_instance_valid(r):
			r.queue_free()
	_rows.clear()
	_hidden_seen = 0
	_idle = 0.0

	var rows: Array = list.duplicate()
	rows.sort_custom(_sort_rows)
	_bonus_queue.clear()
	var shown_bonuses := 0
	for e in rows:
		var d: Dictionary = e
		var kind: int = int(d.get("kind", 0))
		if kind == KIND_BONUS and not bool(d.get("done", false)):
			if shown_bonuses >= MAX_BONUS_ROWS:
				_bonus_queue.append(d)
				continue
			shown_bonuses += 1
		_add_row(d)
	_sync_header()
	if mode == Mode.FULL:
		_flash_panel()


## Primaries first, then bonuses, then anything hidden that has already fired.
## Within a group, definition order — a list that reshuffles itself between
## glances is unreadable at speed no matter how legible each line is.
func _sort_rows(a, b) -> bool:
	var da: Dictionary = a
	var db: Dictionary = b
	var ka: int = int(da.get("kind", 0))
	var kb: int = int(db.get("kind", 0))
	if ka != kb:
		return ka < kb
	return int(da.get("order", 0)) < int(db.get("order", 0))


func _add_row(d: Dictionary) -> Control:
	var id: StringName = d.get("id", &"")
	if _rows.has(id):
		return _rows[id]
	var row := ObjRow.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.apply(d)
	_col.add_child(row)
	_rows[id] = row
	return row


# ═══════════════════════════════════════════════════════════════ FEEDBACK

func _on_progressed(id: StringName, progress: int, target: int, _kind: int) -> void:
	var row = _rows.get(id, null)
	if row == null or not is_instance_valid(row):
		return
	row.set_progress(progress, target)
	_idle = 0.0
	_wake_panel()


func _on_completed(id: StringName, kind: int, reward: int) -> void:
	var row = _rows.get(id, null)
	if row == null or not is_instance_valid(row):
		# A hidden objective that completed before its reveal handler ran, or a
		# late (end-of-leg) objective. Pull the fresh row straight from Mission.
		if _mission != null and _mission.has_method("objective_row"):
			var d: Dictionary = _mission.objective_row(id)
			if d.is_empty():
				return
			row = _add_row(d)
		else:
			return
	if _mission != null and _mission.has_method("objective_row"):
		var fresh: Dictionary = _mission.objective_row(id)
		if not fresh.is_empty():
			row.apply(fresh)
	row.celebrate()
	_reward_chip(row, reward, kind)
	_idle = 0.0
	_wake_panel()

	# Hidden objectives already got a full-screen banner; a second toast on top
	# of it is noise. Everything else gets one.
	if kind != KIND_HIDDEN:
		_toast_complete(row, kind)

	_sync_header()
	# The row has had its moment. Now it gets out of the way, so a good run
	# ends with an emptier screen than it started with.
	var t := get_tree().create_timer(SETTLE_TIME, true, false, true)
	t.timeout.connect(func():
		if is_instance_valid(row):
			row.collapse()
		if kind == KIND_BONUS:
			_promote_bonus())


func _on_hidden(id: StringName, title: String, line: String, _reward: int) -> void:
	_hidden_seen += 1
	if _mission != null and _mission.has_method("objective_row"):
		var d: Dictionary = _mission.objective_row(id)
		if not d.is_empty():
			_add_row(d)
	if _banner != null and is_instance_valid(_banner):
		_banner.show_reveal(title, line)
	_sync_header()
	_wake_panel()


## A cleared bonus slot refills from the queue, so there is always something
## optional on offer and never a list of everything you haven't done.
func _promote_bonus() -> void:
	if _bonus_queue.is_empty():
		return
	var d: Dictionary = _bonus_queue.pop_front()
	if _mission != null and _mission.has_method("objective_row"):
		var fresh: Dictionary = _mission.objective_row(d.get("id", &""))
		if not fresh.is_empty():
			d = fresh
	if bool(d.get("done", false)):
		_promote_bonus()
		return
	var row := _add_row(d)
	row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.35)
	_wake_panel()


func _toast_complete(row: Control, kind: int) -> void:
	var lbl := Toast.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.head = "OBJECTIVE" if kind == KIND_PRIMARY else "BONUS"
	lbl.body = row.text
	lbl.tint = C_GOLD if kind == KIND_PRIMARY else C_BONUS
	lbl.follow = _panel
	lbl.position = Vector2(18, 76.0 + _panel.size.y + 8.0)
	lbl.size = Vector2(PANEL_W, 34)
	_root.add_child(lbl)
	lbl.run()


func _reward_chip(row: Control, reward: int, kind: int) -> void:
	if reward <= 0:
		return
	var chip := Chip.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.value = reward
	chip.tint = C_HIDDEN if kind == KIND_HIDDEN else C_GOLD
	# Parented to the row, not the screen. A row that was added this frame has
	# not been laid out yet, so its global_position is still (0,0) — the first
	# render test put every "+480" on top of the header.
	chip.position = Vector2(PANEL_W - 128.0, -2.0)
	chip.size = Vector2(120, 26)
	row.add_child(chip)
	chip.run()


# ══════════════════════════════════════════════════════════ MODE / FADING

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("gg_objectives"):
		mode = (mode + 1) % 3
		_apply_mode()


func _apply_mode() -> void:
	match mode:
		Mode.FULL:
			_panel.visible = true
			_col.visible = true
			for id in _rows.keys():
				var r: Control = _rows[id]
				if is_instance_valid(r):
					r.visible = true
			_wake_panel()
		Mode.COMPACT:
			# One line. Still tells you the only two numbers that matter.
			_panel.visible = true
			for id in _rows.keys():
				var r2: Control = _rows[id]
				if is_instance_valid(r2):
					r2.visible = false
			_wake_panel()
		Mode.OFF:
			_panel.visible = false
	_sync_header()


func _wake_panel() -> void:
	_idle = 0.0
	if _panel != null and is_instance_valid(_panel):
		_panel.modulate = Color(1, 1, 1, 1)


func _flash_panel() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	_panel.modulate = Color(1.6, 1.5, 1.1, 1.0)
	var tw := create_tween()
	tw.tween_property(_panel, "modulate", Color(1, 1, 1, 1), 0.8)


func _process(delta: float) -> void:
	_idle += delta
	if _panel == null or not is_instance_valid(_panel):
		return
	# Quiet fade rather than a hard hide. The list is there when you look for
	# it and out of the way when you don't, without the player having to
	# manage a setting mid-flight.
	if _idle > IDLE_FADE_AFTER:
		var target_a := 0.45
		var a: float = _panel.modulate.a
		_panel.modulate.a = move_toward(a, target_a, delta * 0.7)
	if _header != null and is_instance_valid(_header):
		_header.queue_redraw()


func _sync_header() -> void:
	if _header == null or not is_instance_valid(_header):
		return
	var req := 0
	var done := 0
	var total := 0
	var leg := 1
	if _mission != null:
		if _mission.has_method("required_count"):
			req = int(_mission.required_count())
		if _mission.has_method("primaries_done"):
			done = int(_mission.primaries_done())
		if _mission.has_method("primary_count"):
			total = int(_mission.primary_count())
		if _mission.has_method("hidden_total"):
			_hidden_total = int(_mission.hidden_total())
		if _mission.has_method("hidden_found"):
			_hidden_seen = int(_mission.hidden_found())
		leg = int(_mission.leg)
	_header.leg = leg
	_header.required = req
	_header.done = done
	_header.total = total
	_header.hidden_seen = _hidden_seen
	_header.hidden_total = _hidden_total
	_header.compact = mode == Mode.COMPACT
	_header.queue_redraw()


func _on_pref_changed(key: StringName, _value) -> void:
	if key == &"show_hints":
		_refresh_visibility()


## Whether the director wants gameplay HUD on screen at all — false while a menu
## or a card owns it. `main.gd::_set_hud_visible()` calls this.
##
## TWO WRITERS, ONE PROPERTY, AND THE LAST ONE WON. The director used to set
## `visible` on this layer directly, on every menu open and every menu close, so
## "Show hints" OFF held exactly until the player resumed from the very menu
## they had turned it off in — and then the panel came back. Measured through
## the checkbox on 2026-09-25: show_hints=false, menu closed, panel visible=true.
## The last session's handoff recorded this pref as "checked and innocent", on
## the strength of the `pref_changed` listener above, which is real and was
## never the problem. D-056.
func set_host_visible(v: bool) -> void:
	_host_visible = v
	_refresh_visibility()


func _refresh_visibility() -> void:
	var show_it := true
	if _prefs != null:
		show_it = bool(_prefs.get_pref(&"show_hints", true))
	visible = _host_visible and show_it


# ═══════════════════════════════════════════════════════════════ DRAWABLES
#
# Everything below draws itself with primitives and ThemeDB.fallback_font.
# Deliberate: no theme asset, no font import, no Unicode glyph that might not
# exist in whatever font ships. A checkbox drawn as two lines and a rectangle
# renders identically on every machine and reads better at the edge of vision
# than a 14px character does.


class HeaderRow extends Control:
	var leg := 1
	var required := 0
	var done := 0
	var total := 0
	var hidden_seen := 0
	var hidden_total := 0
	var compact := false

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var gold := Color(0.99, 0.80, 0.30)
		var dim := Color(0.66, 0.71, 0.80)

		var head := "LEG %d" % leg
		if required > 0:
			head += "   NEED %d OF %d" % [required, total]
		if compact:
			head = "OBJECTIVES  %d/%d" % [done, required]
		draw_string_outline(font, Vector2(0, 12), head, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 12, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0, 12), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)

		# Pass meter: one pip per required primary, filled as you bank them.
		# The single most important number on the panel, so it is a shape.
		var x := size.x - 12.0
		if hidden_total > 0 and hidden_seen > 0:
			# Only appears AFTER the first discovery. Before that the player
			# does not know hidden objectives exist, and telling them they are
			# missing 10 of them is how a fun secret becomes a chore.
			var txt := "%d FOUND" % hidden_seen
			var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string_outline(font, Vector2(x - w, 12), txt, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 11, 3, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(x - w, 12), txt, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 11, Color(1.0, 0.62, 0.86))
			x -= w + 10.0
		for i in required:
			var r := Rect2(x - 9.0, 3.0, 7.0, 7.0)
			if i < done:
				draw_rect(r, gold, true)
			else:
				draw_rect(r, Color(0, 0, 0, 0.5), true)
				draw_rect(r, gold * Color(1, 1, 1, 0.6), false, 1.0)
			x -= 11.0


class ObjRow extends Control:
	var id: StringName = &""
	var kind := 0
	var text := ""
	var hint := ""
	var progress := 0
	var target := 1
	var unit := ""
	var done := false

	var _shown := 0.0    ## animated bar value, chases `progress`
	var _punch := 0.0
	var _glow := 0.0
	var _collapsing := false

	func apply(d: Dictionary) -> void:
		id = d.get("id", &"")
		kind = int(d.get("kind", 0))
		text = String(d.get("text", ""))
		hint = String(d.get("hint", ""))
		progress = int(d.get("progress", 0))
		target = maxi(1, int(d.get("target", 1)))
		unit = String(d.get("unit", ""))
		done = bool(d.get("done", false))
		_shown = float(progress)
		var h: float = 34.0 if kind == 0 else 26.0
		if hint != "" and kind == 0:
			h += 12.0
		custom_minimum_size = Vector2(400.0, h)
		queue_redraw()

	func set_progress(p: int, t: int) -> void:
		progress = p
		target = maxi(1, t)
		_glow = 1.0
		queue_redraw()

	func celebrate() -> void:
		done = true
		progress = target
		_punch = 1.0
		_glow = 1.0
		queue_redraw()

	func collapse() -> void:
		if _collapsing:
			return
		_collapsing = true
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "custom_minimum_size:y", 0.0, 0.34)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "modulate:a", 0.0, 0.30)
		tw.chain().tween_callback(queue_free)

	func _process(delta: float) -> void:
		var dirty := false
		if not is_equal_approx(_shown, float(progress)):
			# Bars slide rather than snap. Motion is the one thing peripheral
			# vision is genuinely excellent at, so it carries "this changed".
			_shown = move_toward(_shown, float(progress), maxf(1.0, float(target)) * delta * 2.4)
			dirty = true
		if _punch > 0.0:
			_punch = maxf(0.0, _punch - delta * 1.6)
			dirty = true
		if _glow > 0.0:
			_glow = maxf(0.0, _glow - delta * 2.2)
			dirty = true
		if dirty:
			queue_redraw()

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var w := size.x
		var h := size.y
		if h <= 1.0:
			return
		var primary := kind == 0
		var hidden := kind == 2

		var base: Color = Color(0.97, 0.98, 1.00)
		if hidden:
			base = Color(1.00, 0.62, 0.86)
		elif not primary:
			base = Color(0.74, 0.79, 0.88)
		if done:
			base = base.lerp(Color(0.55, 0.60, 0.68), 0.62)
		var accent := Color(0.99, 0.80, 0.30) if primary else base
		if hidden:
			accent = Color(1.00, 0.62, 0.86)
		var lift := _punch * _punch
		base = base.lerp(Color(1.6, 1.5, 1.1), lift * 0.85)
		accent = accent.lerp(Color(1.8, 1.7, 1.2), lift * 0.9)

		# Backing plate. Guarantees contrast over asphalt, grass, sky or a
		# magenta hallucination shader without knowing which it is.
		draw_rect(Rect2(0, 0, w, h - 2.0), Color(0.03, 0.035, 0.06, 0.55 + lift * 0.3), true)

		# Left accent stripe — required work only. Its presence/absence is a
		# pre-attentive cue: you know a row is optional before you read it.
		if primary:
			draw_rect(Rect2(0, 1.0, 3.0, h - 4.0), accent, true)

		var fs: int = 16 if primary else 13
		var tx := 30.0
		var ty: float = 15.0 if primary else 12.0

		_draw_marker(Vector2(12.0, ty - 5.0), primary, hidden, accent, lift)

		var body := text
		if not primary and not hidden:
			body = "+ " + body
		draw_string_outline(font, Vector2(tx, ty), body, HORIZONTAL_ALIGNMENT_LEFT,
			w - tx - 46.0, fs, 4, Color(0, 0, 0, 0.95))
		draw_string(font, Vector2(tx, ty), body, HORIZONTAL_ALIGNMENT_LEFT,
			w - tx - 46.0, fs, base)

		if done:
			var tw_: float = minf(font.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT,
				-1, fs).x, w - tx - 46.0)
			draw_line(Vector2(tx, ty - 4.0), Vector2(tx + tw_, ty - 4.0),
				base * Color(1, 1, 1, 0.8), 1.5)

		if hint != "" and primary and not done:
			draw_string_outline(font, Vector2(tx, ty + 12.0), hint, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 11, 3, Color(0, 0, 0, 0.85))
			draw_string(font, Vector2(tx, ty + 12.0), hint, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 11, base * Color(1, 1, 1, 0.55))

		# Count, right-aligned. Redundant with the bar on purpose: the bar is
		# for glancing, the number is for when you actually look.
		if target > 1:
			var cnt := "%d/%d%s" % [progress, target, unit]
			var cw: float = font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string_outline(font, Vector2(w - cw, ty), cnt, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 12, 3, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(w - cw, ty), cnt, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 12, base)

			var by := h - 6.0
			var bw := w - tx - cw - 12.0
			if bw > 20.0:
				draw_rect(Rect2(tx, by, bw, 3.0), Color(0, 0, 0, 0.55), true)
				var frac: float = clampf(_shown / float(target), 0.0, 1.0)
				var fill := accent
				if _glow > 0.0:
					fill = fill.lerp(Color(1.7, 1.7, 1.4), _glow * 0.7)
				draw_rect(Rect2(tx, by, bw * frac, 3.0), fill, true)

	## Outline square when open, filled square with a tick when done, diamond
	## for a discovered hidden objective. Shapes, not glyphs.
	func _draw_marker(at: Vector2, primary: bool, hidden: bool, accent: Color, lift: float) -> void:
		var s: float = 11.0 if primary else 8.0
		var r := Rect2(at.x - s * 0.5, at.y - s * 0.5, s, s)
		if hidden:
			var c := at
			var pts := PackedVector2Array([
				c + Vector2(0, -s * 0.75), c + Vector2(s * 0.7, 0),
				c + Vector2(0, s * 0.75), c + Vector2(-s * 0.7, 0)])
			draw_colored_polygon(pts, accent)
			return
		if done:
			draw_rect(r, accent, true)
			draw_line(r.position + Vector2(s * 0.2, s * 0.52),
				r.position + Vector2(s * 0.44, s * 0.78), Color(0.05, 0.05, 0.08), 2.0)
			draw_line(r.position + Vector2(s * 0.44, s * 0.78),
				r.position + Vector2(s * 0.84, s * 0.22), Color(0.05, 0.05, 0.08), 2.0)
		else:
			draw_rect(r, Color(0, 0, 0, 0.5), true)
			draw_rect(r, accent * Color(1, 1, 1, 0.85), false, 1.0 + lift)


## The completion toast. Sits directly under the panel so the eye that flicked
## to the corner for the flash finds the words in the same place.
class Toast extends Control:
	var head := "OBJECTIVE"
	var body := ""
	var tint := Color(0.99, 0.80, 0.30)
	var follow: Control = null

	func run() -> void:
		var tw := create_tween()
		tw.tween_property(self, "position:x", position.x + 6.0, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.5)
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(queue_free)

	## The panel resizes constantly — rows appear, complete and collapse out.
	## A toast placed once at spawn time sits on top of the list a second later,
	## so it tracks the panel's live bottom edge every frame instead.
	func _process(_delta: float) -> void:
		if follow != null and is_instance_valid(follow):
			position.y = follow.global_position.y + follow.size.y + 8.0
		queue_redraw()

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, size.x, 30.0), Color(0.02, 0.025, 0.045, 0.62), true)
		draw_rect(Rect2(0, 0, 3.0, 30.0), tint, true)
		draw_string_outline(font, Vector2(10, 13), head, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(10, 13), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
		draw_string_outline(font, Vector2(10, 26), body, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 16.0, 13, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(10, 26), body, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 16.0, 13, Color(0.95, 0.96, 1.0))


## "+250" arcing up off the finished row. Cheap, and it is the bit that makes
## a completion feel like a payout rather than a checkbox.
class Chip extends Control:
	var value := 0
	var tint := Color(0.99, 0.80, 0.30)

	func run() -> void:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "position:y", position.y - 34.0, 0.9)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "position:x", position.x + 16.0, 0.9)
		tw.tween_property(self, "modulate:a", 0.0, 0.9).set_delay(0.35)
		tw.chain().tween_callback(queue_free)

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var txt := "+%d" % value
		draw_string_outline(font, Vector2(0, 18), txt, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 20, 5, Color(0, 0, 0, 0.95))
		draw_string(font, Vector2(0, 18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, tint)


## Hidden-objective reveal. Lower third, full width, gold on near-black, held
## long enough to read at speed and short enough not to interrupt a run.
## This is the payoff moment of the entire system, so it gets real estate the
## rest of the HUD is never allowed.
class Banner extends Control:
	var title := ""
	var line := ""
	var _a := 0.0
	var _scale := 0.86
	var _busy := false
	var _queue: Array = []

	## Two hidden objectives CAN fire on the same frame — a cart train that also
	## tips you past the opening-chaos threshold, for instance. Without a queue
	## the second reveal restarts the tween and the player sees half of one
	## banner and none of the other, which reads as a bug at exactly the moment
	## the game is trying to feel generous.
	func show_reveal(p_title: String, p_line: String) -> void:
		_queue.append([p_title, p_line])
		if not _busy:
			_next()

	func _next() -> void:
		if _queue.is_empty():
			_busy = false
			title = ""
			queue_redraw()
			return
		_busy = true
		var pair: Array = _queue.pop_front()
		title = String(pair[0])
		line = String(pair[1])
		_a = 0.0
		_scale = 0.86
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "_a", 1.0, 0.16)
		tw.tween_property(self, "_scale", 1.0, 0.42)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_interval(2.3)
		tw.chain().tween_property(self, "_a", 0.0, 0.55)
		tw.chain().tween_callback(_next)
		queue_redraw()

	func _process(_delta: float) -> void:
		if _a > 0.0:
			queue_redraw()

	func _draw() -> void:
		if _a <= 0.001 or title == "":
			return
		var font: Font = ThemeDB.fallback_font
		var gold := Color(1.0, 0.72, 0.90)
		var cy := size.y * 0.66
		var band := 96.0 * _scale

		draw_rect(Rect2(0, cy - band * 0.5, size.x, band), Color(0.02, 0.01, 0.03, 0.80 * _a), true)
		draw_rect(Rect2(0, cy - band * 0.5, size.x, 2.0), gold * Color(1, 1, 1, _a), true)
		draw_rect(Rect2(0, cy + band * 0.5 - 2.0, size.x, 2.0), gold * Color(1, 1, 1, _a), true)

		var kicker := "SOMETHING HAPPENED"
		var kw: float = font.get_string_size(kicker, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2((size.x - kw) * 0.5, cy - band * 0.5 + 22.0), kicker,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5 * _a))

		var ts: int = int(32.0 * _scale)
		var tw_: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var tp := Vector2((size.x - tw_) * 0.5, cy + 6.0)
		draw_string_outline(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, 6,
			Color(0, 0, 0, 0.95 * _a))
		draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts,
			gold * Color(1, 1, 1, _a))

		var lw: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var lp := Vector2((size.x - lw) * 0.5, cy + 32.0)
		draw_string_outline(font, lp, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4,
			Color(0, 0, 0, 0.9 * _a))
		draw_string(font, lp, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(0.95, 0.95, 1.0, 0.9 * _a))
