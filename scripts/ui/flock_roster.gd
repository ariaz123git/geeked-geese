extends CanvasLayer
## THE FLOCK ROSTER — who is still with you, and who isn't.
##
## ── WHY THIS EXISTS ─────────────────────────────────────────────────────
## The flock is the game's score. It is also, until this screen, the only
## system with no interface: you could see your geese in the pen and watch a
## name flash red for two seconds mid-flight, and that was the entire record of
## a forty-five minute attrition curve. Losses read as arbitrary because there
## was nowhere to go and look at what you had left.
##
## Three rules drove the layout, in this order:
##
##   1. **A LOSS MUST HAVE A FACE.** A goose that is gone is drawn greyed out,
##      struck through, and captioned with how and where it went. That caption
##      comes from `Flock.lose_bird(index, reason)` — the reason string exists
##      purely so that this line can say "flew into a wire over Buffalo" instead
##      of leaving a hole in a list. The dead keep their position in the roster
##      rather than being sorted to the bottom, because the gap where somebody
##      used to stand is the entire point.
##
##   2. **READABLE AT A GLANCE.** One row per bird, always in the same order, so
##      a player who opens this mid-run under a clock re-reads it rather than
##      re-parses it. Every channel is redundant: condition is a colour AND a
##      segmented bar AND a number AND a word.
##
##   3. **IT LOOKS LIKE THE REST OF THE GAME.** Palette, plate, outlined text
##      and the one-`_walk()`-pass layout are lifted from results_screen.gd;
##      the per-bird condition colours are flock_pen.gd's, verbatim, so a goose
##      that is orange standing in the lot is orange on this screen.
##
## ── PORTRAITS ───────────────────────────────────────────────────────────
## flock_pen.gd's presentation is 3D — a goose model, a Label3D and a raycast to
## the ground. Reusing it per row would mean one SubViewport plus one Camera3D
## plus one full goose mesh per bird, on a screen that exists to be opened and
## closed in four seconds. It isn't affordable and it isn't needed: the row
## draws a flat side-profile goose instead, which greys and strikes out cleanly
## and costs four polygons.
##
## ── INTEGRATION ─────────────────────────────────────────────────────────
##   roster.open()                      # from the pause menu
##   roster.open(["WAYNE"])             # after a flight that cost you somebody
##   await roster.closed
##
## It pauses the tree ONLY if the tree was not already paused, and unpauses only
## what it paused — otherwise opening it from the pause menu would resume the
## game behind the still-open pause menu.

signal closed()

## Above the pause menu (30) and the results card (28), below the control card
## (41). It has to clear the pause menu because it is opened from it, and it has
## to clear the results card because a loss is announced immediately after one.
const LAYER := 32

# ── palette. Mirrors results_screen.gd rather than importing it: these are two
# screens that should look the same, not one screen with a shared dependency.
const C_PLATE := Color(0.045, 0.05, 0.082, 0.985)
const C_GOLD := Color(0.99, 0.80, 0.30)
const C_WARN := Color(0.99, 0.74, 0.40)
const C_BAD := Color(0.96, 0.40, 0.36)
const FONT_DIM := Color(0.55, 0.59, 0.67)
const FONT_OK := Color(0.62, 0.93, 0.66)
const C_YOU := Color(0.55, 0.80, 0.98)
const C_DD := Color(0.99, 0.93, 0.20)
## A lost bird is drawn in exactly one colour and it is not a red — red is
## alarm, and this is absence.
const C_LOST := Color(0.44, 0.46, 0.53)

# flock_pen.gd's condition ladder, unchanged.
const C_FINE := Color(0.55, 0.92, 0.62)
const C_LOOSE := Color(0.96, 0.88, 0.38)
const C_ROUGH := Color(0.98, 0.62, 0.28)
const C_WRECKED := Color(0.98, 0.36, 0.32)

## Design canvas: one fixed rectangle, uniformly scaled and centred. Same
## reasoning as the results card — there is no anchoring to get wrong because
## there is only one rectangle.
const CARD_W := 880.0
const CARD_PAD := 28.0
const ROW_H := 72.0
## The flock is six and can never grow past it, but a roster that silently drops
## a bird would be the worst possible bug on this particular screen.
const MAX_ROWS := 8
const MAX_UPSCALE := 1.25

var _flock: Node = null
var _sfx: Node = null

var _open := false
var _t := 0.0
var _paused_by_me := false
var _restore_mouse: int = Input.MOUSE_MODE_VISIBLE

var _backdrop: ColorRect = null
var _card: Control = null


func _ready() -> void:
	# ALWAYS, not WHEN_PAUSED: this node decides whether the tree is paused, so
	# it has to keep running across the frame on which it flips it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	_flock = get_node_or_null("/root/Flock")
	_sfx = get_node_or_null("/root/Sfx")

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.015, 0.018, 0.032, 0.93)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	get_viewport().size_changed.connect(_reflow)


# ════════════════════════════════════════════════════════════════ PUBLIC API

func is_open() -> bool:
	return _open


## `headline` is the names of anyone lost in the event that caused this screen
## to open. Empty for a deliberate open from the pause menu.
func open(headline: Array = []) -> void:
	if _open:
		return
	_t = 0.0
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = Card.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.setup(_gather(headline))
	add_child(_card)
	_place_card()

	_open = true
	visible = true
	_restore_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Only pause what we actually paused. Opened from the pause menu the tree is
	# already stopped, and unpausing it on close would resume the game behind a
	# menu that is still on screen.
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	if _sfx != null:
		_sfx.play(&"score_blip", -13.0, 0.85 if headline.is_empty() else 0.62)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null
	if _paused_by_me:
		_paused_by_me = false
		get_tree().paused = false
	Input.mouse_mode = _restore_mouse
	if _sfx != null:
		_sfx.play(&"score_blip_hi", -14.0, 1.15)
	closed.emit()


## The phase got yanked out from under us.
func force_close() -> void:
	if _open:
		close()


# ═══════════════════════════════════════════════════════════ DATA GATHERING
#
# Every read out of Flock.birds[i] is a Variant and every one of them is
# annotated on the way out — `var x := b.get("intox")` is a hard parse error,
# not a warning.

func _gather(headline: Array) -> Dictionary:
	var rows: Array[Dictionary] = []
	var alive := 0
	var summary := ""
	var leg := 1
	var player_index := -1

	if _flock != null:
		leg = int(_flock.leg)
		player_index = int(_flock.player_index)
		var raw: Array = _flock.birds
		for i in raw.size():
			var b: Dictionary = raw[i]
			var is_alive: bool = bool(b.get("alive", true))
			if is_alive:
				alive += 1
			var can := false
			if is_alive and _flock.has_method("can_lead"):
				can = bool(_flock.can_lead(i))
			var note := ""
			if _flock.has_method("scar_note"):
				note = str(_flock.scar_note(i))
			rows.append({
				"name": str(b.get("name", "?")),
				"alive": is_alive,
				"intox": float(b.get("intox", 0.0)),
				"stamina": float(b.get("stamina", 1.0)),
				"is_dd": bool(b.get("is_dd", false)),
				"is_you": i == player_index,
				"can_lead": can,
				"scars": int(b.get("scars", 0)),
				"scar_note": note,
				"lost_reason": str(b.get("lost_reason", "")),
				"lost_leg": int(b.get("lost_leg", 0)),
				"joined_at_leg": int(b.get("joined_at_leg", 1)),
			})
		if _flock.has_method("condition_summary"):
			summary = str(_flock.condition_summary())

	var has_dd := false
	for r in rows:
		if bool(r.get("is_dd", false)) and bool(r.get("alive", false)):
			has_dd = true
			break

	var names: Array[String] = []
	for h in headline:
		names.append(str(h).to_upper())

	return {
		"rows": rows,
		"alive": alive,
		"total": rows.size(),
		"leg": leg,
		"summary": summary,
		"headline": names,
		"has_dd": has_dd,
	}


# ═════════════════════════════════════════════════════════════ LOOP + INPUT

func _process(delta: float) -> void:
	if not _open:
		return
	# Wall-clock. A substance can leave Engine.time_scale anywhere, and a menu
	# that fades in at a third speed because the player was on a whippet reads
	# as the game hanging.
	_t += delta / maxf(Engine.time_scale, 0.05)
	if _card != null and is_instance_valid(_card):
		_card.t = _t
		_card.queue_redraw()
		_place_card()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var wants_close := false
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		wants_close = true
	elif InputMap.has_action("gg_skip") and event.is_action_pressed("gg_skip"):
		wants_close = true
	elif event is InputEventMouseButton and event.pressed:
		wants_close = true
	if not wants_close:
		return
	# Consume it, or the same Escape that closed this immediately opens the
	# pause menu underneath.
	get_viewport().set_input_as_handled()
	close()


# ═════════════════════════════════════════════════════════════════ LAYOUT

func _reflow() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	_card.measure()
	_place_card()


func _place_card() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var vs := get_viewport().get_visible_rect().size
	var want: Vector2 = _card.card_size
	var s: float = minf((vs.x - 40.0) / want.x, (vs.y - 28.0) / want.y)
	s = clampf(s, 0.30, MAX_UPSCALE)
	_card.size = want
	_card.pivot_offset = Vector2.ZERO
	var isc: float = _card.intro_scale()
	_card.scale = Vector2(s, s) * isc
	_card.position = ((vs - want * _card.scale) * 0.5).round()


# ══════════════════════════════════════════════════════════════════ THE CARD

class Card extends Control:
	## One `_walk(do_draw)` is the single source of truth for layout: called once
	## with false to measure and once a frame with true to paint, so the two can
	## never disagree about where anything is. Same pattern as the results card.

	## A flat side-profile Canada goose, in a unit box, facing right. Screen
	## coordinates, so +y is DOWN and the head sits at the top — this is 2D, and
	## the project's "-Z is forward" rule has nothing to say about it.
	## Plain Arrays, not PackedVector2Array: the packed constructor is not a
	## constant expression in 4.7 and a `const` holding one is a parse error.
	## _poly() packs them at draw time anyway.
	const G_BODY := [
		Vector2(0.06, 0.62), Vector2(0.20, 0.50), Vector2(0.42, 0.46),
		Vector2(0.60, 0.52), Vector2(0.68, 0.64), Vector2(0.66, 0.80),
		Vector2(0.50, 0.92), Vector2(0.30, 0.94), Vector2(0.14, 0.86),
		Vector2(0.04, 0.72),
	]
	const G_TAIL := [
		Vector2(0.10, 0.56), Vector2(-0.14, 0.44), Vector2(0.04, 0.70),
	]
	const G_NECK := [
		Vector2(0.56, 0.56), Vector2(0.62, 0.16), Vector2(0.77, 0.16),
		Vector2(0.70, 0.58),
	]
	const G_CHEEK := [
		Vector2(0.615, 0.07), Vector2(0.70, 0.05), Vector2(0.70, 0.21),
		Vector2(0.615, 0.20),
	]
	const G_BEAK := [
		Vector2(0.79, 0.09), Vector2(1.00, 0.13), Vector2(0.79, 0.19),
	]
	const G_SIZE := 42.0
	## The tail pokes into negative x, so the glyph column starts inset.
	const G_INSET := 8.0
	const G_COL := 62.0

	## Where the two condition bars start, measured from the card's inner left.
	const BAR_X := 452.0
	const BAR_W := 348.0

	var d: Dictionary = {}
	var t := 0.0
	var card_size := Vector2(RW, 640.0)

	var _panel: StyleBoxFlat


	func setup(data: Dictionary) -> void:
		d = data
		_panel = StyleBoxFlat.new()
		_panel.bg_color = RPlate
		_panel.set_corner_radius_all(18)
		_panel.border_width_top = 6
		_panel.border_width_left = 1
		_panel.border_width_right = 1
		_panel.border_width_bottom = 1
		var head: Array = d.get("headline", [])
		_panel.border_color = RBad if not head.is_empty() else RGold
		_panel.shadow_color = Color(0, 0, 0, 0.65)
		_panel.shadow_size = 26
		measure()


	func measure() -> void:
		var h := _walk(false)
		card_size = Vector2(RW, h)
		custom_minimum_size = card_size
		size = card_size


	func intro_scale() -> float:
		if t >= 0.28:
			return 1.0
		return lerpf(0.90, 1.0, _ease_out(clampf(t / 0.28, 0.0, 1.0)))


	static func _ease_out(u: float) -> float:
		return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


	## 0..1 fade-in for a block starting at t0. Rows stagger down the list, which
	## is what makes a roster read as being counted rather than as being printed.
	func _rev(t0: float, dur := 0.22) -> float:
		if t <= t0:
			return 0.0
		return _ease_out((t - t0) / dur)


	func _f() -> Font:
		return ThemeDB.fallback_font


	## draw_string with a black outline. Same helper as the results card, same
	## reason: every readable thing here sits over a live 3D scene.
	func _text(pos: Vector2, s: String, fs: int, col: Color,
			align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 4) -> void:
		if col.a <= 0.004 or s == "":
			return
		var f := _f()
		if outline > 0:
			f.draw_string_outline(get_canvas_item(), pos, s, align, w, fs, outline,
				Color(0, 0, 0, col.a * 0.85))
		f.draw_string(get_canvas_item(), pos, s, align, w, fs, col)


	## Hard-truncate to a pixel width. draw_string clips silently at `width`,
	## which ends a line mid-word with no indication it was cut.
	func _clip(s: String, fs: int, w: float) -> String:
		var f := _f()
		if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return s
		var out := s
		while out.length() > 4 and f.get_string_size(out + "…",
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			out = out.substr(0, out.length() - 1)
		return out + "…"


	func _draw() -> void:
		draw_style_box(_panel, Rect2(Vector2.ZERO, card_size))
		_walk(true)


	# ══════════════════════════════════════════════════ THE ONE LAYOUT PASS

	func _walk(do_draw: bool) -> float:
		var f := _f()
		var x := CARD_PAD
		var y := CARD_PAD
		var inner := RW - CARD_PAD * 2.0

		var rows: Array = d.get("rows", [])
		var head: Array = d.get("headline", [])
		var alive: int = int(d.get("alive", 0))
		var total: int = int(d.get("total", 0))

		# ── header ─────────────────────────────────────────────────────
		var ha := _rev(0.0, 0.24)
		var oy := (1.0 - ha) * 8.0
		if do_draw:
			_text(Vector2(x, y + oy + f.get_ascent(14)), "LEG %d" % int(d.get("leg", 1)), 14,
				Color(RGold.r, RGold.g, RGold.b, 0.85 * ha))
			_text(Vector2(x, y + oy + f.get_ascent(14)),
				"%d OF %d STILL WITH YOU" % [alive, total], 14,
				Color(1, 1, 1, 0.70 * ha), HORIZONTAL_ALIGNMENT_RIGHT, inner)
		y += f.get_ascent(14) + f.get_descent(14) + 5.0

		# The title is the verdict. When this screen opens itself it opens with a
		# name on it, because "THE FLOCK" is a menu and "WAYNE DIDN'T MAKE IT" is
		# the reason the menu appeared.
		var title := "THE FLOCK"
		var tcol: Color = Color(0.95, 0.96, 1.0)
		if not head.is_empty():
			var joined := str(head[0])
			for i in range(1, head.size()):
				joined += (" AND " if i == head.size() - 1 else ", ") + str(head[i])
			title = "%s DIDN'T MAKE IT" % joined
			tcol = RBad
		if do_draw:
			_text(Vector2(x, y + oy + f.get_ascent(36)), _clip(title, 36, inner), 36,
				Color(tcol.r, tcol.g, tcol.b, ha), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5)
		y += f.get_ascent(36) + f.get_descent(36) + 10.0

		if do_draw:
			draw_rect(Rect2(x, y, inner, 1.0), Color(1, 1, 1, 0.16 * ha), true)
		y += 12.0

		# ── the roster ─────────────────────────────────────────────────
		if rows.is_empty():
			if do_draw:
				_text(Vector2(x, y + f.get_ascent(16)),
					"Nobody on the books. That should not be possible.", 16,
					Color(RDim.r, RDim.g, RDim.b, ha))
			y += 30.0
		var shown := 0
		for r in rows:
			if shown >= MAX_ROWS:
				break
			var row: Dictionary = r
			var a := _rev(0.10 + float(shown) * 0.055, 0.24)
			if do_draw and a > 0.002:
				_row(Vector2(x, y), inner, row, a)
			y += ROW_H
			shown += 1
		var over: int = rows.size() - shown
		if over > 0:
			if do_draw:
				_text(Vector2(x + G_COL, y + f.get_ascent(13)), "+%d more" % over, 13,
					Color(RDim.r, RDim.g, RDim.b, ha))
			y += 20.0

		# ── footer ─────────────────────────────────────────────────────
		y += 6.0
		if do_draw:
			draw_rect(Rect2(x, y, inner, 1.0), Color(1, 1, 1, 0.16 * ha), true)
		y += 13.0

		var fa := _rev(0.55, 0.3)
		if do_draw:
			_text(Vector2(x, y + f.get_ascent(15)),
				_clip(str(d.get("summary", "")), 15, inner - 140.0), 15,
				Color(0.87, 0.90, 0.96, fa))
			# Gentle pulse so the way out reads as "waiting for you" rather than
			# as another line of the table.
			var pulse: float = 0.72 + 0.28 * (0.5 + 0.5 * sin(t * 4.0))
			_text(Vector2(x, y + f.get_ascent(15)), "ESC  ·  ENTER      BACK", 15,
				Color(1, 1, 1, 0.66 * fa * pulse), HORIZONTAL_ALIGNMENT_RIGHT, inner)
		y += f.get_ascent(15) + f.get_descent(15)

		# The one thing this screen can tell a player to DO. A sober bird is the
		# best thing you can carry into a flight and the pen is the only place to
		# name one, so a flock with nobody driving gets told so here rather than
		# finding out at 30 metres with nobody fit to take the point.
		if not bool(d.get("has_dd", false)) and not rows.is_empty():
			y += 5.0
			if do_draw:
				_text(Vector2(x, y + f.get_ascent(13)),
					"NOBODY IS DRIVING.  Walk up to a goose in the zone and press [G].", 13,
					Color(RDD.r, RDD.g, RDD.b, 0.88 * fa))
			y += f.get_ascent(13) + f.get_descent(13)

		return y + CARD_PAD * 0.9


	# ── one bird ───────────────────────────────────────────────────────

	func _row(at: Vector2, inner: float, row: Dictionary, a: float) -> void:
		var f := _f()
		var alive: bool = bool(row.get("alive", true))
		var is_dd: bool = bool(row.get("is_dd", false))
		var is_you: bool = bool(row.get("is_you", false))
		var intox: float = float(row.get("intox", 0.0))
		var stamina: float = float(row.get("stamina", 1.0))
		var scars: int = int(row.get("scars", 0))

		var oy := (1.0 - a) * 7.0
		var y := at.y + oy

		# A lost row sits in a darker slot. It should read as a hole in the list
		# before a single word of it has been read.
		if not alive:
			draw_rect(Rect2(at.x - 6.0, y - 2.0, inner + 12.0, ROW_H - 8.0),
				Color(0, 0, 0, 0.34 * a), true)

		var cond := _condition_colour(alive, is_dd, intox, stamina)
		cond.a = a

		# ── the bird ──
		var body := cond
		# A Canada goose's head and neck are black. Keeping a fifth of the
		# condition hue in them means a wrecked bird still reads as red at a
		# glance; any more than that and the DD's head goes olive and the bird
		# stops being a Canada goose.
		var dark := Color(0.055, 0.055, 0.075).lerp(cond, 0.20)
		dark.a = a
		var cheek := Color(0.94, 0.95, 0.98, a)
		if not alive:
			body = Color(RLost.r, RLost.g, RLost.b, 0.55 * a)
			dark = Color(RLost.r * 0.55, RLost.g * 0.55, RLost.b * 0.6, 0.55 * a)
			cheek = Color(RLost.r, RLost.g, RLost.b, 0.7 * a)
		_goose(Vector2(at.x + G_INSET, y + 9.0), G_SIZE, body, dark, cheek)

		# ── name + badges ──
		var nx := at.x + G_COL
		var nm: String = str(row.get("name", "?")).to_upper()
		var ncol := Color(0.95, 0.96, 1.0, a) if alive else Color(RLost.r, RLost.g, RLost.b, a)
		var nfs := 22
		_text(Vector2(nx, y + f.get_ascent(nfs)), nm, nfs, ncol)
		var nw: float = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		if not alive:
			# Struck through. The single most legible "this one is gone" mark
			# there is, and it survives being read at a glance from a metre back.
			var sy: float = y + f.get_ascent(nfs) * 0.62
			draw_line(Vector2(nx - 2.0, sy), Vector2(nx + nw + 2.0, sy),
				Color(RLost.r, RLost.g, RLost.b, a), 2.0)

		var bx := nx + nw + 12.0
		if is_you:
			bx += _badge(Vector2(bx, y + 3.0), "YOU", RYou, a) + 6.0
		if is_dd and alive:
			bx += _badge(Vector2(bx, y + 3.0), "DD", RDD, a) + 6.0
		if alive:
			if bool(row.get("can_lead", false)):
				bx += _badge(Vector2(bx, y + 3.0), "FIT TO LEAD", ROk, a) + 6.0
			else:
				bx += _badge(Vector2(bx, y + 3.0), "CAN'T TAKE A SHIFT", RBad, a) + 6.0
		if int(row.get("joined_at_leg", 1)) > 1 and alive:
			bx += _badge(Vector2(bx, y + 3.0), "MET ON THE ROUTE", RGold, a) + 6.0

		# ── scars, and the line under the name ──
		var sub_y := y + f.get_ascent(nfs) + 13.0
		var sub_x := nx
		if scars > 0:
			sub_x += _scar_pips(Vector2(nx, sub_y - 4.0), scars, a) + 8.0

		var sub := ""
		var scol := Color(RDim.r, RDim.g, RDim.b, 0.95 * a)
		if alive:
			sub = str(row.get("scar_note", ""))
			if sub == "":
				sub = "no marks on it yet"
				scol = Color(RDim.r, RDim.g, RDim.b, 0.55 * a)
		else:
			sub = str(row.get("lost_reason", ""))
			if sub == "":
				sub = "went down somewhere on the way"
			var lost_leg: int = int(row.get("lost_leg", 0))
			if lost_leg > 0:
				sub = "%s  ·  leg %d" % [sub, lost_leg]
			scol = Color(RLost.r, RLost.g, RLost.b, a)
		_text(Vector2(sub_x, sub_y + f.get_ascent(13)),
			_clip(sub, 13, BAR_X - (sub_x - at.x) - 18.0), 13, scol)

		# ── the two bars ──
		var bar_left := at.x + BAR_X
		if alive:
			_meter(Vector2(bar_left, y + 4.0), "INTOXICATION", intox,
				_intox_colour(is_dd, intox), a, _intox_word(is_dd, intox))
			_meter(Vector2(bar_left, y + 30.0), "STAMINA", stamina,
				_stamina_colour(stamina), a, "")
		else:
			# No bars for a bird that isn't here. A greyed-out 0% still reads as
			# a measurement of somebody present.
			_text(Vector2(bar_left, y + 16.0 + f.get_ascent(15)), "NOT WITH YOU ANY MORE", 15,
				Color(RLost.r, RLost.g, RLost.b, a))
			draw_rect(Rect2(bar_left, y + 40.0, BAR_W, 1.0),
				Color(RLost.r, RLost.g, RLost.b, 0.35 * a), true)

		# Row rule.
		draw_rect(Rect2(at.x, at.y + ROW_H - 9.0, inner, 1.0), Color(1, 1, 1, 0.07 * a), true)


	## Label, segmented bar and a number, on one line. Three redundant readings
	## of the same value — the peripheral-vision rule from DESIGN_MISSIONS.md §7
	## is that no channel is ever alone.
	func _meter(at: Vector2, label: String, frac: float, col: Color, a: float,
			word: String) -> void:
		var f := _f()
		var lw := 96.0
		var num_w := 44.0
		_text(Vector2(at.x, at.y + f.get_ascent(11)), label, 11,
			Color(RDim.r, RDim.g, RDim.b, 0.95 * a))
		if word != "":
			_text(Vector2(at.x + lw, at.y + f.get_ascent(11)), word, 11,
				Color(col.r, col.g, col.b, 0.95 * a), HORIZONTAL_ALIGNMENT_RIGHT,
				BAR_W - lw)
		var bar_x := at.x + lw
		var bar_w := BAR_W - lw - num_w - 8.0
		var by := at.y + 13.0
		var segs := 10
		var gap := 3.0
		var sw: float = (bar_w - gap * float(segs - 1)) / float(segs)
		var filled: int = int(round(clampf(frac, 0.0, 1.0) * float(segs)))
		for i in segs:
			var r := Rect2(bar_x + float(i) * (sw + gap), by, sw, 9.0)
			if i < filled:
				draw_rect(r, Color(col.r, col.g, col.b, a), true)
			else:
				draw_rect(r, Color(1, 1, 1, 0.12 * a), true)
		_text(Vector2(at.x, by - 2.0 + f.get_ascent(14)),
			"%d%%" % int(round(clampf(frac, 0.0, 1.0) * 100.0)), 14,
			Color(0.92, 0.94, 0.99, a), HORIZONTAL_ALIGNMENT_RIGHT, BAR_W)


	## One small triangle per scar — a drawn shape, never a glyph, so it cannot
	## turn into a missing-character box on somebody else's font fallback.
	## Returns the width it used.
	func _scar_pips(at: Vector2, scars: int, a: float) -> float:
		var n: int = mini(scars, 3)
		var step := 13.0
		for i in n:
			var c := at + Vector2(float(i) * step + 5.0, 8.0)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -5.5), c + Vector2(5.2, 4.0), c + Vector2(-5.2, 4.0)]),
				Color(RWarn.r, RWarn.g, RWarn.b, 0.92 * a))
		var w := float(n) * step
		if scars > 3:
			var f := _f()
			_text(Vector2(at.x + w + 2.0, at.y + f.get_ascent(11)), "x%d" % scars, 11,
				Color(RWarn.r, RWarn.g, RWarn.b, 0.9 * a))
			w += 20.0
		return w


	## A small filled capsule with a word in it. Returns its width.
	func _badge(at: Vector2, txt: String, col: Color, a: float) -> float:
		var f := _f()
		var fs := 11
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w := tw + 14.0
		var h := 17.0
		var r := Rect2(at.x, at.y, w, h)
		draw_rect(r, Color(col.r, col.g, col.b, 0.18 * a), true)
		draw_rect(r, Color(col.r, col.g, col.b, 0.85 * a), false, 1.0)
		_text(Vector2(at.x + 7.0, at.y + (h - f.get_ascent(fs) - f.get_descent(fs)) * 0.5
			+ f.get_ascent(fs)), txt, fs, Color(col.r, col.g, col.b, a),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
		return w


	# ── the drawn goose ────────────────────────────────────────────────

	func _poly(pts: Array, at: Vector2, s: float, col: Color) -> void:
		var out := PackedVector2Array()
		for p in pts:
			# Array elements are Variants; PackedVector2Array.append refuses one.
			var v: Vector2 = p
			out.append(at + v * s)
		draw_colored_polygon(out, col)


	func _goose(at: Vector2, s: float, body: Color, dark: Color, cheek: Color) -> void:
		_poly(G_TAIL, at, s, body)
		_poly(G_BODY, at, s, body)
		_poly(G_NECK, at, s, dark)
		draw_circle(at + Vector2(0.715, 0.125) * s, 0.135 * s, dark)
		_poly(G_CHEEK, at, s, cheek)
		_poly(G_BEAK, at, s, dark)
		# The eye last and darker than everything, or it vanishes into the head.
		draw_circle(at + Vector2(0.775, 0.095) * s, 0.030 * s,
			Color(0.03, 0.03, 0.05, body.a))


	# ── condition wording, shared with the pen ─────────────────────────

	func _condition_colour(alive: bool, is_dd: bool, intox: float, stamina: float) -> Color:
		if not alive:
			return RLost
		if is_dd:
			return RDD
		if intox > 0.75:
			return RWrecked
		if intox > 0.45:
			return RRough
		if intox > 0.2 or stamina < 0.35:
			return RLoose
		return RFine


	func _intox_colour(is_dd: bool, intox: float) -> Color:
		if is_dd:
			return RDD
		if intox > 0.75:
			return RWrecked
		if intox > 0.45:
			return RRough
		if intox > 0.2:
			return RLoose
		return RFine


	## The same five words flock_pen.gd puts over their heads in the zone, so the
	## screen and the world agree about what state a bird is in.
	func _intox_word(is_dd: bool, intox: float) -> String:
		if is_dd:
			return "DESIGNATED DRIVER"
		if intox > 0.75:
			return "WRECKED"
		if intox > 0.45:
			return "rough"
		if intox > 0.2:
			return "loose"
		return "sober"


	func _stamina_colour(stamina: float) -> Color:
		if stamina < 0.2:
			return RWrecked
		if stamina < 0.45:
			return RRough
		return ROk


## Inner classes can't see the outer script's members by every name, so
## everything the card needs gets one explicit alias here — the same trick
## results_screen.gd and briefing.gd use.
const RW := CARD_W
const RPlate := C_PLATE
const RGold := C_GOLD
const RWarn := C_WARN
const RBad := C_BAD
const RDim := FONT_DIM
const ROk := FONT_OK
const RYou := C_YOU
const RDD := C_DD
const RLost := C_LOST
const RFine := C_FINE
const RLoose := C_LOOSE
const RRough := C_ROUGH
const RWrecked := C_WRECKED
