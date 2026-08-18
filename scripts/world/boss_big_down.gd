extends Node3D
## BIG DOWN — the leg 7 encounter, and the only boss in this game that is a
## building.
##
## Spec: docs/BOSS_DESIGN.md §2.2, implemented rather than redesigned. Geometry
## comes from scripts/world/prop_models_bigdown.gd; this file is behaviour,
## collision and the clock.
##
## ---------------------------------------------------------------------------
## WHAT IT IS
## ---------------------------------------------------------------------------
## A distribution centre across the interstate from the truck stop, at 3 a.m.,
## in warm rain. At 110 seconds into leg 7 the ground-floor lights come on over
## there and NOTHING SAYS A WORD ABOUT IT. A player who never goes is fine and
## loses nothing mechanical (§2.2.7 guarantee 1).
##
##   PHASE 1  THE FLOOR    a dark warehouse racked to the ceiling with white
##                         bales. No substances, no people, no music. The bales
##                         are the highest-value prop in the game and they burst
##                         into the SAME feather particle the game has spent on
##                         faceplants for six legs. The score stays ON. Nobody
##                         says anything.
##   PHASE 2  THE ATRIUM   four storeys of glass. A HONK SHATTERS A PANE. The
##                         boss is a man in a suit with a briefcase who closes
##                         things and is never caught.
##   PHASE 3  THE WEATHER  break the last curtain wall and it all goes up over
##                         four lanes of I-95.
##   PHASE 4  THE ROOF     fifteen seconds. Rain. Nothing to do.
##
## ---------------------------------------------------------------------------
## THE BOSS
## ---------------------------------------------------------------------------
## He has ONE behaviour and it is subtraction: HE CLOSES THINGS. No health, no
## hit reaction, no stagger, no defeat state, and you never catch him — inside
## 4 m he simply takes the next stair. Every "attack" is a shutter, every
## shutter is telegraphed for 0.9 s by an amber strobe and a servo whine, and
## the only fail state is LOCKED OUT: about eight seconds, and it retracts by
## itself. It never compounds and it can never soft-lock.
##
## He is in group "npc" like every other body in the game, so a honk and a
## catnip-frenzied cat both reach him for free (honk.gd:132-136, cat.gd:229-237)
## — and `startle()` is where the joke lives. He is the one human in this game
## who does not flinch at a goose. He checks the time and walks faster.
##
## ---------------------------------------------------------------------------
## THE THREE THINGS THAT MADE THIS HARD, AND WHAT WAS DONE ABOUT THEM
## ---------------------------------------------------------------------------
##
## 1. "ACROSS THE INTERSTATE" IS OFF THE MAP, AND THE MAP FIGHTS BACK.
##    zone_truckstop.gd's world is 80 x 80 m. The interstate berm IS the south
##    edge (a solid box at z -40.4..-36.4, top y 2.2, zone_truckstop.gd:1370)
##    and behind it is an INVISIBLE WALL at z = -40 spanning y -4..26
##    (zone_truckstop.gd:723-727), and beyond that there is no ground slab at
##    all. Everything south of z = -40 in this game did not exist before this
##    file.
##
##    So this encounter builds its own extension of the world — ground, walls,
##    lighting, a crossing over the berm — and, at the moment the dock opens,
##    it finds the truck stop's -Z map wall by geometry and DISABLES ITS
##    COLLIDER, having first put its own containment around the new ground.
##    See `_open_the_map()`. That is a runtime mutation of a node this file does
##    not own, it is reversible, it is guarded, and it degrades to "the tower is
##    a lit building you can look at but not reach" if the wall is ever moved.
##    The correct fix is one line in zone_truckstop.gd's wall loop and it is
##    reported in the build handoff; this is what works without it.
##
## 2. THE HONK COULD NOT BREAK ANYTHING, ANYWHERE, EVER.
##    honk.gd:129 delivers `dir * 5.5` with a normalised dir, i.e. a force of
##    4.147 into ChaosProp._maybe_score, and the lowest break_force anywhere in
##    the project is 5.0. "Honk shatters glass" has never once crossed its own
##    threshold. And glass CANNOT be a ChaosProp — zone_truckstop.gd:1001-1006
##    states plainly that "a pane of glass modelled as a rigid body falls over
##    the moment the physics starts", which is why the diner's five windows are
##    hidden StaticBody3D + unshaded quad + trigger Area3D.
##
##    Both are true at once, so this file resolves them the only way that needs
##    no edit outside it: the panes stay StaticBody3D exactly like the diner's,
##    and each one carries an `Ear` — a bare Node3D in group **"npc"** with a
##    `startle(from)` method. honk.gd's second group sweep finds it, at the
##    correct radius, with the correct pitch scaling, for free. The Ear does not
##    break the pane itself; it queues an index, and ONE batched break runs on
##    the next physics tick (see §3).
##
##    This is a hack and it is labelled as one. The clean version is a third
##    group sweep in honk.gd over a "glass" group calling `shatter(from)`, which
##    is written out in the handoff. Until then: an Ear is a Node3D that yelps
##    when a goose yells at it, which is what an "npc" is.
##
## 3. MASS SHATTER IS A REAL HAZARD, NOT A THEORETICAL ONE.
##    Juice.burst pools 14 emitters round-robin, Juice.shake ACCUMULATES to a
##    1.20 ceiling (which is the blackout's tier-5 value), Sfx.play_at is
##    unpooled and uncapped, and Game.score bumps the combo on EVERY call. One
##    honk in front of a curtain wall touches six modules; six independent
##    breaks would be six shakes summing past the ceiling, six score calls, and
##    eighteen new AudioStreamPlayer3D nodes in one frame.
##
##    So nothing here breaks itself. Every shatter goes through
##    `_break_panes(list)`, which pays out ONCE for the whole event: one score
##    call, one shake, one burst, one label, one sound. A honk that clears a
##    whole wall is one event, not six — the same argument honk.gd:139 already
##    makes about its own scoring.
##
##    The bales solve it differently and better: their `break_force` is 5.6,
##    which is above the honk's 4.147 and above the goose's 4.2 waddle. You
##    cannot honk a bale open and you cannot walk one open. You have to hit it
##    at speed. So the room's score is paced by how well you are flying, not by
##    how fast you can mash a key, and forty bales can never go off at once.
##
## ---------------------------------------------------------------------------
## HOW IT ATTACHES, AND WHY IT DOES NOT FREE ITSELF
## ---------------------------------------------------------------------------
## Beside the zone, exactly like boss_ranger.gd and hallucinations.gd. One
## guarded line in main.gd::_load_zone; zone_truckstop.gd is not edited and does
## not know this exists.
##
##     BossBigDown.spawn_into(zone, zone.goose, -1.0)
##
## boss_ranger.gd's checklist says a boss must `queue_free()` itself at the end
## of its exit animation. THIS ONE DELIBERATELY DOES NOT, and the reason is the
## whole difference between the two encounters: the Ranger is a truck that
## drives away, and this is forty metres of building with the player standing on
## the roof of it. Freeing the node at the end of the 90 s cap would delete the
## ground under a bird that is mid-glide, in the dark, over a hole in the world
## where the map wall used to be. What ends on the clock is the ENCOUNTER — the
## man, the shutters, the weather. The building stays until main._clear() tears
## the zone down and takes it along, which is exactly what being a child of the
## zone is for.
##
## ---------------------------------------------------------------------------
## HOW IT CANNOT SOFT-LOCK
## ---------------------------------------------------------------------------
##  * Hard 90 s cap above every other exit (BOSS_DESIGN.md §0), enforced in
##    _physics_process before anything else can run.
##  * Every shutter retracts by itself after LOCKOUT_SECS whether or not the
##    player did anything, and each one only ever fires once.
##  * The last stair — top floor to roof — has no shutter and never gets one.
##  * The weather is GUARANTEED: if the player has not broken the last curtain
##    wall by T_WEATHER_FORCE, he backs into it himself. Only the authorship
##    varies (§2.2.7 guarantee 2).
##  * Nothing here ever takes the controls away from the goose. There is no
##    carry, no grab, no stun, and `process_mode` is never written — which is
##    why this file has no counterpart to the Ranger's `abort_carry()` guards.
##  * If the zone clock stops (results card, leg end, restart) the encounter
##    stands down on the same frame and leaves the world standing.

const BD := preload("res://scripts/world/prop_models_bigdown.gd")
const CHAOS_PROP := preload("res://scripts/world/chaos_prop.gd")
const MDEF := preload("res://scripts/core/mission_defs_bigdown.gd")
# human_visual_lowpoly.gd and prop_models_bigdown.gd are also preloaded INSIDE
# the Suit inner class rather than referenced through a file-scope const. Inner
# classes can reach an outer const (`class Bale extends CHAOS_PROP` below proves
# it), but an inline preload is the form that is unambiguously correct in every
# GDScript version this project has ever run on, and this is the one class whose
# construction order has already cost another file a comment (npc_human.gd:50).

signal encounter_started()
## outcome is one of &"done" (the roof beat finished normally), &"expired" (the
## 90 s ceiling) or &"stood_down" (the zone clock stopped under it).
signal encounter_ended(outcome: StringName)

enum Phase { WAITING, FLOOR, ATRIUM, WEATHER, ROOF, DONE }
enum SState { OPEN, TELEGRAPH, CLOSING, SEATED, RETRACT, JAMMED }


# ═══════════════════════════════════════════════════════════════════ THE CLOCK
#
# BOSS_DESIGN.md §2.2.2 wants leg 7 to be 230 s: 110 truck stop, then <=75 in
# the tower, then 15 on the roof. main.gd ships leg 7 at 180 s with a comment
# forbidding 230 until zone_truckstop.gd's DEPART_AT is rewritten, and neither
# file is ours.
#
# So THIS ENCOUNTER DOES NOT ASSUME EITHER NUMBER. It opens the dock when the
# leg has DOCK_OPENS_WITH seconds LEFT rather than after a fixed elapsed time,
# which is the same beat on any clock long enough to hold it: on a 230 s leg
# that is t=112, on a 180 s leg it is t=62. The truck stop's rest beat gets
# shorter on the short clock, which is the correct thing to lose, because the
# encounter's own budget is fixed and the alternative is an encounter that gets
# cut off in the middle of the spectacle.
const DOCK_OPENS_WITH := 118.0
## …but never in the first few seconds, or a 110 s leg (Mission's floor) would
## open the dock during the opening briefing.
const MIN_WAIT := 22.0

## Seconds after the dock opens before he starts up the building whether or not
## the player has come in. Without this he stands in the lobby forever and a
## player who arrives at t=70 finds a static diorama.
const T_ATRIUM_FORCE := 40.0
## The hard guarantee. If the last curtain wall is still standing at this point
## he backs into it. 62 + 10 + 15 = 87, which is inside §0's ceiling of 90 with
## three seconds to spare.
const T_WEATHER_FORCE := 62.0
const WEATHER_SECS := 10.0
const ROOF_SECS := 15.0
## BOSS_DESIGN.md §0. Above every other exit in the file, same as
## boss_ranger.gd:227.
const HARD_CAP := 90.0

## §2.2.7: "A shutter seats before you get through it. You lose the route, you
## take the long way, ~8 seconds. That is the whole penalty." Eight seconds, and
## then it goes back up on its own — because the alternative is a player who did
## not work out the honk standing in front of a steel door for the rest of the
## encounter, which is not a fail state, it is the end of the game.
const LOCKOUT_SECS := 8.0
## The reaction window, per the readability rule in the boss-design literature.
## 0.9 s of amber strobe and servo whine while the player still has a choice.
const TELEGRAPH := 0.9
const SEAT_SECS := 1.15
const RETRACT_SECS := 1.40
## Inside this and he simply takes the next stair. He is never caught, he is
## never hurt, and this is the only thing proximity does.
const CATCH_R := 4.0


# ═════════════════════════════════════════════════════════════════ THE NUMBERS
#
# BALE_POINTS is the single number a human should tune first and it is written
# here rather than buried at a call site for exactly that reason.
#
# 165 makes it the highest-value prop in the game — the current maximum is the
# corn field's scarecrow at 150 — which is BOSS_DESIGN.md §2.2.3 verbatim, and
# the point of it is that leg 7's grade ends up substantially made of goose
# down and the results card reports it in the same typeface as shopping carts.
#
# THE ARITHMETIC, BECAUSE IT MATTERS: a broken ChaosProp scores TWICE
# (chaos_prop.gd:138 and :186, the second at 2x), so a burst bale is 495 points
# before the combo multiplier. Twelve of them is 5,940 against a leg-7 par of
# 10,500 — par is frozen at the leg-6 value (mission.gd:1244), so it does not
# rise to meet this. That is deliberately more than half of par for a room you
# are in for twenty-five seconds, and if a human decides the tower grades every
# run S, this constant and BALE_SPOTS.size() are the two dials. Nobody has ever
# played it, so nobody knows.
const BALE_POINTS := 165
const BALE_MASS := 22.0
## Above the honk's 4.147 (honk.gd:129 -> chaos_prop.gd:115) and above the
## goose's 4.2 m/s waddle (goose_controller.gd:21), below anything that counts
## as flying. You cannot honk one open and you cannot walk one open.
const BALE_BREAK := 5.6

## Per module. Six modules is a whole wall and one honk, i.e. 540 in one event.
const PANE_POINTS := 90
const WEATHER_POINTS := 900
const EARLY_POINTS := 450
const INSIDE_POINTS := 220
const TOP_POINTS := 300
const JAM_POINTS := 260
const LOCKED_POINTS := 140
const ROOF_POINTS := 260
## Break the last wall inside this many seconds of the atrium phase opening and
## the encounter pays a flourish on top. See mission_defs_bigdown.gd's note on
## `made_the_weather` for why the hidden objective is NOT gated on it.
const EARLY_WINDOW := 20.0


# ══════════════════════════════════════════════════════════════════ GEOMETRY
#
# Everything below is WORLD space in zone_truckstop.gd's frame, where the lot is
# x,z in [-40, 40], the ground is y=0 and the interstate berm runs z -40.4..-36.4
# with its top at y=2.2.
#
# The site is a strip 65 m deep hung off the south edge, the same 80 m wide as
# the lot so the containment walls line up with the truck stop's own at x = +/-40
# and there is no corner to fall through.
const SITE_HX := 40.0
const SITE_Z0 := -40.2          ## butts the berm
const SITE_Z1 := -105.0
const BERM_TOP := 2.20

## The service crossing over the berm. A goose can flap 1.86 m and the berm is
## 2.20, so without this the crossing is a flap plus a scramble and a stone-cold
## sober player with no stamina left cannot make it. Two ramps at 25.6 degrees —
## shallower than either of the cottage's two shipped flights — is the whole fix.
##
## x = 2.5 is the widest clear band between the berm's headlight boxes, which sit
## at x = -38 + 3.5i (white) and +1.6 of that (red), zone_truckstop.gd:1375-1380.
## They are unshaded meshes with no collider, so the worst case is a tail light
## reading as a marker on the shoulder, which is what it looks like anyway.
const CROSS_X := 2.5
const CROSS_W := 2.6

## Both buildings are yawed by PI so their -Z faces — which is where every model
## in this project puts its front, its lettering and its lit window — look NORTH,
## back across the interstate at the truck stop. Rotating them is cheaper and
## far less error-prone than mirroring every placement by hand, and it means the
## one lit window at the top of the atrium is the thing you see from the lot.
const YAW := PI

## Warehouse: 40 x 30 x 11, dock face on the north at z = -63.
const WH_AT := Vector3(6.0, 0.0, -78.0)
## Interior floor is at DOCK height, not at grade, because that is what a dock
## IS — a floor level with a trailer bed. BD.DOCK_Y is 1.15 and it is 1.15
## because that is the truck stop's own trailer deck (prop_models_truckstop.gd:581).
const WH_FLOOR_Y := 1.15
const WH_ROOF_Y := 11.0

## Dock apron, in front of the two middle dock doors. Its building face lands
## exactly on the warehouse's dock face.
const APRON_AT := Vector3(6.0, 0.0, -58.7)
const APRON_W := 9.0
const APRON_D := 5.2
const APRON_RUN := 3.4
const APRON_RAMP_W := 2.6

## Atrium: 14 x 12, four storeys of 3.60, roof deck at 14.40. Bolted to the front
## of the warehouse with a 2 m alley between them, its own front flush with the
## dock face at z = -63.
const AT_AT := Vector3(-23.0, 0.0, -69.0)
const AT_FLOORS := 4
const AT_W := 14.0
const AT_D := 12.0

## Six curtain-wall modules per storey on the north face, centred. MODULE is
## 1.72, so this is 10.32 m of glass in a 14 m wall — the corner posts and 1.8 m
## of spandrel each side are what stops it reading as a fish tank.
const PANE_COLS := 6
const PANE_SILL := 0.32

## Twelve bales on the floor, in the warehouse's LOCAL frame (x, z), sitting on
## WH_FLOOR_Y. Laid down the central aisle and the cross-gaps rather than tucked
## between racks: they have to be in the way, because the joke only works if the
## player hits them without meaning to.
const BALE_SPOTS := [
	Vector3(-3.0, 0.0, -11.0), Vector3(1.4, 0.0, -10.2), Vector3(4.2, 0.0, -12.6),
	Vector3(-4.6, 0.0, -6.0), Vector3(0.2, 0.0, -5.2), Vector3(3.8, 0.0, -4.4),
	Vector3(-2.2, 0.0, 0.6), Vector3(2.6, 0.0, 1.4), Vector3(-4.0, 0.0, 4.8),
	Vector3(1.0, 0.0, 6.2), Vector3(4.4, 0.0, 8.0), Vector3(-3.4, 0.0, 10.4),
]

## Six racks, two columns either side of a 10.8 m central aisle that runs from
## the dock doors to the back wall. Local (x, z).
const RACK_SPOTS := [
	Vector3(-9.5, 0.0, -8.0), Vector3(9.5, 0.0, -8.0),
	Vector3(-9.5, 0.0, 0.0), Vector3(9.5, 0.0, 0.0),
	Vector3(-9.5, 0.0, 8.0), Vector3(9.5, 0.0, 8.0),
]
## 8.60 not the library's default 10.40: the roof is at 11.0 and the floor at
## 1.15, so there is 9.85 of clear height and a 10.40 rack goes through the roof.
## 8.60 gives four beam levels at 1.80 / 3.50 / 5.20 / 6.90 above the floor —
## every one of them under one flap from the one below, which is the library
## header's whole argument for the 1.70 pitch.
const RACK_H := 8.60
const RACK_BAYS := 3

## LIGHT BUDGET. docs/ZONE_TRUCKSTOP_NOTES.md §5 records 24 omnis already spent
## against the GL Compatibility 32-light frame cap, i.e. EIGHT of headroom, and
## every emissive surface in the BIG DOWN library is an unshaded mesh that needs
## no light at all. So this encounter spends SIX and leaves two, and every one of
## them goes through `_lamp()` so the number stays countable in one place:
## 3 down the warehouse aisle, 2 over the dock apron, 1 in the atrium lobby.
const LIGHT_BUDGET := 6


# ══════════════════════════════════════════════════════════════════════ STATE
var goose: CharacterBody3D = null
var phase: int = Phase.WAITING

## Seconds from the dock opening. Everything in the encounter is measured off
## this and nothing is measured off the zone clock, which drifts under substance
## slow-motion (Game._process divides by time_scale, the zone's _clock does not).
var _t := 0.0
var _phase_t := 0.0
var _atrium_t := 0.0
var _wait_t := 0.0
## < 0 means "read the real clock". >= 0 is a literal countdown, which is what
## main.gd's probe flag hands us.
var _delay := -1.0
var _ended := false
var _probe := false

var _sfx: Node = null
var _tex: Node = null

## The truck stop's south map wall, borrowed and given back. See _open_the_map().
var _map_wall: StaticBody3D = null
var _map_wall_opened := false

var _suit: Node3D = null
var _weather_author: StringName = &"nobody"
var _entered_floor := false
var _entered_atrium := false
var _reached_top := false
var _roof_scored := false

# ── panes, as parallel typed arrays ────────────────────────────────────────
# Deliberately NOT an array of Dictionaries. zone_truckstop.gd:192-195 explains
# why in its own words: every Dictionary read out of one would need an explicit
# type annotation and this file would otherwise carry forty of them.
var _pane_body: Array[StaticBody3D] = []
var _pane_area: Array[Area3D] = []
var _pane_glass: Array[Node3D] = []
var _pane_ear: Array[Node3D] = []
var _pane_gone: Array[bool] = []
var _pane_floor: Array[int] = []
var _pane_pos: Array[Vector3] = []
## Indices queued by an Ear this frame, drained and paid out as ONE event.
var _pending_glass: Array[int] = []

# ── shutters, same treatment ───────────────────────────────────────────────
var _sh_model: Array[Node3D] = []
var _sh_strobe: Array[MeshInstance3D] = []
var _sh_body: Array[StaticBody3D] = []
var _sh_ear: Array[Node3D] = []
var _sh_state: Array[int] = []
var _sh_t: Array[float] = []
var _sh_shut: Array[float] = []
var _sh_used: Array[bool] = []
## Mirrors the collider state so it is only ever WRITTEN on a transition.
var _sh_solid: Array[bool] = []
var _sh_pos: Array[Vector3] = []

# ── lights that come on when the dock opens ────────────────────────────────
var _dark_nodes: Array[Node3D] = []
var _lamps: Array[OmniLight3D] = []
var _lamp_energy: Array[float] = []
var _lit := 0.0

var _down_up: CPUParticles3D = null
var _down_fall: CPUParticles3D = null

## The echo. Delays and volumes, drained in _tick_echo.
var _echo_t: Array[float] = []
var _echo_db: Array[float] = []

var _cached_mats: Dictionary = {}


# ===========================================================================
# THE INTEGRATION API — this is the whole thing
# ===========================================================================

## Drop BIG DOWN into a running leg 7. Returns the encounter node.
##
##     preload("res://scripts/world/boss_big_down.gd").spawn_into(
##         zone, zone.goose, _big_down_delay)
##
## [param delay] < 0 (the default) means "open the dock when the leg has
## DOCK_OPENS_WITH seconds left", which is the shipping behaviour and the only
## one that survives leg 7 being 180 s today and 230 s later. A value >= 0 is a
## literal countdown and exists for `--probe`, so the encounter can be
## photographed without burning two minutes of wall clock.
##
## Self-`load()` rather than `preload()` because a script cannot preload itself,
## and the resource is in the cache by the time anything can call this.
static func spawn_into(zone: Node, goose_ref: CharacterBody3D, delay := -1.0) -> Node3D:
	var script: GDScript = load("res://scripts/world/boss_big_down.gd")
	# Deliberately untyped, same as boss_ranger.gd:151: a statically-typed Node3D
	# has no `goose` property as far as the analyser is concerned.
	var boss = script.new()
	boss.name = "BossBigDown"
	boss.goose = goose_ref
	boss._delay = delay
	zone.add_child(boss)
	return boss


func _ready() -> void:
	_sfx = get_node_or_null("/root/Sfx")
	_tex = get_node_or_null("/root/Tex")
	_probe = OS.get_cmdline_user_args().has("--probe")
	# A software render runs at about two frames a second, so a probe that had to
	# wait out the real delay — or the real clock, which does not open the dock
	# until the leg has 118 seconds left — could never reach the encounter at
	# all. Under --probe the dock opens at three seconds no matter what the
	# director asked for, which is also what makes this encounter visible to
	# `--probe --loop-test`, the cheapest whole-campaign check in the project.
	# Outside --probe this line does nothing and main.gd keeps the number.
	if _probe and (_delay < 0.0 or _delay > 3.0):
		_delay = 3.0

	# THE BUILDING IS BUILT NOW, DARK, AND NOT AT 110 SECONDS. Four hundred nodes
	# arriving in one frame is a hitch, and the one moment it must not happen is
	# the moment the player is meant to look up and notice something. It also
	# means the silhouette and the one lit window at the top are on the horizon
	# for the whole leg, which is CAMPAIGN_SPEC.md §2.5's Stopover manoeuvre: put
	# the image in the world long before it matters so its arrival is a return.
	_build_site()

	if _probe:
		print("[bigdown] built — %d panes, %d shutters, %d bales, %d lamps"
			% [_pane_body.size(), _sh_model.size(), BALE_SPOTS.size(), _lamps.size()])


func _exit_tree() -> void:
	# Defence in depth. The zone is almost certainly dying with us, but if this
	# node is ever freed on its own the map has to go back the way it was — an
	# open south wall with no ground behind it is a hole a goose falls out of.
	_close_the_map()


# ===========================================================================
# FRAME
# ===========================================================================

func _physics_process(raw_delta: float) -> void:
	# THE ENCOUNTER'S BUDGET IS IN REAL SECONDS, BECAUSE THE LEG'S IS.
	#
	# Every delta Godot hands out is already multiplied by `Engine.time_scale`,
	# and `Game.zone_time_left` divides it back out (game.gd:81) — so the leg
	# clock counts wall-clock seconds. This encounter's clocks did not: they
	# accumulated the raw delta, which made HARD_CAP "90 seconds" mean 90 SCALED
	# seconds. Substances only ever push time_scale DOWN
	# (`substance_manager.gd`'s `minf`), so the drift is one-way: on nitrous at
	# 0.4 the ninety-second cap is two hundred and twenty-five real seconds.
	#
	# On the shipping 180 s leg there is about 31 s of slack and it survives. On
	# a punished one it does not — `main.gd` takes 60 s off leg 7 for landing
	# short before the mission modifier, and `Mission.ZONE_SECONDS_MIN` is 110 —
	# so a player on a slow-motion substance could still be inside the building
	# when the leg ends. BOSS_DESIGN.md §0's cap is a promise about the player's
	# time, and the player's time is not scaled.
	#
	# `raw_delta` stays available for anything that genuinely wants game time;
	# `_tick_cosmetics()` keeps it, because animation should slow with the world.
	var delta := raw_delta / maxf(Engine.time_scale, 0.05)
	if _ended:
		# The encounter is over. The building is not, the weather is not, and the
		# lamps are still humming. Cosmetics only.
		_tick_cosmetics(raw_delta)
		return

	# The zone clock stopping — results card, leg end, a restart — stands the
	# encounter down on the same frame. WAITING is exempt for the reason
	# boss_ranger.gd:207-209 gives: the opening briefing holds zone_running false
	# (main.gd:429-436) and standing down there would kill the encounter before
	# it ever existed.
	if not Game.zone_running:
		if phase != Phase.WAITING:
			_stand_down()
		return

	if phase == Phase.WAITING:
		_tick_waiting(delta)
		return

	_t += delta
	_phase_t += delta
	_tick_cosmetics(raw_delta)

	# Absolute ceiling, above every other exit. BOSS_DESIGN.md §0: no encounter
	# may exceed ninety seconds under any circumstances.
	if _t > HARD_CAP:
		_finish(&"expired")
		return

	_drain_pending_glass()
	_tick_panes()
	_tick_shutters(delta)
	# The Suit is a CharacterBody3D and drives itself from its own
	# _physics_process — there is deliberately no _tick_suit() here. The
	# encounter only ever speaks to him through start_climbing() and
	# back_into_it(), and he only ever speaks back through on_suit_closes().

	match phase:
		Phase.FLOOR:
			_tick_floor()
		Phase.ATRIUM:
			_tick_atrium(delta)
		Phase.WEATHER:
			if _phase_t >= WEATHER_SECS:
				_begin_roof()
		Phase.ROOF:
			_tick_roof()
			if _phase_t >= ROOF_SECS:
				_finish(&"done")


func _tick_waiting(delta: float) -> void:
	_wait_t += delta
	if _delay >= 0.0:
		_delay -= delta
		if _delay <= 0.0:
			_open_the_dock()
		return
	if _wait_t < MIN_WAIT:
		return
	var left: float = Game.zone_time_left
	if left <= DOCK_OPENS_WITH:
		_open_the_dock()


## Everything that keeps running after the encounter has ended: the lights
## coming up, the strobes finishing their blink, the down still falling.
func _tick_cosmetics(delta: float) -> void:
	if _lit < 1.0:
		# Framerate-independent, per the project rule. Never lerp(a, b, 0.1).
		_lit = minf(1.0, _lit + delta * 0.85)
		for i in _lamps.size():
			var l: OmniLight3D = _lamps[i]
			var e: float = _lamp_energy[i]
			if is_instance_valid(l):
				# A cold fluorescent does not fade up smoothly, it stutters. One
				# sine on top of the ramp is the whole effect.
				l.light_energy = e * _lit * (0.82 + 0.18 * sin(_lit * 26.0))
	_tick_echo(delta)


# ===========================================================================
# THE DOCK OPENS — and that is all that happens
# ===========================================================================

## §2.2.2: "The dock opens at 110 s with no announcement. The ground-floor
## lights come on across the interstate. That is all."
##
## There is no toast, no line of dialogue, no objective reveal and no music cue.
## The single most important thing this function does not do is tell you.
func _open_the_dock() -> void:
	phase = Phase.FLOOR
	_t = 0.0
	_phase_t = 0.0

	_open_the_map()
	for n in _dark_nodes:
		if is_instance_valid(n):
			n.visible = true
	_lit = 0.0

	# One distant clunk, forty metres away and eight decibels down: a contactor
	# closing somewhere. `thud_land` at a third of pitch is an honest placeholder
	# — there is no contactor, no servo and no roller shutter anywhere in
	# tools/gen_audio.py's forty sounds, and every one of this encounter's
	# mechanical noises is a substitute that has never been heard by anybody.
	if _sfx:
		_sfx.play_at(&"thud_land", self, -8.0, 0.34)

	_build_suit()
	Mission.note(&"dock_opened")
	encounter_started.emit()


## Borrow the truck stop's south map wall.
##
## zone_truckstop.gd:723-727 builds four invisible walls from one symmetric loop.
## The i==2 wall is a hidden-mesh StaticBody3D at (0, 11, -40) of size
## (80, 30, 1), and it is the only thing between the lot and this encounter. We
## do not own that file, so we find the wall by its geometry — position and box
## size, both exact — and disable its shapes through set_deferred.
##
## THE CONTAINMENT DOES NOT GO AWAY, IT MOVES. `_build_site()` has already put
## our own walls at x = +/-40 and z = -105.5 around the new ground, so at no
## point is there an edge of the world to walk off. _close_the_map() puts the
## original back on the way out.
##
## If the wall is ever moved or removed by a future edit to zone_truckstop.gd
## this finds nothing, says so once under --probe, and the encounter degrades to
## a lit building across an interstate you cannot cross — which is a worse leg 7
## but not a broken one, and the dock was optional anyway.
func _open_the_map() -> void:
	if _map_wall_opened:
		return
	var zone := get_parent()
	if zone == null:
		return
	var want := Vector3(0.0, 11.0, -40.0)
	for c in zone.get_children():
		if not (c is StaticBody3D):
			continue
		var sb: StaticBody3D = c
		if sb.global_position.distance_to(want) > 1.2:
			continue
		for gc in sb.get_children():
			if not (gc is CollisionShape3D):
				continue
			var cs: CollisionShape3D = gc
			if not (cs.shape is BoxShape3D):
				continue
			var bs: BoxShape3D = cs.shape
			# 80 x 30 x 1, allowing for the loop's rot_y of PI.
			if absf(bs.size.y - 30.0) > 0.5 or minf(bs.size.x, bs.size.z) > 1.5:
				continue
			_map_wall = sb
			cs.set_deferred("disabled", true)
			_map_wall_opened = true
	if not _map_wall_opened and _probe:
		print("[bigdown] WARNING — south map wall not found; the tower is unreachable")


func _close_the_map() -> void:
	if not _map_wall_opened:
		return
	_map_wall_opened = false
	if _map_wall == null or not is_instance_valid(_map_wall):
		return
	for gc in _map_wall.get_children():
		if gc is CollisionShape3D:
			gc.set_deferred("disabled", false)


# ===========================================================================
# PHASE 1 — THE FLOOR
# ===========================================================================

## Twenty-five seconds in a dark room full of the best props in the game, and
## the encounter's entire contribution is to notice you came in.
##
## The score stays ON. §2.2.3 considered running the tower unscored, like the
## finale, and rejected it: the horror is that it is business as usual.
func _tick_floor() -> void:
	if goose == null or not is_instance_valid(goose):
		return
	var p := goose.global_position
	if not _entered_floor and _in_warehouse(p):
		_entered_floor = true
		Game.score(INSIDE_POINTS, MDEF.LBL_INSIDE, p + Vector3.UP * 1.2)
		Mission.note(&"entered_floor")
	if _in_atrium(p):
		_begin_atrium()
		return
	if _phase_t >= T_ATRIUM_FORCE:
		_begin_atrium()


func _in_warehouse(p: Vector3) -> bool:
	var l := _to_local(WH_AT, p)
	return absf(l.x) < 19.5 and absf(l.z) < 14.5 and p.y > 0.4 and p.y < WH_ROOF_Y - 0.4


func _in_atrium(p: Vector3) -> bool:
	var l := _to_local(AT_AT, p)
	return absf(l.x) < AT_W * 0.5 - 0.3 and absf(l.z) < AT_D * 0.5 - 0.3 \
		and p.y > -1.0 and p.y < 14.2


func _on_roof(p: Vector3) -> bool:
	var wl := _to_local(WH_AT, p)
	if absf(wl.x) < 19.0 and absf(wl.z) < 14.0 and p.y > WH_ROOF_Y - 0.6 and p.y < WH_ROOF_Y + 3.0:
		return true
	var al := _to_local(AT_AT, p)
	return absf(al.x) < AT_W * 0.5 and absf(al.z) < AT_D * 0.5 \
		and p.y > 14.0 and p.y < 17.0


# ===========================================================================
# PHASE 2 — THE ATRIUM
# ===========================================================================

func _begin_atrium() -> void:
	if phase != Phase.FLOOR:
		return
	phase = Phase.ATRIUM
	_phase_t = 0.0
	_atrium_t = 0.0
	_entered_atrium = true
	Mission.note(&"entered_atrium")
	if _suit != null and is_instance_valid(_suit):
		_suit.call("start_climbing")


func _tick_atrium(delta: float) -> void:
	_atrium_t += delta
	if goose == null or not is_instance_valid(goose):
		return
	if not _reached_top:
		var l := _to_local(AT_AT, goose.global_position)
		if goose.global_position.y > 10.4 and absf(l.x) < 7.4 and absf(l.z) < 6.4:
			_reached_top = true
			Game.score(TOP_POINTS, MDEF.LBL_TOP, goose.global_position + Vector3.UP * 1.0)
			Mission.note(&"reached_top")
	# Belt and braces on authorship. `_break_panes` fires the weather itself the
	# moment the last wall goes, but only if the encounter is already in the
	# atrium phase — and a goose that takes the top storey out from OUTSIDE, in a
	# dive off the warehouse roof, does it while the encounter still thinks it is
	# on the floor. Re-checking here means the ordering cannot cost the player
	# their own spectacle.
	if _last_wall_is_out():
		_make_weather(&"you")
		return
	# §2.2.7 guarantee 2. The spectacle is not optional and it is not the
	# player's to withhold — only theirs to claim.
	if _t >= T_WEATHER_FORCE:
		_suit_backs_into_it()


## Have the remaining top-storey panes gone? Three of six is the threshold: one
## pane is a goose flying through a window, three is a wall coming out, and one
## honk in front of the row takes all six because the row is 10.3 m wide and the
## honk reaches 7.5 m from its middle.
func _last_wall_is_out() -> bool:
	var gone := 0
	for i in _pane_gone.size():
		if _pane_floor[i] == AT_FLOORS - 1 and _pane_gone[i]:
			gone += 1
	return gone >= 3


# ===========================================================================
# PHASE 3 — THE WEATHER
# ===========================================================================

## The reason this encounter exists. Every cubic metre of loose down in a
## four-storey atrium goes up into the night over four lanes of I-95 in the rain
## at three in the morning, and then it is on flight 7.
##
## [param author] is &"you" or &"him". The event is identical either way; only
## the scoring differs, because §2.2.7's whole resolution of spectacle-versus-
## skill is that the building fails whether or not you were any good and only the
## question of who did it varies.
func _make_weather(author: StringName) -> void:
	if phase != Phase.ATRIUM:
		return
	phase = Phase.WEATHER
	_phase_t = 0.0
	_weather_author = author

	# Take whatever is left of the top storey with it, for free and unscored:
	# this is the spectacle, not a payout, and charging the player for the two
	# panes they did not personally break would be the game marking its own work.
	var rest: Array[int] = []
	for i in _pane_gone.size():
		if _pane_floor[i] == AT_FLOORS - 1 and not _pane_gone[i]:
			rest.append(i)
	_clear_panes(rest)

	var at := _to_world(AT_AT, Vector3(0.0, 13.0, -3.0))
	if _down_up:
		_down_up.emitting = true
	# TIER 4. Bigger than a prop break (0.25..0.70) and short of the blackout's
	# tier-5 ceiling of 1.20, because a whole building's worth of glass leaving
	# at once is the largest thing that happens in leg 7 and it is still not the
	# largest thing that happens in the game.
	Juice.shake(0.62)
	Juice.burst(at, BD.C_DOWN, 22, &"feathers")
	if _sfx:
		# Pitch 1.22 on `smash` is this project's existing "this is glass"
		# treatment (zone_truckstop.gd:1797) and it is reused deliberately so the
		# curtain wall and the diner window are audibly the same material.
		_sfx.play_at(&"smash", self, 1.0, 1.18)
		_sfx.play_at(&"crash_heavy", self, -4.0, 0.52)

	if author == &"you":
		Game.score(WEATHER_POINTS, MDEF.LBL_WEATHER, at)
		if _atrium_t <= EARLY_WINDOW:
			# The flourish, and NOT the objective. See mission_defs_bigdown.gd.
			Game.score(EARLY_POINTS, MDEF.LBL_EARLY, at + Vector3.UP * 1.4)
	Mission.note(&"the_weather", {"author": String(author)})


## The guarantee, executed by the only person in the building who did not want
## it to happen. He is not attacking; he is retreating, and he has run out of
## floor. Nobody wins.
func _suit_backs_into_it() -> void:
	if phase != Phase.ATRIUM:
		return
	if _suit != null and is_instance_valid(_suit):
		# TELL HIM WHERE THE WALL IS. He used to be told only to retreat, and
		# retreat meant "walk along your own `basis.z`" — his back. But his last
		# waypoint is the lit window, which sits inboard of the north face, so
		# the final leg of his climb is northward and he arrives FACING the
		# curtain wall. Walking his own back from there took him south, deeper
		# into the top floor, away from the glass.
		#
		# §2.2.7's second guarantee is that if the player never breaks the last
		# wall "he breaks it himself — he backs into it, panicking, and the down
		# goes up anyway". The guarantee fired correctly either way (the line
		# below runs on the same frame regardless), but what rendered was a man
		# strolling backwards away from a storey that was exploding without him.
		# It is the one beat in the encounter that exists purely as a picture.
		_suit.call("back_into_it", _wall_centre())
	_make_weather(&"him")


## Where the curtain wall is, in world space, so the Suit can be sent at it.
## Averaged over the panes the encounter actually built rather than derived from
## the atrium constants a second time — if the wall moves, this moves with it.
func _wall_centre() -> Vector3:
	if _pane_pos.is_empty():
		return global_position
	var c := Vector3.ZERO
	for p in _pane_pos:
		c += p
	return c / float(_pane_pos.size())


# ===========================================================================
# PHASE 4 — THE ROOF
# ===========================================================================

## Fifteen seconds. You, on a roof, in Georgia, in the rain, in the dark, alone,
## with the down coming back down around you. There is nothing to do and there is
## no prompt. Across the interstate is the truck stop, and the pen, and your
## flock, exactly where you left them.
##
## The one thing this phase actively does is take the encounter away: the man is
## gone, every shutter goes up, and the chaos counter stops moving because there
## is nothing left to hit.
func _begin_roof() -> void:
	phase = Phase.ROOF
	_phase_t = 0.0
	if _down_up:
		_down_up.emitting = false
	if _down_fall:
		_down_fall.emitting = true
	if _suit != null and is_instance_valid(_suit):
		_suit.queue_free()
		_suit = null
	for i in _sh_state.size():
		if _sh_state[i] != SState.JAMMED and _sh_state[i] != SState.OPEN:
			_sh_state[i] = SState.RETRACT
			_sh_t[i] = 0.0
	Mission.note(&"on_the_roof")


func _tick_roof() -> void:
	if _roof_scored or goose == null or not is_instance_valid(goose):
		return
	if not goose.is_on_floor():
		return
	if not _on_roof(goose.global_position):
		return
	_roof_scored = true
	# The only score in the phase, and it is for standing still.
	Game.score(ROOF_POINTS, MDEF.LBL_RAIN, goose.global_position + Vector3.UP * 1.2)


# ===========================================================================
# ENDINGS
# ===========================================================================

## The encounter ends. THE BUILDING DOES NOT — see the header. Nothing is freed
## here except the man, and he was going to leave anyway.
func _finish(outcome: StringName) -> void:
	if _ended:
		return
	_ended = true
	phase = Phase.DONE
	if _suit != null and is_instance_valid(_suit):
		_suit.queue_free()
		_suit = null
	for i in _sh_state.size():
		_shutter_open_now(i)
	Mission.note(&"bigdown_ended", {"outcome": String(outcome),
		"author": String(_weather_author)})
	encounter_ended.emit(outcome)


## The not-a-story-beat exit: the zone clock stopped under us. Same as _finish
## but silent, and it does not emit an outcome anybody would want to read.
func _stand_down() -> void:
	if _ended:
		return
	_ended = true
	phase = Phase.DONE
	if _suit != null and is_instance_valid(_suit):
		_suit.queue_free()
		_suit = null
	if _down_up:
		_down_up.emitting = false
	encounter_ended.emit(&"stood_down")


# ===========================================================================
# GLASS
# ===========================================================================

## An Ear reporting a honk. It does NOT break anything: it queues an index, and
## the whole frame's worth is paid out as one event on the next physics tick.
## That is the entire mass-shatter mitigation and it is why this indirection
## exists at all.
func on_honk_hit(kind: StringName, index: int, _from: Vector3) -> void:
	if _ended:
		return
	if kind == &"pane":
		if index >= 0 and index < _pane_gone.size() and not _pane_gone[index]:
			if not _pending_glass.has(index):
				_pending_glass.append(index)
		return
	if kind == &"shutter":
		_jam_shutter(index)


func _drain_pending_glass() -> void:
	if _pending_glass.is_empty():
		return
	var batch := _pending_glass.duplicate()
	_pending_glass.clear()
	_break_panes(batch, true)


## The other way in: a goose at speed. Straight out of zone_truckstop.gd's
## _tick_panes (1759-1772), including the 4.0 m/s floor — below that you are
## bouncing off a window, which is the correct outcome and also funnier.
func _tick_panes() -> void:
	if goose == null or not is_instance_valid(goose):
		return
	if goose.velocity.length() < 4.0:
		return
	var hits: Array[int] = []
	for i in _pane_area.size():
		if _pane_gone[i]:
			continue
		var a: Area3D = _pane_area[i]
		if is_instance_valid(a) and a.overlaps_body(goose):
			hits.append(i)
	if not hits.is_empty():
		_break_panes(hits, false)


## ONE event, ONE payout, however many modules went. See the header, §3.
func _break_panes(list: Array[int], by_honk: bool) -> void:
	var live := _clear_panes(list)
	if live.is_empty():
		return
	var n := live.size()
	var centre := Vector3.ZERO
	for i in live:
		centre += _pane_pos[i]
	centre /= float(n)

	# One score call, so the combo advances by one and the objective advances by
	# n. Game.score() bumps `combo` on EVERY call (game.gd:117) and there is no
	# API to award without doing so, which is exactly why this is batched.
	Game.score(PANE_POINTS * n, MDEF.LBL_PANE, centre)
	# ...AND ONE NOTE PER PANE, because the objective counts EVENTS, not points.
	#
	# The line above used to carry a comment claiming "the objective advances by
	# n". It does not. `mission.gd:784` is `st["prog"] = min(tgt, st.prog + 1.0)`
	# — a label event advances a counter by exactly ONE no matter how large its
	# `amount` is. So the batching that makes a six-module honk read as one event
	# (one combo bump, one hitstop, one popup — all correct, and all the reason it
	# is batched) also made `glazier` advance by one, and a player who demolished
	# two entire storeys with a single honk watched the row sit at 1 of 10.
	#
	# `Mission.note()` dispatches into the same counter without touching chaos,
	# the combo or Juice, so the score stays batched and the count stays honest.
	# `glazier`'s condition matches this event rather than the label.
	if Mission != null:
		for _i in n:
			Mission.note(&"pane_broken")
	# THE SEVENTH HITSTOP SITE IN THE GAME, and juice.gd:95-98 says if you are
	# adding a sixth you are almost certainly wrong. The argument for this one:
	# it is the payoff of the only mechanical promise the design document has
	# left outstanding for eight months, it fires at most six or seven times in
	# the whole encounter because a pane can only break once, requests do not
	# queue (juice.gd:290, longest wins) so a six-module honk is one freeze, and
	# it is set BELOW the prop break's 0.07 @ 0.8 rather than above it. If a
	# human decides the game freezes too much, this is the first line to delete
	# and the encounter survives it.
	Juice.hitstop(0.05, 0.7)
	# Additive and clamped at 1.20 (juice.gd:353-356), so the size here has to be
	# the size of the whole event and not of one pane. Six panes at
	# zone_truckstop.gd's per-pane 0.35 would sum to 2.1 and spend the entire
	# shake budget — the blackout's value — on one honk.
	Juice.shake(clampf(0.20 + 0.05 * float(n), 0.20, 0.52))
	Juice.burst(centre, Color(0.90, 0.94, 1.00), mini(10 + 2 * n, 24), &"debris")
	Juice.floating_text(centre + Vector3.UP * 1.1, "%s!!" % MDEF.LBL_PANE,
		Color(1.0, 0.86, 0.32))
	if _sfx:
		_sfx.play_at(&"smash", self, 0.0, 1.22)
		if n > 2:
			_sfx.play_at(&"crash_light", self, -5.0, 0.86)
	# THE OLD WHOLE-EVENT NOTE USED TO BE HERE AND IT WAS NEVER DELETED, so every
	# shatter emitted n + 1 matching `pane_broken` events: n from the loop above,
	# plus this one. `glazier` asks for ten panes on leg 7 and was completing on
	# five single-pane fly-throughs, or nine panes taken in honk batches, paying
	# its 240 × 1.6 = 384 at roughly half the intended work. Nobody saw the row
	# tick because `mission_hud.gd` caps BONUS rows at two and glazier is appended
	# behind the truck stop's five — the counter was wrong AND invisible.
	#
	# Deleted rather than renamed: nothing reads the `{n, honk}` payload. If a
	# whole-event hook is wanted later it must NOT reuse this event name.

	if phase == Phase.ATRIUM and _last_wall_is_out():
		_make_weather(&"you")


## Take panes out of the world without paying for them. Returns the ones that
## were actually still there, so the caller can price the event correctly.
##
## The FRAME STAYS. A mullion standing in an empty opening is not an oversight,
## it is what a broken curtain wall looks like, and it is also how the building's
## state stays legible from thirty metres — which is §2.2.4's whole argument for
## this encounter having no health bar.
func _clear_panes(list: Array[int]) -> Array[int]:
	var live: Array[int] = []
	for idx in list:
		var i: int = idx
		if i < 0 or i >= _pane_gone.size() or _pane_gone[i]:
			continue
		_pane_gone[i] = true
		live.append(i)
		var g: Node3D = _pane_glass[i]
		if is_instance_valid(g):
			g.visible = false
		var b: StaticBody3D = _pane_body[i]
		if is_instance_valid(b):
			for c in b.get_children():
				if c is CollisionShape3D:
					c.set_deferred("disabled", true)
		var e: Node3D = _pane_ear[i]
		if is_instance_valid(e):
			# Out of the group or honk.gd keeps counting a hole in a wall toward
			# the honk score, and cat.gd could still pounce it.
			e.remove_from_group("npc")
			e.set("dead", true)
		var a: Area3D = _pane_area[i]
		if is_instance_valid(a):
			a.set_deferred("monitoring", false)
	return live


# ===========================================================================
# SHUTTERS — the only thing he does, and the only thing that moves
# ===========================================================================

## Called by the Suit the instant he arrives on the floor above. He presses
## something on a wall; the shutter is below him and behind you.
func on_suit_closes(i: int) -> void:
	if i < 0 or i >= _sh_state.size():
		return
	if _sh_used[i] or _sh_state[i] != SState.OPEN:
		return
	_sh_used[i] = true
	_sh_state[i] = SState.TELEGRAPH
	_sh_t[i] = 0.0
	if _sfx:
		# The servo whine. There is no servo in tools/gen_audio.py — `hiss` at
		# pitch 2.1 is the same substitute the truck stop makes for its air
		# brakes (zone_truckstop.gd, pitch 1.55) and it has never been heard.
		_sfx.play_at(&"hiss", self, -6.0, 2.10)
	Mission.note(&"shutter_closing", {"i": i})


## The counter, and the whole reason the telegraph is 0.9 s long. A honk while
## the strobe is running — or while the curtain is still coming down — jams it
## permanently. This is the encounter's only skill check and it is the payoff of
## an eight-month joke button.
func _jam_shutter(i: int) -> void:
	if i < 0 or i >= _sh_state.size():
		return
	var st: int = _sh_state[i]
	if st != SState.TELEGRAPH and st != SState.CLOSING:
		return
	# JAMMED is a transient, not a resting place. `_tick_shutters` runs the
	# curtain back up and then parks the shutter in OPEN — and when the jam lands
	# during the TELEGRAPH, before the curtain has moved at all, that happens on
	# the very next physics tick. Both paths are correct and both are permanent,
	# because `_sh_used[i]` is already true and on_suit_closes() refuses a used
	# shutter. The state you observe afterwards is OPEN, not JAMMED; the thing
	# that makes it a jam is that it never closes again.
	_sh_state[i] = SState.JAMMED
	_sh_t[i] = 0.0
	Game.score(JAM_POINTS, MDEF.LBL_JAMMED, _sh_pos[i] + Vector3.UP * 1.6)
	Juice.shake(0.22)
	Juice.burst(_sh_pos[i] + Vector3.UP * 1.4, Color(0.96, 0.78, 0.28), 10, &"sparkle")
	if _sfx:
		_sfx.play_at(&"crash_light", self, -3.0, 1.32)
	Mission.note(&"shutter_jammed", {"i": i})


func _tick_shutters(delta: float) -> void:
	for i in _sh_state.size():
		var m: Node3D = _sh_model[i]
		if not is_instance_valid(m):
			continue
		_sh_t[i] += delta
		var st: int = _sh_state[i]
		var strobe: MeshInstance3D = _sh_strobe[i]
		match st:
			SState.TELEGRAPH:
				if is_instance_valid(strobe):
					strobe.visible = fmod(_sh_t[i], 0.20) < 0.10
				if _sh_t[i] >= TELEGRAPH:
					_sh_state[i] = SState.CLOSING
					_sh_t[i] = 0.0
			SState.CLOSING:
				if is_instance_valid(strobe):
					strobe.visible = fmod(_sh_t[i], 0.20) < 0.10
				_sh_shut[i] = clampf(_sh_t[i] / SEAT_SECS, 0.0, 1.0)
				BD.shutter_set_closed(m, _sh_shut[i])
				# The collider arrives a third of the way down rather than at
				# the end. A goose that dives under a curtain already past its
				# own head and comes out the other side has beaten a shutter
				# that was, visually, in the way — and the player will remember
				# the picture, not the trigger volume.
				_shutter_solid(i, _sh_shut[i] > 0.34)
				if _sh_shut[i] >= 1.0:
					_sh_state[i] = SState.SEATED
					_sh_t[i] = 0.0
					if is_instance_valid(strobe):
						strobe.visible = false
					if _sfx:
						_sfx.play_at(&"thud_land", self, -4.0, 0.62)
					_on_locked_out(i)
			SState.SEATED:
				if _sh_t[i] >= LOCKOUT_SECS:
					_sh_state[i] = SState.RETRACT
					_sh_t[i] = 0.0
					if _sfx:
						_sfx.play_at(&"hiss", self, -9.0, 1.85)
			SState.RETRACT:
				_sh_shut[i] = clampf(1.0 - _sh_t[i] / RETRACT_SECS, 0.0, 1.0)
				BD.shutter_set_closed(m, _sh_shut[i])
				_shutter_solid(i, _sh_shut[i] > 0.34)
				if _sh_shut[i] <= 0.0:
					_shutter_open_now(i)
			SState.JAMMED:
				# It comes back up faster than it went down - a honk kicks the
				# curtain out of its guides and the counterweight does the rest -
				# and then it stops being a state machine at all. `_sh_used[i]` is
				# already true, so OPEN here is TERMINAL: on_suit_closes() refuses
				# a used shutter and _jam_shutter() only accepts TELEGRAPH or
				# CLOSING. He does not get to try that one again.
				#
				# Landing in OPEN rather than sitting in JAMMED forever also stops
				# this branch re-driving eighteen slat visibilities and a deferred
				# collider write on every frame for the rest of the leg.
				_sh_shut[i] = maxf(0.0, _sh_shut[i] - delta * 2.4)
				BD.shutter_set_closed(m, _sh_shut[i])
				_shutter_solid(i, false)
				if is_instance_valid(strobe):
					strobe.visible = false
				if _sh_shut[i] <= 0.0:
					_shutter_open_now(i)


## Fires once per shutter, at the moment it seats. The fail state pays, because
## it is bounded at eight seconds and because a punishment that small is a beat
## rather than a penalty. mission_defs_bigdown.gd's `locked_out` argues it.
func _on_locked_out(i: int) -> void:
	if goose == null or not is_instance_valid(goose):
		return
	if goose.global_position.distance_to(_sh_pos[i]) > 9.0:
		return
	Game.score(LOCKED_POINTS, MDEF.LBL_LOCKED, _sh_pos[i] + Vector3.UP * 1.8)
	Juice.floating_text(_sh_pos[i] + Vector3.UP * 2.4, "LOCKED OUT",
		Color(0.96, 0.72, 0.30))
	Mission.note(&"locked_out", {"i": i})


## CollisionShape3D.disabled must always go through set_deferred - but a
## shutter spends seventy frames closing, and writing the same value seventy
## times queues seventy call_deferreds for one state change.
func _shutter_solid(i: int, on: bool) -> void:
	if i < 0 or i >= _sh_solid.size() or _sh_solid[i] == on:
		return
	_sh_solid[i] = on
	var b: StaticBody3D = _sh_body[i]
	if not is_instance_valid(b):
		return
	for c in b.get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", not on)


func _shutter_open_now(i: int) -> void:
	if i < 0 or i >= _sh_state.size():
		return
	_sh_state[i] = SState.OPEN
	_sh_shut[i] = 0.0
	var m: Node3D = _sh_model[i]
	if is_instance_valid(m):
		BD.shutter_set_closed(m, 0.0)
	var strobe: MeshInstance3D = _sh_strobe[i]
	if is_instance_valid(strobe):
		strobe.visible = false
	_shutter_solid(i, false)


# ===========================================================================
# THE MAN
# ===========================================================================

func _build_suit() -> void:
	if _suit != null and is_instance_valid(_suit):
		return
	var s := Suit.new()
	s.boss_ref = self
	s.goose_ref = goose
	_suit_route(s)
	add_child(s)
	# In the lobby, on the far side of the glass you are about to come through,
	# doing nothing. He has been standing there since the lights came on.
	s.global_position = _to_world(AT_AT, Vector3(2.2, 0.0, -4.4))
	_suit = s


## Three flights and a window. He never takes the last stair, so the roof is
## yours alone — which is Phase 4's entire premise and it costs one waypoint.
##
## THE FIRST WAYPOINT IS NOT DECORATION AND IT COST A RUN TO FIND. The stair is a
## switchback across the void at local x = 2.0, and the lobby is at the -Z end of
## the atrium while flight 0's FOOT is at the +Z end. Routed straight between
## them he walks along the same x band as flight 0 and meets the UNDERSIDE of his
## own staircase: the soffit is 0.62 m off the floor two metres short of the foot,
## and a 1.7 m capsule stops there and stands in it for the entire encounter.
## Measured, not reasoned — the runtime probe watched him sit at y=0.00 for sixty
## seconds. So he crosses to the +Z strip at x = 0, which is clear of the ramp's
## 1.6 m width, and only then steps sideways onto the foot.
##
## The same geometry applies to the player, and there it is fine: the goose is a
## 1.10 m capsule, the clearance at mid-flight is 1.46 m, and walking beside a
## staircase rather than under it is not a puzzle.
func _suit_route(s: Suit) -> void:
	var out: Array[Vector3] = []
	var shut: Array[int] = []
	var flights := _flights()
	if not flights.is_empty():
		var f0: Dictionary = flights[0]
		var fa: Vector3 = f0["a"]
		out.append(_to_world(AT_AT, Vector3(0.0, 0.0, fa.z + signf(fa.z) * 1.6)))
		shut.append(-1)
	for f in mini(flights.size(), AT_FLOORS - 1):
		var e: Dictionary = flights[f]
		var a: Vector3 = e["a"]
		var b: Vector3 = e["b"]
		# Onto the landing SLAB rather than at its lip: the flight ends at
		# |z| = 3.0, which is the exact edge of the void, and a man aiming
		# for a point on a cliff edge walks off it about a third of the time.
		if f > 0:
			out.append(_to_world(AT_AT, Vector3(0.0, a.y, a.z + signf(a.z) * 1.2)))
			shut.append(-1)
		out.append(_to_world(AT_AT, a))
		shut.append(-1)
		# Arriving at the HEAD of flight f means he is on the floor above and the
		# shutter at that flight's foot comes down behind him.
		out.append(_to_world(AT_AT, b))
		shut.append(f)
	# The lit window at the top of the -Z face, which has been the only lit thing
	# on the skyline since leg 6. `_atrium_parts` puts it at x = MODULE * 1.5.
	out.append(_to_world(AT_AT, Vector3(BD.MODULE * 1.5,
		float(AT_FLOORS - 1) * BD.AT_FLOOR, -AT_D * 0.5 + 1.3)))
	shut.append(-1)
	s.route = out
	s.route_shutter = shut


# ===========================================================================
# THE ECHO — the only thing in this building that answers
# ===========================================================================

## §2.2.6: "In the atrium, if the player honks — and they will, constantly,
## because it is the verb the room is made of — NOTHING ANSWERS. Same cue, same
## code path, no reply. Twenty minutes later, on the 18th green, the player
## honks and forty geese honk back."
##
## The flock is not here. It is not even data here — it is a hundred metres north
## in a pen, and this encounter deliberately builds no pen of its own, so
## `gg_share` has no target and a honk gets no reply.
##
## What it gets instead is itself, twice, off forty metres of concrete and
## corrugated steel. That is not a reply and it is not meant to console anybody:
## it is the sound of a room being empty, and it costs four lines and two
## AudioStreamPlayer3Ds.
##
## `_input`, not `_unhandled_input`, and it NEVER marks the event handled —
## goose_controller.gd:652 has to still get it or the goose does not honk at all.
## flock_pen.gd:350 and zone_finale.gd:1200 both state this rule.
func _input(e: InputEvent) -> void:
	if _ended or goose == null or not is_instance_valid(goose):
		return
	if not e.is_action_pressed("gg_honk"):
		return
	var p := goose.global_position
	if p.z > SITE_Z0:
		return
	var indoors := _in_warehouse(p) or _in_atrium(p)
	if not indoors:
		return
	_echo_t.append(0.26)
	_echo_db.append(-13.0)
	_echo_t.append(0.53)
	_echo_db.append(-20.0)


func _tick_echo(delta: float) -> void:
	if _echo_t.is_empty():
		return
	var i := _echo_t.size() - 1
	while i >= 0:
		_echo_t[i] -= delta
		if _echo_t[i] <= 0.0:
			if _sfx:
				_sfx.play_at(&"honk_a", self, _echo_db[i], 0.98)
			_echo_t.remove_at(i)
			_echo_db.remove_at(i)
		i -= 1


# ===========================================================================
# THE SUIT — an inner class, because he is eighty lines and no geometry
# ===========================================================================

class Suit extends CharacterBody3D:
	## He runs up four flights of stairs holding a briefcase, in a suit, in
	## Georgia, in August, and he is losing to a bird. He has no health, no hit
	## reaction and no defeat state, and the encounter never lets you catch him.

	## Slower than the goose's 4.2 m/s waddle on purpose — he is not fleeing, he
	## is leaving, and a man who visibly outran you would be a chase.
	const WALK := 1.95
	## And this is what happens when you get close: exactly enough to stay ahead
	## and not one metre more.
	const TROT := 4.55
	const GRAV := 22.0
	## Long enough to read the strobe from a floor below, short enough that he is
	## gone by the time you reach the landing.
	const HOLD := 2.40
	const ARRIVE := 1.05

	var boss_ref: Node = null
	var goose_ref: CharacterBody3D = null
	var route: Array[Vector3] = []
	## Parallel to `route`: the shutter index to close on arriving at that
	## waypoint, or -1. Parallel arrays rather than an array of Dictionaries for
	## the reason zone_truckstop.gd:192-195 gives — every read out of a Dictionary
	## is a Variant and needs an explicit annotation.
	var route_shutter: Array[int] = []

	var _step := -1
	var _hold := 0.0
	var _trot := 0.0
	var _climbing := false
	var _leaving := false
	## Direction he retreats along once the wall is coming down. Set by
	## back_into_it(); zero means "use his own back", the old behaviour.
	var _leave_dir := Vector3.ZERO
	var _lp: Node3D = null
	var _arm_r: Node3D = null
	var _forearm_r: Node3D = null
	var _sfx: Node = null

	func _ready() -> void:
		_sfx = get_node_or_null("/root/Sfx")
		# CHECKLIST: every boss body joins "npc" even when it should ignore a
		# honk, because staying out of the group loses the cat interaction too
		# (boss_ranger.gd:1225-1231 makes the same argument for the dog).
		add_to_group("npc")

		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.30
		cap.height = 1.70
		cs.shape = cap
		cs.position.y = 0.85
		add_child(cs)
		floor_max_angle = deg_to_rad(50.0)
		floor_snap_length = 0.5

		# NO y OFFSET. human_visual_lowpoly.gd:59 fixed HIP_Y at the source and
		# boss_ranger.gd:884-886 records that the old 0.066 compensator now lifts
		# a body six centimetres off the floor instead of settling it.
		var lp := preload("res://scripts/world/human_visual_lowpoly.gd").new()
		lp.name = "VisLP"
		# setup() BEFORE add_child(), per npc_human.gd:50-58 — the other order
		# builds the whole eight-mesh body twice.
		# A WARM charcoal, not a cool one, and the reason is three lines of
		# somebody else's file. human_visual_lowpoly.gd:129-130 picks the hair
		# colour deterministically from the SHIRT'S HUE:
		#   HAIR_COLOURS[int(shirt.h * 5) % 5]
		# and a blue-grey suit (h = 0.63) indexes 3, which is AUBURN. The first
		# render of this encounter produced a bright ginger man in a black
		# t-shirt, which is a character, and he is not supposed to be one - he is
		# a man in a suit with no face beyond the faceted default. Nudging the
		# suit warm puts h at 0.08, which indexes 0, near-black brown. It costs
		# nothing and it is invisible at this ambient.
		lp.setup(Color(0.150, 0.145, 0.140), Color(0.112, 0.108, 0.104),
			Color(0.84, 0.68, 0.57))
		add_child(lp)
		_lp = lp
		_arm_r = lp.arm_r
		if _arm_r != null:
			_forearm_r = _arm_r.get_node_or_null("Forearm")

		# He keeps it. If it ever leaves his hand that is a joke somebody else
		# gets to write.
		var hand: Node3D = _forearm_r if _forearm_r != null else self
		var holder := Node3D.new()
		holder.name = "Case"
		hand.add_child(holder)
		holder.position = Vector3(0.0, -0.64, 0.02) if _forearm_r != null \
			else Vector3(0.34, 0.62, 0.0)
		preload("res://scripts/world/prop_models_bigdown.gd").build(&"briefcase", holder, {})

	## THE JOKE. Every other human in this game yelps, pops and runs
	## (npc_human.gd:107-134). He is a man who has been told about the geese.
	##
	## He does not flinch, he does not drop anything, he does not turn round, and
	## there is no floating text. He stops waiting and starts walking, which
	## means honking at him COSTS you the shutter you were about to jam — the one
	## interaction in the encounter where the honk is the wrong answer.
	##
	## The signature and the group membership are the shared contract with
	## npc_human.gd:107, so honk.gd:132-136 and cat.gd:229-237 both reach this
	## for free and neither needed a line.
	func startle(_from: Vector3) -> void:
		if _leaving:
			return
		_hold = 0.0
		_trot = maxf(_trot, 1.30)

	func start_climbing() -> void:
		if _climbing or _leaving:
			return
		_climbing = true
		_step = 0

	## The guarantee. He has run out of floor.
	## [param wall_at] is where the curtain wall is. He walks AT it, backwards.
	func back_into_it(wall_at := Vector3.INF) -> void:
		_leaving = true
		_climbing = false
		_hold = 0.0
		velocity = Vector3.ZERO
		_leave_dir = Vector3.ZERO
		if wall_at.is_finite():
			var to := wall_at - global_position
			to.y = 0.0
			if to.length() > 0.05:
				_leave_dir = to.normalized()
				# Face AWAY from where he is going. That is what makes it read as
				# backing into something rather than walking into it: the model
				# faces -Z, so pointing his forward at the opposite of the travel
				# direction puts his back on the glass.
				rotation.y = atan2(_leave_dir.x, _leave_dir.z)

	func _physics_process(delta: float) -> void:
		_trot = maxf(0.0, _trot - delta)
		var dir := Vector3.ZERO
		var speed := WALK

		if _climbing and _step >= 0 and _step < route.size():
			var target: Vector3 = route[_step]
			var to := target - global_position
			to.y = 0.0
			# Inside four metres he simply takes the next stair. No stagger, no
			# reaction, no acknowledgement that you are there.
			if goose_ref != null and is_instance_valid(goose_ref):
				if global_position.distance_to(goose_ref.global_position) < 4.0:
					_hold = 0.0
					_trot = maxf(_trot, 0.8)
			if _hold > 0.0:
				_hold -= delta
			elif to.length() < ARRIVE:
				_advance()
			else:
				dir = to.normalized()
				if _trot > 0.0:
					speed = TROT
		elif _leaving:
			# Backwards, into the glass, at a walk. He is not running at it, and
			# he is not looking at it.
			#
			# The direction comes from `back_into_it()`, which was handed the
			# wall's position. It used to be `global_transform.basis.z` — his own
			# back — on the assumption that he was facing the goose with the
			# glass behind him. He is not: his last waypoint is the lit window,
			# 1.33 m inboard of the north face, so he arrives facing the wall and
			# his back pointed at the middle of the building. `basis.z` is kept
			# only as the fallback for a call that supplies no wall.
			dir = _leave_dir
			if dir.length() < 0.01:
				dir = global_transform.basis.z
				dir.y = 0.0
				dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
			speed = WALK * 0.72

		velocity.x = move_toward(velocity.x, dir.x * speed, 26.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, 26.0 * delta)
		velocity.y -= GRAV * delta
		if is_on_floor() and velocity.y < 0.0:
			velocity.y = -0.6
		move_and_slide()

		if dir.length() > 0.05 and not _leaving:
			# -basis.z is FORWARD. Every model in this project faces -Z.
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z),
				clampf(7.5 * delta, 0.0, 1.0))
		if _lp != null and is_instance_valid(_lp):
			var flat := Vector2(velocity.x, velocity.z).length()
			_lp.animate(delta, clampf(flat / TROT, 0.0, 1.0), 0.0)
			_carry_pose(delta)

	## Applied AFTER animate() has run the walk cycle over the same joints, the
	## same way boss_ranger.gd:1055-1070 hangs a clipboard on a walking man. A
	## briefcase does not swing; it hangs, and the arm holding it is the stillest
	## thing on him.
	func _carry_pose(delta: float) -> void:
		if _arm_r == null or not is_instance_valid(_arm_r):
			return
		var k := 1.0 - pow(0.01, delta)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -0.06, k)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.10, k)
		if _forearm_r != null and is_instance_valid(_forearm_r):
			_forearm_r.rotation.x = lerpf(_forearm_r.rotation.x, -0.10, k)

	func _advance() -> void:
		var sh := -1
		if _step >= 0 and _step < route_shutter.size():
			sh = route_shutter[_step]
		if sh >= 0 and boss_ref != null and is_instance_valid(boss_ref):
			boss_ref.call("on_suit_closes", sh)
			_hold = HOLD
		_step += 1
		if _step >= route.size():
			_step = maxi(0, route.size() - 1)
			_climbing = false


# ===========================================================================
# EAR — a Node3D that yelps when a goose yells at it
# ===========================================================================

class Ear extends Node3D:
	## The honk hook, and the only reason a honk can break glass in this project.
	##
	## honk.gd::_shove sweeps exactly two groups — "chaos_prop" and "npc" — and
	## calls `startle(global_position)` on anything in the second that has the
	## method. Glass cannot be a chaos_prop (a rigid pane topples the instant
	## physics starts, zone_truckstop.gd:1001-1006), so it is an "npc": a Node3D
	## that reacts to being honked at. It has no body, no collider and no
	## behaviour beyond forwarding.
	##
	## This is a hack standing in for a third group sweep in honk.gd. It gets the
	## radius, the pitch scaling and the distance test right for free, which the
	## alternative — reimplementing honk.gd's geometry in here — would not.

	var boss_ref: Node = null
	var kind: StringName = &"pane"
	var index := 0
	var dead := false

	func startle(from: Vector3) -> void:
		if dead or boss_ref == null or not is_instance_valid(boss_ref):
			return
		boss_ref.call("on_honk_hit", kind, index, from)


# ===========================================================================
# BALE — a ChaosProp that bursts into six legs of faceplants
# ===========================================================================

class Bale extends CHAOS_PROP:
	## ChaosProp._break() throws a `&"debris"` burst in the prop's own colour
	## (chaos_prop.gd:182). That is the right default for a shopping cart and it
	## is the wrong one for this, which has to burst into `&"feathers"` —
	## Color(0.94, 0.94, 0.92), the exact preset the game has been spending on
	## faceplants, wire strikes and WAYNE IS DOWN for six legs (juice.gd:134).
	##
	## THE EQUIVALENCE IS THE ENTIRE SATIRE and it is delivered by a particle
	## system that shipped months ago. So the override adds the feathers and lets
	## the base class do everything else, unchanged: the chunks, the hitstop, the
	## shake, the doubled score, the debris bodies.
	##
	## Nothing says a word about it. Not the objective, not a toast, not the
	## floating text — which reads "DOWN BALE!!" in gold, in the same typeface as
	## a shopping cart, because that is what the results card is going to call it
	## too.

	var boss_ref: Node = null

	func _break() -> void:
		if not _broken:
			Juice.burst(global_position + Vector3.UP * 0.3,
				preload("res://scripts/world/prop_models_bigdown.gd").C_DOWN,
				20, &"feathers")
			if boss_ref != null and is_instance_valid(boss_ref):
				boss_ref.call("on_bale_broken", global_position)
		super()


func on_bale_broken(_at: Vector3) -> void:
	Mission.note(&"bale_broken")


# ===========================================================================
# BUILD — everything below here is geometry and runs once
# ===========================================================================

func _build_site() -> void:
	_ground()
	_crossing()
	_warehouse()
	_atrium()
	_yard()
	_weather_emitters()


# ── the ground, and the containment that replaces the truck stop's ─────────

func _ground() -> void:
	var cz := (SITE_Z0 + SITE_Z1) * 0.5
	var dz := SITE_Z0 - SITE_Z1
	# Collision: one hidden slab. Its mesh is never drawn, so the eight-lights-
	# per-MeshInstance3D rule does not apply to it.
	_hide_meshes(_static_box(Vector3(0.0, -0.5, cz),
		Vector3(SITE_HX * 2.0, 1.0, dz), BD.C_ASPHALT))
	# Visual: TILED, and it is not cosmetic. GL Compatibility lights ONE
	# MeshInstance3D with at most eight lights and the chosen eight change as
	# things move, so a sixty-five-metre apron as a single mesh flickers.
	# zone_truckstop.gd:382-387 learned this in the cottage.
	_flat_tiles(Vector3(0.0, -0.02, cz), Vector3(SITE_HX * 2.0, 0.06, dz), 6, 5,
		&"asphalt", BD.C_ASPHALT, 4.5)

	# CONTAINMENT. The truck stop's south wall is about to be switched off, so
	# these go up first: same x as its own east and west walls so the corner
	# lines up and there is no seam to walk through, and the same y span
	# (-4..26) because nothing in this game contains a goose above 26 m and the
	# atrium tops out at 15.6.
	_hide_meshes(_static_box(Vector3(0.0, 11.0, SITE_Z1 - 0.5),
		Vector3(SITE_HX * 2.0, 30.0, 1.0), Color(1, 1, 1)))
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_hide_meshes(_static_box(Vector3(xs * SITE_HX, 11.0, cz),
			Vector3(1.0, 30.0, dz), Color(1, 1, 1)))


## Two ramps over the interstate berm, and they are the difference between an
## encounter and a locked door. The berm's top is 2.20 m and one flap is 1.86 m,
## so a goose that has spent leg 7 on the rigs cannot get over it under its own
## power — and BOSS_DESIGN.md's whole structure has the truck stop's rest beat
## running FIRST, which means the player arrives here tired by design.
func _crossing() -> void:
	var col := Color(0.245, 0.245, 0.250)
	_ramp(Vector3(CROSS_X, 0.0, -32.0), Vector3(CROSS_X, BERM_TOP, -36.6),
		CROSS_W, 0.5, col)
	_ramp(Vector3(CROSS_X, BERM_TOP, -40.2), Vector3(CROSS_X, 0.0, -44.8),
		CROSS_W, 0.5, col)
	# The visible half. The ramp colliders above are hidden (that is what _ramp
	# does), so these are what the player actually reads as "you can go here":
	# two pale slabs and four hazard posts on a black berm at three in the
	# morning. If the crossing is not legible the encounter does not exist.
	for pair in [[-32.0, -36.6], [-40.2, -44.8]]:
		var e: Array = pair
		var z0: float = e[0]
		var z1: float = e[1]
		var a := Vector3(CROSS_X, 0.0 if z0 < -39.0 else 0.0, z0)
		var b := Vector3(CROSS_X, 0.0, z1)
		var mid := (a + b) * 0.5
		mid.y = BERM_TOP * 0.5
		var run := absf(z1 - z0)
		var mi := _decal_box(mid, Vector3(CROSS_W, 0.06, sqrt(run * run + BERM_TOP * BERM_TOP)),
			Color(0.34, 0.34, 0.33))
		mi.rotation.x = atan2(BERM_TOP, run) * (1.0 if z0 > z1 else -1.0)
	for i in 4:
		var zz := -33.0 - float(i) * 4.0
		for sx in [-1.0, 1.0]:
			var xs: float = sx
			_glow_box(Vector3(CROSS_X + xs * (CROSS_W * 0.5 + 0.18), 0.9, zz),
				Vector3(0.10, 0.30, 0.10), Color(0.98, 0.66, 0.16))


# ── the warehouse ─────────────────────────────────────────────────────────

func _wh_params() -> Dictionary:
	return {
		"width": 40.0, "depth": 30.0, "height": WH_ROOF_Y,
		"doors": 4, "door_w": BD.DOOR_W, "door_h": BD.DOOR_H,
		"dock_y": WH_FLOOR_Y, "door_pitch": BD.DOOR_PITCH,
		# THE ROOF IS NOT DAYLIGHT STEEL. `trim_colour` is what the library uses
		# for the roof deck (prop_models_bigdown.gd:1312), and BD.C_STEEL is 0.42
		# grey — which on an UPWARD-facing surface under the truck stop's 0.44
		# ambient reads pale, and the first render of leg 7's roof beat is a
		# bright grey plane at three in the morning in the rain.
		#
		# 0.18 sits just above the wall skin (C_DARK, 0.145) and just above the
		# wet asphalt (C_ASPHALT, 0.130), which keeps the zone's stated
		# readability rule: everything you can see is visible because it is
		# BRIGHTER THAN THE GROUND, not because anything is lit. The library
		# lightens the corrugation ribs by 0.06 and 0.16 on top of this, so the
		# roof still reads as ribbed metal rather than as a slab.
		"colour": BD.C_DARK, "trim_colour": Color(0.180, 0.190, 0.205),
	}


func _warehouse() -> void:
	var params := _wh_params()
	_model_at(&"warehouse_shell", WH_AT, YAW, params)
	_place_colliders(&"warehouse_shell", params, WH_AT)

	# THE FLOOR IS AT DOCK HEIGHT. `_warehouse_boxes` gives walls from grade up,
	# but a warehouse floor is level with a trailer bed or the dock doors open
	# onto a 1.15 m drop, which is exactly the kind of thing that is invisible
	# in code and obvious the first time anybody walks in.
	_hide_meshes(_static_box(Vector3(WH_AT.x, WH_FLOOR_Y - 0.3, WH_AT.z),
		Vector3(39.4, 0.6, 29.4), BD.C_CONCRETE))
	_flat_tiles(Vector3(WH_AT.x, WH_FLOOR_Y - 0.02, WH_AT.z),
		Vector3(39.4, 0.06, 29.4), 6, 5, &"concrete", BD.C_CONCRETE, 3.0)

	_racking()
	_bales()

	# Dock doors, on the outside of the -Z wall. NEVER pass a size to this kind —
	# the library header says it is anchored on a wall plane and is not centred
	# in Z, and a rescale would drag the seal through the wall.
	var doors := 4
	for i in doors:
		var lx := -BD.DOOR_PITCH * float(doors - 1) * 0.5 + BD.DOOR_PITCH * float(i)
		var at := _to_world(WH_AT, Vector3(lx, 0.0, -15.0))
		_model_at(&"dock_door", at, YAW, {
			"width": BD.DOOR_W, "height": BD.DOOR_H, "dock_y": WH_FLOOR_Y,
			"text": "%d" % (i + 1), "lit": true, "glow_colour": BD.C_SODIUM})

	# One shutter, seated, on the far bay. Pure scenery and it does not move: it
	# is the building telling you what it does before the man does it to you.
	var far := _to_world(WH_AT, Vector3(-BD.DOOR_PITCH * 1.5, WH_FLOOR_Y, -15.35))
	_model_at(&"roller_shutter", far, YAW,
		{"width": 3.10, "height": BD.DOOR_H, "closed": 1.0, "colour": BD.C_STEEL})
	_hide_meshes(_static_box(far + Vector3(0.0, BD.DOOR_H * 0.5, 0.0),
		Vector3(3.3, BD.DOOR_H, 0.3), Color(1, 1, 1)))

	# The one object in the room that is text. It says a fill power and a lot
	# code and nothing else, at goose height, facing the doors.
	_model_at(&"fill_power_sign", _to_world(WH_AT, Vector3(0.0, WH_FLOOR_Y, -12.4)),
		YAW, {"text": "FILL 850", "code": "LOT 4471-B", "lit": true})

	_wh_lights()


## Six racks in a MultiMeshInstance3D, because at the library's defaults one rack
## is 2,784 triangles and six as separate MeshInstance3Ds is a draw call each.
## zone_corn.gd:620-663 is the pattern. A LIT rack cannot be instanced — a
## MultiMesh has one mesh and one material and the strip light lives on the glow
## shell — so the light comes from separate `aisle_light` models instead.
func _racking() -> void:
	var params := {"bays": RACK_BAYS, "height": RACK_H, "lit": false, "stock": true,
		"colour": Color(0.52, 0.26, 0.11), "trim_colour": Color(0.17, 0.30, 0.42)}
	var mesh := BD.mesh_for(&"racking", params)
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = RACK_SPOTS.size()
	mmi.multimesh = mm
	mmi.material_override = BD.shared_material()
	# Explicit, because a MultiMesh's automatic bounds are the single mesh's and
	# the whole block would pop out of frame at the wrong angle.
	mmi.custom_aabb = AABB(Vector3(-17.0, 0.0, -11.0), Vector3(34.0, 12.0, 22.0))
	add_child(mmi)
	mmi.global_position = WH_AT
	mmi.rotation.y = YAW
	for i in RACK_SPOTS.size():
		var s: Vector3 = RACK_SPOTS[i]
		mm.set_instance_transform(i, Transform3D(Basis(),
			Vector3(s.x, WH_FLOOR_Y, s.z)))

	# Perch decks. `collider_boxes` returns one thin slab per beam level, in the
	# model's own local frame, and the mesh builder reads the same array — so the
	# thing the goose lands on and the thing it can see cannot drift apart.
	for i in RACK_SPOTS.size():
		var s2: Vector3 = RACK_SPOTS[i]
		for entry in BD.collider_boxes(&"racking", params):
			var e: Dictionary = entry
			var c: Vector3 = e["c"]
			var sz: Vector3 = e["s"]
			_hide_meshes(_static_box(
				_to_world(WH_AT, Vector3(s2.x + c.x, WH_FLOOR_Y + c.y, s2.z + c.z)),
				sz, Color(1, 1, 1), YAW))

	# HANG THEM ON THE ROOF STEEL, not 1.1 m below it.
	#
	# `aisle_light` is base-anchored on its LENS and its stem runs 1.40 m UP from
	# there to a ceiling plate — the library header says so. These were placed at
	# local y = 7.4, which puts the plate top at 8.80, while the lowest roof
	# member the shell builds is the truss bottom chord at `height - 1.05` with
	# half 0.055, i.e. 9.895. So five fixtures hung in mid-air with a 1.1 m gap
	# above them — and once the dock opens they light up and become the brightest
	# things in an 11 m dark room, which is the worst possible place for a
	# floating prop. Same class as the geese on an awning and the dog buried to
	# its knees that HANDOFF §7 says renders have already caught.
	#
	# Derived rather than typed: if the warehouse gets taller, the lights follow.
	const LIGHT_STEM := 1.40      ## lens -> ceiling plate top, from the library
	const CHORD_DROP := 1.05      ## roof steel below the shell height
	var hang_y := WH_ROOF_Y - CHORD_DROP - LIGHT_STEM
	for i in 5:
		var lz := -10.0 + float(i) * 5.0
		var m := _model_at(&"aisle_light",
			_to_world(WH_AT, Vector3(0.0, hang_y, lz)), YAW,
			{"lit": true, "glow_colour": BD.C_CANOPY})
		_darken(m)


func _bales() -> void:
	for i in BALE_SPOTS.size():
		var s: Vector3 = BALE_SPOTS[i]
		var size := Vector3(1.20, 0.90, 0.90)
		var p := Bale.new()
		p.boss_ref = self
		add_child(p)
		# ChaosProp.setup() only resolves models against prop_models.gd
		# (chaos_prop.gd:21), so anything from this library is built here and the
		# graybox hidden. `_visual` MUST be repointed or _break() hides the
		# invisible box and leaves an intact bale standing in its own debris —
		# zone_truckstop.gd:421-431 shipped exactly that bug once.
		p.setup(size, BD.C_DOWN, BALE_MASS, BALE_POINTS, MDEF.LBL_BALE)
		_hide_meshes(p)
		var m: Node3D = BD.build(&"down_bale", p, {
			"size": size, "colour": BD.C_DOWN,
			# Stencils cost two extra MeshInstance3Ds each. Four of twelve carry
			# them — enough that the player can read one, cheap enough that the
			# room does not.
			"stencil": i % 3 == 0,
			"text": "850 FILL", "code": "LOT %d" % (4471 + i),
			"variant": float(i) * 1.7})
		m.position.y = -size.y * 0.5
		p._visual = m
		p.break_force = BALE_BREAK
		p.global_position = _to_world(WH_AT, Vector3(s.x, WH_FLOOR_Y + size.y * 0.5, s.z))
		p.rotation.y = randf_range(-PI, PI)


func _wh_lights() -> void:
	for i in 3:
		var lz := -9.0 + float(i) * 9.0
		_lamp(_to_world(WH_AT, Vector3(0.0, 7.6, lz)), BD.C_CANOPY, 3.6, 17.0)


# ── the atrium ────────────────────────────────────────────────────────────

func _at_params() -> Dictionary:
	return {
		"width": AT_W, "depth": AT_D, "floors": AT_FLOORS,
		"floor_h": BD.AT_FLOOR, "void_w": BD.AT_VOID_W, "void_d": BD.AT_VOID_D,
		"stair_w": BD.STAIR_W,
		"colour": Color(0.16, 0.18, 0.21), "trim_colour": Color(0.245, 0.245, 0.255),
		"glow_colour": BD.C_CANOPY,
	}


## THE LIBRARY'S STAIR CANNOT BE WALKED, AND THIS IS THE ARITHMETIC.
##
## `BD.climb_ramps(&"atrium_shell")` returns a landing-free scissor stair: every
## flight runs in the SAME 1.6 m wide column at local x = 2.0, alternating
## direction, and consecutive flights meet at a single point on the slab edge.
## So flight f+1 hangs directly over flight f, and the gap between them closes as
## you approach the landing.
##
##   flight below, surface:   Y - m*d          m = fh / (2*hvd) = 3.6/6 = 0.6
##   flight above, underside: Y + m*d - t      t = ramp thickness, 0.34
##   clearance:               2*m*d - t = 1.2*d - 0.34
##
## A 1.10 m goose needs 1.15 m and therefore stops 1.24 m short of every landing.
## A 1.70 m man needs 1.75 and stops 1.74 m short. THE RUNTIME PROBE MEASURED
## EXACTLY THAT: the Suit walked up flight 0 and parked at local z = -1.17, which
## is 1.83 m from the head, and stood there for thirty seconds. The boss could
## not climb his own building.
##
## The unusable fraction is `(H + t) / (2 * fh)` and it does not depend on the
## void size, the stair width or the pitch — only on the storey height, which
## the design fixes at 3.60 m and which the library header is emphatic must not
## move. So no parameter fixes this. A landing-free scissor stair simply does not
## fit inside a 3.6 m storey.
##
## THE FIX, and it is what a real switchback stair does: put the odd flights on
## the OTHER side of the void, at local x = -2.0. Four metres of lateral
## separation means no flight is ever above another, the landing between them is
## the slab strip at |z| in [3, 6] which is already solid, and the pitch, the
## width and every endpoint stay exactly where the library put them.
##
## The cost is that the library draws its tread geometry for ALL four flights at
## x = +2.0, so the odd ones leave a set of treads with nothing under them. Two
## answers, both applied: this file builds real visible treads on the mirrored
## flights, and every flight that is actually walkable gets a nosing light. The
## lit stair is the real stair. Reported to the library owner as a defect in
## `_atrium_flights` rather than worked around silently.
func _flights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw := BD.climb_ramps(&"atrium_shell", _at_params())
	for f in raw.size():
		var e: Dictionary = raw[f]
		var a: Vector3 = e["a"]
		var b: Vector3 = e["b"]
		var w: float = e["w"]
		var mir := f % 2 == 1
		if mir:
			a.x = -a.x
			b.x = -b.x
		out.append({"a": a, "b": b, "w": w, "mirrored": mir})
	return out


func _atrium() -> void:
	var params := _at_params()
	var model := _model_at(&"atrium_shell", AT_AT, YAW, params)
	_place_colliders(&"atrium_shell", params, AT_AT)

	# THE FLOOR LIGHTS ARE THE ANNOUNCEMENT. Dark until the dock opens; the one
	# lit window at the top is NOT, because it has been the only lit thing on the
	# skyline since leg 6 and switching it off would undo twenty minutes of setup.
	if model != null:
		var banks := model.get_node_or_null("FloorLights")
		if banks is Node3D:
			var b3: Node3D = banks
			b3.visible = false
			_dark_nodes.append(b3)

	# THE STAIRS ARE NOT DECORATION. The treads in the shell mesh are 0.18 m
	# risers and the goose is a CharacterBody3D with floor_snap_length 0.4 and no
	# step-up code (goose_controller.gd:126, 152). Without these ramp colliders
	# it walks into the first riser of every flight and stops there for the rest
	# of the encounter. zone_cottage.gd:877-923 ships the same trick and calls it
	# "a ramp collider with step decals".
	for entry in _flights():
		var e: Dictionary = entry
		var a: Vector3 = e["a"]
		var b: Vector3 = e["b"]
		var w: float = e["w"]
		_ramp(_to_world(AT_AT, a), _to_world(AT_AT, b), w, 0.34, Color(1, 1, 1))
		if bool(e["mirrored"]):
			_stair_treads(a, b, w)
		_stair_lights(a, b, w)

	_curtain_wall()
	_atrium_shutters()
	_lamp(_to_world(AT_AT, Vector3(0.0, 3.1, 0.0)), BD.C_CANOPY, 2.4, 13.0)


## Six breakable modules per storey on the NORTH face — the one the truck stop
## can see and the one the down leaves through — and a single sealed sheet on the
## other three. Four storeys of six is twenty-four panes; four storeys of all
## four faces would be a hundred and twelve, which is a hundred and twelve
## StaticBody3Ds, a hundred and twelve Area3Ds and a hundred and twelve models
## against a zone that already carries eight hundred and twenty-six meshes.
##
## Built exactly like the diner's five windows (zone_truckstop.gd:1007-1034):
## hidden-mesh StaticBody3D + the library's frame-and-quad model + a shallow
## trigger Area3D, tracked in parallel arrays and polled from _physics_process.
## Plus an Ear, which is the honk half.
func _curtain_wall() -> void:
	var half := float(PANE_COLS - 1) * 0.5
	for f in AT_FLOORS:
		var fy := float(f) * BD.AT_FLOOR
		for c in PANE_COLS:
			var px := (float(c) - half) * BD.MODULE
			var base := Vector3(px, fy + PANE_SILL, -AT_D * 0.5 - 0.03)
			var at := _to_world(AT_AT, base)
			var centre := at + Vector3(0.0, BD.PANE_H * 0.5 + BD.MULLION, 0.0)

			var m := _model_at(&"glass_pane", at, YAW, {
				"pane_w": BD.PANE_W, "pane_h": BD.PANE_H, "frame": BD.MULLION,
				"colour": BD.C_GLASS, "trim_colour": Color(0.15, 0.17, 0.20)})
			var glass: Node3D = null
			if m != null:
				glass = m.get_node_or_null("Glass")

			var body := _static_box(centre, Vector3(BD.MODULE, BD.PANE_H + 0.12, 0.14),
				Color(1, 1, 1), YAW)
			_hide_meshes(body)

			var area := Area3D.new()
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(BD.PANE_W, BD.PANE_H, 1.10)
			cs.shape = bs
			area.add_child(cs)
			area.monitoring = true
			area.monitorable = false
			add_child(area)
			area.global_position = centre

			var ear := Ear.new()
			ear.boss_ref = self
			ear.kind = &"pane"
			ear.index = _pane_body.size()
			add_child(ear)
			ear.global_position = centre
			ear.add_to_group("npc")

			_pane_body.append(body)
			_pane_area.append(area)
			_pane_glass.append(glass)
			_pane_ear.append(ear)
			_pane_gone.append(false)
			_pane_floor.append(f)
			_pane_pos.append(centre)

		# Spandrel bands, above and below the glass, so the wall reads as a
		# building rather than as a row of floating rectangles.
		_decal_box(_to_world(AT_AT, Vector3(0.0, fy + 0.16, -AT_D * 0.5 - 0.05)),
			Vector3(12.6, 0.32, 0.10), Color(0.13, 0.14, 0.17), YAW)
		_decal_box(_to_world(AT_AT, Vector3(0.0, fy + 3.22, -AT_D * 0.5 - 0.05)),
			Vector3(12.6, 0.76, 0.10), Color(0.13, 0.14, 0.17), YAW)

	# The other three faces: one sealed sheet each, full height, non-breakable.
	# You come in through the north wall or you do not come in.
	var top := float(AT_FLOORS) * BD.AT_FLOOR
	_sealed_glass(Vector3(0.0, top * 0.5, AT_D * 0.5 + 0.03), Vector3(13.6, top, 0.06))
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_sealed_glass(Vector3(xs * (AT_W * 0.5 + 0.03), top * 0.5, 0.0),
			Vector3(0.06, top, 11.6))


## Visible treads for a mirrored flight, because the library only drew them for
## the column it thought the stair was in. One sloped soffit and twelve nosings:
## the ramp collider underneath is the real walking surface and always was —
## zone_cottage.gd:877-923 calls this exact pattern "a ramp collider with step
## decals" and it is the only thing in this project that makes a stair walkable.
func _stair_treads(a: Vector3, b: Vector3, w: float) -> void:
	var d := b - a
	var run := absf(d.z)
	if run < 0.1:
		return
	var ang := atan2(d.y, run) * (-1.0 if d.z < 0.0 else 1.0)
	var mid := _to_world(AT_AT, (a + b) * 0.5)
	var length := sqrt(run * run + d.y * d.y)

	var soffit := _decal_box(mid + Vector3(0.0, -0.20, 0.0),
		Vector3(w + 0.10, 0.20, length), Color(0.225, 0.228, 0.240), YAW)
	soffit.basis = Basis(Vector3.UP, YAW) * Basis(Vector3.RIGHT, ang)

	var steps := 12
	for i in steps:
		var t := float(i + 1) / float(steps)
		var p := _to_world(AT_AT, a.lerp(b, t))
		var going := d.z / float(steps)
		var riser := d.y / float(steps)
		_decal_box(p + Vector3(0.0, 0.030, going * 0.5),
			Vector3(w, 0.055, absf(going) * 0.88), Color(0.30, 0.30, 0.31), YAW)
		_decal_box(p + Vector3(0.0, 0.030 - riser * 0.5, 0.0),
			Vector3(w, riser, 0.045), Color(0.20, 0.20, 0.215), YAW)


## Nosing lights up every flight that is actually walkable. They are the only lit
## thing inside the void, they come on with the dock like everything else, and
## they are the answer to the library's orphaned tread geometry: THE LIT STAIR IS
## THE REAL STAIR, and a player never has to be told that in words.
func _stair_lights(a: Vector3, b: Vector3, w: float) -> void:
	for i in 5:
		var t := (float(i) + 0.5) / 5.0
		var p := _to_world(AT_AT, a.lerp(b, t))
		_glow_box(p + Vector3(0.0, 0.04, 0.0), Vector3(w * 0.86, 0.03, 0.05),
			Color(0.86, 0.92, 1.00), YAW)


func _sealed_glass(local_centre: Vector3, size: Vector3) -> void:
	var at := _to_world(AT_AT, local_centre)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _glass_mat()
	add_child(mi)
	mi.global_position = at
	mi.rotation.y = YAW
	var body := _static_box(at, Vector3(maxf(size.x, 0.16), size.y, maxf(size.z, 0.16)),
		Color(1, 1, 1), YAW)
	_hide_meshes(body)


## Three, at the feet of the first three flights. The LAST flight — top floor to
## roof — never gets one, which is the structural reason this encounter cannot
## lock a player out of its own ending.
func _atrium_shutters() -> void:
	var flights := _flights()
	for f in mini(flights.size(), AT_FLOORS - 1):
		var e: Dictionary = flights[f]
		var a: Vector3 = e["a"]
		# 0.30 outboard of the flight's foot, so it seats on solid slab rather
		# than over the void.
		var lz: float = a.z + (0.30 if a.z > 0.0 else -0.30)
		var at := _to_world(AT_AT, Vector3(a.x, a.y, lz))
		var m := _model_at(&"roller_shutter", at, YAW, {
			"width": 2.20, "height": 2.60, "closed": 0.0,
			"colour": BD.C_STEEL, "glow_colour": BD.C_SODIUM})

		var body := _static_box(at + Vector3(0.0, 1.30, 0.0),
			Vector3(2.40, 2.60, 0.32), Color(1, 1, 1), YAW)
		_hide_meshes(body)
		for c in body.get_children():
			if c is CollisionShape3D:
				c.set_deferred("disabled", true)

		var ear := Ear.new()
		ear.boss_ref = self
		ear.kind = &"shutter"
		ear.index = _sh_model.size()
		add_child(ear)
		ear.global_position = at + Vector3(0.0, 1.30, 0.0)
		ear.add_to_group("npc")

		_sh_model.append(m)
		_sh_strobe.append(BD.shutter_strobe(m))
		_sh_body.append(body)
		_sh_ear.append(ear)
		_sh_state.append(SState.OPEN)
		_sh_t.append(0.0)
		_sh_shut.append(0.0)
		_sh_used.append(false)
		_sh_solid.append(false)
		_sh_pos.append(at)


# ── the yard, the apron, and one building on the horizon ──────────────────

func _yard() -> void:
	var params := {"width": APRON_W, "depth": APRON_D, "dock_y": WH_FLOOR_Y,
		"ramp_run": APRON_RUN, "ramp_w": APRON_RAMP_W, "lit": true,
		"colour": BD.C_CONCRETE, "glow_colour": BD.C_SODIUM}
	_model_at(&"dock_apron", APRON_AT, YAW, params)
	_place_colliders(&"dock_apron", params, APRON_AT)
	for entry in BD.climb_ramps(&"dock_apron", params):
		var e: Dictionary = entry
		var a: Vector3 = e["a"]
		var b: Vector3 = e["b"]
		var w: float = e["w"]
		_ramp(_to_world(APRON_AT, a), _to_world(APRON_AT, b), w, 0.34, Color(1, 1, 1))

	# Two lamps over the dock, and these are the thing that comes on at 110 s.
	# From the truck stop they are two orange smudges appearing on the far side
	# of the interstate, at the bottom of a building that has been on the skyline
	# since leg 6. Nothing points at them.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_lamp(Vector3(WH_AT.x + xs * 8.0, 6.4, -60.5), BD.C_SODIUM, 3.4, 22.0)

	# The reveal, and it costs one prop: the trailers in the truck stop's lot are
	# BIG DOWN trailers, and this is the same mark on the building. The player has
	# been climbing on it for a hundred seconds. (The trailer half is one call at
	# zone_truckstop.gd:1296 and is reported in the handoff — this file cannot
	# reach into that zone's rig array.)
	var mark := Node3D.new()
	add_child(mark)
	BD.company_decal(mark, _to_world(WH_AT, Vector3(0.0, 8.6, -15.06)),
		Vector3(0.0, 0.0, 1.0), Vector3.UP, 1.30,
		Color(0.90, 0.90, 0.86), false, 0.05)

	# One more of these, on the horizon, never approached and with no collider.
	# CAMPAIGN_SPEC.md §2.5: there is always more of this than you thought.
	_model_at(&"lit_skyline_box", Vector3(27.0, 0.0, -128.0), YAW,
		{"width": 18.0, "height": 22.0, "depth": 15.0, "lit": true})


func _weather_emitters() -> void:
	# CPUParticles3D, NOT GPUParticles3D. BOSS_DESIGN.md:570 says "one
	# GPUParticles3D emitter" and it is wrong about this project: the game ships
	# on the GL Compatibility renderer and every particle system in it is a
	# CPUParticles3D for that reason (zone_truckstop.gd:1550-1553,
	# docs/JUICE_NOTES.md:122). And it must not be Juice.burst either — that is a
	# round-robin pool of fourteen emitters and a ten-second continuous state
	# would starve every impact in the encounter.
	_down_up = _make_down(300, 7.0, Vector3(9.0, 1.0, 7.0),
		Vector3(0.0, 1.0, 0.55), 7.0, 13.0, Vector3(0.5, -1.4, 3.2))
	_down_up.global_position = _to_world(AT_AT, Vector3(0.0, 12.0, -2.0))
	_down_up.emitting = false

	# Phase 4. Wider, slower, and coming back down over the whole site, because
	# what goes up over an interstate in warm rain does not stay up.
	_down_fall = _make_down(200, 9.0, Vector3(30.0, 1.0, 26.0),
		Vector3(0.05, -1.0, 0.12), 0.6, 1.8, Vector3(0.35, -0.9, 0.6))
	_down_fall.global_position = Vector3(-6.0, 26.0, -72.0)
	_down_fall.emitting = false


func _make_down(amount: int, life: float, box: Vector3, dir: Vector3,
		v0: float, v1: float, grav: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	add_child(p)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.085, 0.020, 0.115)
	p.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(BD.C_DOWN.r, BD.C_DOWN.g, BD.C_DOWN.b, 0.86)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	p.amount = amount
	p.lifetime = life
	# So the particles stay where they were emitted instead of riding the node.
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = dir
	p.spread = 48.0
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = grav
	p.damping_min = 1.4
	p.damping_max = 3.0
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	return p


# ===========================================================================
# HELPERS — local copies on purpose
#
# zone_truckstop.gd has all of these and they are all private methods that
# add_child onto the ZONE. Calling them across the boundary would scatter this
# encounter's four hundred nodes through a file we do not own and break the one
# guarantee the header makes: everything BIG DOWN builds is a child of BIG DOWN,
# so freeing this node frees the site and nothing else has to know.
# ===========================================================================

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _surf(key: StringName, uv_scale: float, fallback: Color, rough := 0.9) -> StandardMaterial3D:
	if _tex != null:
		var m: StandardMaterial3D = _tex.surface(key, uv_scale, rough, fallback)
		if m != null:
			return m
	return _mat(fallback, rough)


## Unshaded, alpha, cull disabled, depth-draw opaque only — the same treatment
## BD.glass_material() gives its own panes, but with a flat albedo, because a
## BoxMesh carries no vertex colours and the library's material reads its colour
## out of them.
func _glass_mat() -> StandardMaterial3D:
	if _cached_mats.has("glass"):
		var cached: StandardMaterial3D = _cached_mats["glass"]
		return cached
	var m := StandardMaterial3D.new()
	m.albedo_color = BD.C_GLASS
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	_cached_mats["glass"] = m
	return m


func _static_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.global_position = pos
	sb.rotation.y = rot_y
	return sb


func _decal_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := _mat(color)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.rotation.y = rot_y
	return mi


## An UNSHADED box. At this ambient a pale quad that is merely lit renders as a
## grey rectangle, which is the difference between a hazard beacon and a smudge.
##
## Everything built through here starts HIDDEN and comes on with the dock. That
## is not a general-purpose helper decision, it is this encounter's: every
## emissive thing on the site is part of the same reveal, and a beacon that was
## already burning at t=0 would give the reveal away seventy seconds early. The
## concrete of the crossing is a `_decal_box` and stays visible throughout, which
## is correct — the ramp has always been there. Only the lights are new.
func _glow_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.4
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.rotation.y = rot_y
	mi.visible = false
	_dark_nodes.append(mi)
	return mi


## A ramp whose TOP SURFACE runs from `a` to `b`. Both are points ON the finished
## surface — doing the trigonometry at the call site is how you get a lip the
## goose trips over. Copied from zone_truckstop.gd:366 because the library's
## climb_ramps() returns its flights in exactly that form.
func _ramp(a: Vector3, b: Vector3, width: float, thick: float, col: Color) -> StaticBody3D:
	var d := b - a
	var flat := Vector2(d.x, d.z).length()
	var pitch := atan2(-d.y, flat)
	var yaw := atan2(d.x, d.z)
	var sb := _static_box((a + b) * 0.5 + Vector3(0, -thick * 0.5, 0),
		Vector3(width, thick, d.length()), col)
	sb.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	_hide_meshes(sb)
	return sb


func _flat_tiles(centre: Vector3, size: Vector3, nx: int, nz: int, key: StringName,
		fallback: Color, uv_scale: float, rough := 0.62) -> void:
	var mat := _surf(key, uv_scale, fallback, rough)
	var tw := size.x / float(nx)
	var td := size.z / float(nz)
	for ix in nx:
		for iz in nz:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(tw, size.y, td)
			mi.mesh = bm
			mi.material_override = mat
			add_child(mi)
			mi.global_position = centre + Vector3(
				-size.x * 0.5 + tw * (float(ix) + 0.5), 0.0,
				-size.z * 0.5 + td * (float(iz) + 0.5))


func _hide_meshes(sb: Node) -> void:
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false


## Every point light in the encounter goes through here so LIGHT_BUDGET stays
## countable in one place and nothing accidentally ships with shadows on: on GL
## Compatibility an omni shadow is a cube render, and there are 24 of these
## already lit across the interstate.
func _lamp(pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.0
	l.omni_range = rng
	l.omni_attenuation = 1.10
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	_lamps.append(l)
	_lamp_energy.append(energy)
	return l


## Build a model in its own holder so two models under one parent never collide
## over the name "Model" — BD.build() always names it that, and add_child()
## silently discards a requested name on collision.
func _model_at(kind: StringName, pos: Vector3, yaw: float, params := {}) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	n.rotation.y = yaw
	return BD.build(kind, n, params)


## Turn a model's "Glow" child off until the dock opens.
func _darken(model: Node3D) -> void:
	if model == null or not is_instance_valid(model):
		return
	var g := model.get_node_or_null("Glow")
	if g is Node3D:
		var g3: Node3D = g
		g3.visible = false
		_dark_nodes.append(g3)


## Turn a library kind's collider_boxes() into real StaticBody3Ds.
##
## The keys need explicit annotations on read — everything out of a Dictionary is
## a Variant and `var c := entry["c"]` is the parse error this codebase breaks on
## more than any other.
func _place_colliders(kind: StringName, params: Dictionary, origin: Vector3) -> void:
	for entry in BD.collider_boxes(kind, params):
		var e: Dictionary = entry
		var c: Vector3 = e["c"]
		var s: Vector3 = e["s"]
		_hide_meshes(_static_box(_to_world(origin, c), s, Color(1, 1, 1), YAW))


## Model-local to world, through the building's yaw.
func _to_world(origin: Vector3, local: Vector3) -> Vector3:
	return origin + Basis(Vector3.UP, YAW) * local


## …and back, for the "am I inside this building" tests.
func _to_local(origin: Vector3, world: Vector3) -> Vector3:
	return Basis(Vector3.UP, -YAW) * (world - origin)
