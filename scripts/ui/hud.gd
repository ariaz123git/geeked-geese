extends CanvasLayer
## HUD + the screen-effect stack.
##
## The Goose Brain is the educational spine of the entire game and it works by
## saying nothing. Four labelled fluids that visibly respond to what you ate.
## No tooltip ever explains what dopamine is. Players read their own HUD for
## twenty hours and go look it up themselves. That's the win condition.

const BRAIN_COLORS := {
	"dopamine": Color(0.98, 0.78, 0.20),
	"adrenaline": Color(0.92, 0.26, 0.24),
	"gaba": Color(0.32, 0.62, 0.95),
	"serotonin": Color(0.38, 0.84, 0.50),
}

var fx_rect: ColorRect
var fx_mat: ShaderMaterial
var lbl_timer: Label
var lbl_chaos: Label
var lbl_combo: Label
var lbl_actives: Label
var lbl_toast: Label
var lbl_state: Label
var brain: Control
var dose: Control
var stamina_bar: Control
var goose: Goose
var icon_row: HBoxContainer
var lbl_leg: Label

var _toast_t := 0.0
var _fx_intensity := 1.0
var _sfx: Node


func _ready() -> void:
	layer = 2
	_sfx = get_node_or_null("/root/Sfx")
	_read_prefs()
	var prefs := get_node_or_null("/root/Prefs")
	if prefs and prefs.has_signal("pref_changed"):
		prefs.pref_changed.connect(func(_k, _v): _read_prefs())
	_build_fx()
	_build_hud()
	_wire_unlocks()


func _read_prefs() -> void:
	var prefs := get_node_or_null("/root/Prefs")
	if prefs:
		# Accessibility valve: the substance effects are strong on purpose, but
		# nobody should have to choose between playing and feeling sick.
		_fx_intensity = clampf(float(prefs.get_pref(&"fx_intensity", 1.0)), 0.0, 1.0)


## First time a substance is ever taken it unlocks an Almanac entry. That's the
## only moment the educational layer ever announces itself, and it's a reward,
## not an interruption — a toast and a chime, never a modal.
func _wire_unlocks() -> void:
	var unlocks := get_node_or_null("/root/Unlocks")
	if unlocks == null or not unlocks.has_signal("newly_unlocked"):
		return
	unlocks.newly_unlocked.connect(func(res):
		var nm: String = res.display_name if res != null else "SOMETHING"
		toast("NEW ALMANAC ENTRY — %s" % nm.to_upper(), Color(0.62, 0.92, 1.0), 2.8)
		if _sfx:
			_sfx.play(&"unlock", -3.0))


func _build_fx() -> void:
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 1
	add_child(fx_layer)

	fx_rect = ColorRect.new()
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://shaders/screen_fx.gdshader")
	fx_mat.set_shader_parameter("mode", 0)
	fx_mat.set_shader_parameter("strength", 0.0)
	fx_rect.material = fx_mat
	fx_layer.add_child(fx_rect)


func _label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- top centre: leg + clock ---
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-90, 14)
	top.custom_minimum_size = Vector2(180, 0)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top)
	lbl_timer = _label("3:00", 40, Color.WHITE)
	lbl_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(lbl_timer)
	lbl_leg = _label("", 15, Color(0.8, 0.82, 0.86))
	lbl_leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(lbl_leg)

	# --- top right: chaos ---
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-230, 14)
	tr.custom_minimum_size = Vector2(214, 0)
	tr.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(tr)
	lbl_chaos = _label("CHAOS 0", 30, Color(0.99, 0.82, 0.25))
	lbl_chaos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(lbl_chaos)
	lbl_combo = _label("", 19, Color(1, 0.55, 0.25))
	lbl_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(lbl_combo)

	# --- the toast, centred on the FREE part of the screen ---
	#
	# Not on the viewport centre, which is where it used to be. The objectives
	# panel is 420 px wide at x = 18 (`mission_hud.gd::PANEL_W`) and it lives on
	# CanvasLayer 3, one above this HUD — so anything centred at 640 that is wider
	# than about 400 px slides its own left edge underneath an opaque panel and
	# gets eaten. Every zone banner in the game is wider than that: renders of
	# legs 1, 4, 5 and 7 all show the first word of the arrival title clipped by
	# the panel, and the longest ("LEG 1 — THE RETENTION POND") loses most of a
	# word.
	#
	# The fix is to treat the readable stage as what it actually is — the 810 px
	# between the panel's right edge and the right margin — and centre in that.
	# Chosen over moving the toast down the screen because the panel's HEIGHT is
	# dynamic (six to nine rows depending on the leg) and its width is a constant.
	const TOAST_STAGE_L := 452.0     ## panel right edge (18 + 420) + a gutter
	const TOAST_STAGE_R := 1262.0    ## viewport width - the same 18 px margin
	const TOAST_W := TOAST_STAGE_R - TOAST_STAGE_L
	lbl_toast = _label("", 30, Color.WHITE)
	lbl_toast.set_anchors_preset(Control.PRESET_CENTER)
	lbl_toast.position = Vector2(TOAST_STAGE_L - 640.0, -125)
	lbl_toast.custom_minimum_size = Vector2(TOAST_W, 0)
	lbl_toast.size = Vector2(TOAST_W, 70)
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Long strings used to run off the right edge of the screen.
	lbl_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(lbl_toast)

	# --- bottom left: THE GOOSE BRAIN ---
	brain = BrainPanel.new()
	brain.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	brain.position = Vector2(18, -170)
	brain.custom_minimum_size = Vector2(230, 150)
	brain.size = Vector2(230, 150)
	root.add_child(brain)

	# --- bottom right: stamina + what you're on ---
	stamina_bar = StaminaPanel.new()
	stamina_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamina_bar.position = Vector2(-262, -104)
	stamina_bar.custom_minimum_size = Vector2(244, 44)
	stamina_bar.size = Vector2(244, 44)
	root.add_child(stamina_bar)

	lbl_actives = _label("", 17, Color(0.92, 0.94, 0.98))
	lbl_actives.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl_actives.position = Vector2(-262, -56)
	lbl_actives.custom_minimum_size = Vector2(244, 0)
	lbl_actives.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(lbl_actives)

	# --- bottom centre: the dose sweet-spot arc ---
	dose = DosePanel.new()
	dose.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dose.position = Vector2(-130, -132)
	dose.custom_minimum_size = Vector2(260, 110)
	dose.size = Vector2(260, 110)
	root.add_child(dose)

	# --- controls crib sheet ---
	lbl_state = _label("WASD move · SPACE flap (run up first) · SHIFT dive · H honk · E hold to dose · Q share · R restart",
		13, Color(0.72, 0.75, 0.80))
	lbl_state.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl_state.position = Vector2(18, -26)
	root.add_child(lbl_state)

	# Active substance icons, above the name row.
	icon_row = HBoxContainer.new()
	icon_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	icon_row.position = Vector2(-262, -92)
	icon_row.custom_minimum_size = Vector2(244, 34)
	icon_row.alignment = BoxContainer.ALIGNMENT_END
	icon_row.add_theme_constant_override("separation", 6)
	root.add_child(icon_row)

	Game.chaos_scored.connect(_on_score)
	Subs.combo_started.connect(func(n: String): toast(n, Color(1.0, 0.45, 0.85), 2.2))
	Subs.blackout_started.connect(func(): toast("...", Color(0.6, 0.6, 0.6), 3.0))
	Subs.blackout_ended.connect(func(): toast("WHERE ARE YOU", Color(0.8, 0.8, 0.9), 2.0))
	Subs.substance_taken.connect(func(r: Substance, d: float, res: Dictionary):
		toast(r.display_name.to_upper() + (" — OVERDOSE" if res.overdosed else ""), r.tint, 1.6))


func _on_score(amount: int, total: int, combo: int, label: String) -> void:
	lbl_chaos.text = "CHAOS %d" % total
	lbl_combo.text = ("x%d  +%d %s" % [combo, amount, label]) if combo > 1 else ("+%d %s" % [amount, label])
	if _sfx:
		# Pitch climbs with the combo so a long chain sounds like a long chain.
		var hi: bool = combo >= 5
		_sfx.play(&"score_blip_hi" if hi else &"score_blip", -12.0,
			clampf(1.0 + float(combo - 1) * 0.045, 1.0, 1.9))


## The director sets this per leg; the HUD has no business knowing which zone
## it's looking at.
func set_zone_title(t: String) -> void:
	if lbl_leg:
		lbl_leg.text = t


func toast(msg: String, col: Color, secs: float) -> void:
	lbl_toast.text = msg
	lbl_toast.add_theme_color_override("font_color", col)
	_toast_t = secs


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)

	var t := Game.zone_time_left
	lbl_timer.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	lbl_timer.add_theme_color_override("font_color",
		Color(1, 0.3, 0.3) if t < 20.0 else Color.WHITE)

	if _toast_t > 0.0:
		_toast_t -= real
		if _toast_t <= 0.0:
			lbl_toast.text = ""

	if Game.combo == 0:
		lbl_combo.text = ""

	var names := Subs.active_names()
	lbl_actives.text = " + ".join(names) if not names.is_empty() else ("COMEDOWN" if Subs.in_comedown() else "")
	lbl_actives.add_theme_color_override("font_color",
		Color(0.75, 0.55, 0.95) if Subs.in_comedown() and names.is_empty() else Color(0.92, 0.94, 0.98))

	var m: Dictionary = Subs.mods

	# Benzos: real anterograde amnesia, honestly rendered. The score and clock
	# simply stop existing while you're on it. You'll be fine. Probably.
	var amnesia: bool = m.get("hud_amnesia", false)
	lbl_chaos.visible = not amnesia
	lbl_combo.visible = not amnesia
	lbl_timer.visible = not amnesia

	fx_mat.set_shader_parameter("mode", int(m.fx_mode))
	fx_mat.set_shader_parameter("strength", float(m.fx_strength) * _fx_intensity)
	fx_mat.set_shader_parameter("tint", Subs.primary_tint())

	_sync_icons()

	if brain:
		brain.queue_redraw()
	if dose:
		dose.goose = goose
		dose.queue_redraw()
	if stamina_bar:
		stamina_bar.goose = goose
		stamina_bar.queue_redraw()


## Rebuild the active-substance icon strip only when the set actually changes.
func _sync_icons() -> void:
	if icon_row == null:
		return
	var want: Array[StringName] = []
	for a in Subs.actives:
		want.append(a.res.id)
	if want.size() == icon_row.get_child_count():
		var same := true
		for i in want.size():
			var c := icon_row.get_child(i)
			if StringName(str(c.get_meta("sub_id", ""))) != want[i]:
				same = false
				break
		if same:
			return

	for c in icon_row.get_children():
		c.queue_free()

	var tex := get_node_or_null("/root/Tex")
	for a in Subs.actives:
		var id: StringName = a.res.id
		var holder: Control = null
		var icon: Texture2D = null
		if tex:
			icon = tex.icon_for(id)
		if icon != null:
			var tr := TextureRect.new()
			tr.texture = icon
			tr.custom_minimum_size = Vector2(30, 30)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			holder = tr
		else:
			var cr := ColorRect.new()
			cr.color = a.res.tint
			cr.custom_minimum_size = Vector2(30, 30)
			holder = cr
		holder.set_meta("sub_id", String(id))
		icon_row.add_child(holder)


# ============================================================ inner panels

class BrainPanel extends Control:
	func _draw() -> void:
		var w := size.x
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08, 0.55), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.62, 0.68, 0.5), false, 1.5)
		draw_string(font, Vector2(10, 20), "GOOSE BRAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.78, 0.80, 0.86))

		var keys := ["dopamine", "adrenaline", "gaba", "serotonin"]
		var y := 38.0
		for k in keys:
			var v: float = Subs.brain[k]
			var col: Color = HUD_BRAIN_COLORS[k]
			# label
			draw_string(font, Vector2(10, y + 10), k.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.72, 0.74, 0.80))
			# trough
			var bx := 96.0
			var bw := w - bx - 12.0
			draw_rect(Rect2(bx, y, bw, 12), Color(0, 0, 0, 0.5), true)
			# fluid — wobbles like liquid, because it's supposed to look gross
			var fill := bw * clampf(v, 0.0, 1.0)
			draw_rect(Rect2(bx, y, fill, 12), col, true)
			var wob := sin(Time.get_ticks_msec() * 0.004 + y) * 2.0
			if fill > 3.0:
				draw_rect(Rect2(bx + fill - 3 + wob, y, 3, 12), col.lightened(0.35), true)
			# baseline tick
			var bl := bx + bw * 0.40
			draw_line(Vector2(bl, y - 1), Vector2(bl, y + 13), Color(1, 1, 1, 0.35), 1.0)
			y += 26.0

	const HUD_BRAIN_COLORS := {
		"dopamine": Color(0.98, 0.78, 0.20),
		"adrenaline": Color(0.92, 0.26, 0.24),
		"gaba": Color(0.32, 0.62, 0.95),
		"serotonin": Color(0.38, 0.84, 0.50),
	}


class StaminaPanel extends Control:
	var goose: Goose

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, 12), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.76, 0.78, 0.84))
		var v: float = goose.stamina if goose and is_instance_valid(goose) else 0.0
		draw_rect(Rect2(0, 18, size.x, 14), Color(0, 0, 0, 0.55), true)
		var col := Color(0.42, 0.86, 0.52)
		if v < 0.3:
			col = Color(0.94, 0.32, 0.26)
		elif v < 0.6:
			col = Color(0.96, 0.78, 0.28)
		draw_rect(Rect2(0, 18, size.x * clampf(v, 0.0, 1.0), 14), col, true)
		draw_rect(Rect2(0, 18, size.x, 14), Color(0.7, 0.72, 0.78, 0.6), false, 1.0)

		# Tolerance pips — one per prior dose. Silent, ominous, effective.
		var x := 0.0
		for id in Subs.tolerance:
			var n: int = Subs.tolerance[id]
			for i in mini(n, 8):
				draw_rect(Rect2(x, 36, 5, 5), Color(0.86, 0.42, 0.92, 0.9), true)
				x += 7.0
			x += 8.0


class DosePanel extends Control:
	var goose: Goose

	func _draw() -> void:
		if goose == null or not is_instance_valid(goose):
			return
		var res: Substance = goose.get_eat_substance()
		if res == null:
			return
		var charge: float = goose.get_eat_charge()
		var font := ThemeDB.fallback_font
		var c := Vector2(size.x * 0.5, size.y - 8)
		var r := 62.0
		var a0 := PI          # left
		var a1 := TAU         # right (sweeping over the top)

		# track
		draw_arc(c, r, a0, a1, 48, Color(0, 0, 0, 0.6), 14.0)
		# sweet band
		draw_arc(c, r, lerpf(a0, a1, res.sweet_min), lerpf(a0, a1, res.sweet_max), 24,
			Color(0.35, 0.92, 0.48, 0.85), 14.0)
		# overdose band
		draw_arc(c, r, lerpf(a0, a1, res.sweet_max), a1, 20, Color(0.92, 0.30, 0.26, 0.55), 14.0)
		# needle
		if charge > 0.001:
			var ang := lerpf(a0, a1, clampf(charge, 0.0, 1.0))
			var p := c + Vector2(cos(ang), sin(ang)) * r
			draw_line(c + Vector2(cos(ang), sin(ang)) * (r - 12.0), p + Vector2(cos(ang), sin(ang)) * 6.0,
				Color.WHITE, 3.5)

		var msg := "HOLD [E] — %s" % res.display_name.to_upper()
		if charge > 0.001:
			msg = "RELEASE TO COMMIT"
		draw_string(font, Vector2(0, size.y - 74), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15,
			Color(0.95, 0.96, 1.0))
