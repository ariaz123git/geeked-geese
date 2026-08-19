extends Resource
class_name Substance

## A single substance. THE most important class in the project.
##
## DESIGN RULE (do not violate): a substance must never be only a number that
## goes up. Every entry here must include at least one CONTROL MUTATION —
## something that changes how the player's hands work. If you find yourself
## adding a substance that only edits speed_mult, delete it.

@export_group("Identity")
@export var id: StringName = &"unnamed"
@export var display_name: String = "Unnamed"
@export var blurb: String = ""
## What this is a joke about. Drives the Almanac entry and the ESRB self-report.
## Every substance in the game must fill this in — if you can't name what it
## mimics, you don't know what you're designing.
@export var mimics: String = ""
## Real-world fact shown in the Bird Brain Almanac. Must be TRUE and sourced.
@export_multiline var codex_fact: String = ""
@export var tint: Color = Color.WHITE

@export_group("Dose")
## Seconds of holding [eat] to reach full dose (1.0).
@export var charge_time: float = 1.1
## Dose range that counts as the sweet spot. Below = weak, above = overdose.
@export var sweet_min: float = 0.42
@export var sweet_max: float = 0.78
@export var duration: float = 14.0
## Seconds of being WORSE than baseline after it wears off.
@export var comedown: float = 5.0

@export_group("Brain chemistry (targets, -1..1)")
@export_range(-1.0, 1.0) var dopamine: float = 0.0
@export_range(-1.0, 1.0) var adrenaline: float = 0.0
@export_range(-1.0, 1.0) var gaba: float = 0.0
@export_range(-1.0, 1.0) var serotonin: float = 0.0

@export_group("Control mutations — the actual design surface")
## Seconds of input delay. The berries' whole personality.
@export var input_lag: float = 0.0
## Random walk added to the movement vector, 0..1.
@export var drift: float = 0.0
@export var flap_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var gravity_mult: float = 1.0
@export var turn_mult: float = 1.0
## Hard landings become uncontrolled tumbles (and smash props).
@export var ragdoll_landings: bool = false
## Releasing the stick doesn't stop you. Caffeine.
@export var cannot_idle: bool = false
## Engine time scale while active. Nitrous.
@export var time_scale: float = 1.0
## Props break on contact regardless of impact speed.
@export var smash_through: bool = false
## Camera stops being attached to you. Ketamine. 0 = normal, 1 = fully adrift.
@export var camera_detach: float = 0.0
## Movement snaps to 90° increments. DXM. Robotic and hilarious.
@export var grid_snap: bool = false
## HUD objectives and score vanish while active. Benzos cause real anterograde
## amnesia — this is the honest version of that, as a mechanic.
@export var hud_amnesia: bool = false
## Fake props and fake NPCs spawn that you cannot distinguish from real ones.
## Deliriants do this. TODO(hook): not yet wired into the zone builder.
@export var hallucinate: float = 0.0
## You stop taking fall damage and can't tumble. Opioids.
@export var no_fall_damage: bool = false
## MACROPSIA / MICROPSIA. Amanita muscaria's actual signature effect: things
## look far bigger or smaller than they are, and it PULSES. We execute it by
## scaling the goose, which is physically honest — a tiny goose really can get
## under the dumpster, and a huge one really can step over a minivan. Scale is
## a traversal tool, not a filter.
## Amplitude in octaves: 1.5 -> roughly 0.35x to 2.8x.
@export var scale_amp: float = 0.0
## Seconds for one full small->large->small cycle.
@export var scale_period: float = 7.0
## Cats within earshot go berserk. Doesn't touch you at all — that's the joke.
@export var aggro_cats: bool = false
## How many tolerance points one dose adds. Nicotine is 3 — that's the point.
@export var tolerance_gain: int = 1

@export_group("Presentation")
## Which branch of screen_fx.gdshader to drive: 0 none, 1 wobble, 2 jitter, 3 slowmo
@export var fx_mode: int = 0
@export var fx_strength: float = 1.0
## Honk pitch multiplier. This is 100% of your marketing clips. Take it seriously.
@export var honk_pitch: float = 1.0

@export_group("Economy")
@export var stamina_restore: float = 0.0
## Chaos score multiplier while active.
@export var chaos_mult: float = 1.0


## Scale every mutation by dose quality and tolerance.
## Returns a plain Dictionary the SubstanceManager can sum across actives.
func resolve(dose: float, tolerance: int) -> Dictionary:
	var quality := 1.0
	var overdosed := false
	if dose < sweet_min:
		# Under the band: proportionally weak, minimum 15% so it's not a total whiff.
		quality = maxf(0.15, dose / maxf(sweet_min, 0.001))
	elif dose > sweet_max:
		# Over the band: MORE raw effect but the bad parts scale harder.
		quality = 1.0 + (dose - sweet_max) * 1.5
		overdosed = true

	# Tolerance shrinks the good, never the bad. This is the lesson, uncommented.
	var tol := 1.0 / (1.0 + 0.35 * float(tolerance))

	var good := quality * tol
	var bad := quality * (1.6 if overdosed else 1.0)

	return {
		"id": id,
		"overdosed": overdosed,
		"quality": quality,
		"input_lag": input_lag * bad,
		"drift": drift * bad,
		"flap_mult": 1.0 + (flap_mult - 1.0) * good,
		"speed_mult": 1.0 + (speed_mult - 1.0) * good,
		# FLOORED, BECAUSE `bad` IS UNBOUNDED AND THESE TWO CROSS ZERO.
		#
		# `quality` on an overdose is `1.0 + (dose - sweet_max) * 1.5` and `bad`
		# multiplies that by another 1.6, so a full-charge dose reaches bad = 2.37.
		# Both of these fields are declared BELOW 1.0 by most of the shelf, and
		# `1.0 + (v - 1.0) * bad` goes negative once `bad > 1 / (1 - v)`. Nothing
		# downstream clamps either one: `_aggregate()` multiplies them raw, and the
		# controller's only two readers do not check the sign.
		#
		# Two live bugs, both reachable by simply HOLDING the eat key — `_tick_eat`
		# saturates `_eat_charge` at exactly 1.0, so max dose is the default outcome
		# of not letting go:
		#
		#   * special_k (gravity_mult 0.55, sweet_max 0.68) turns NEGATIVE above
		#     dose 0.939. At 1.0 it resolves to -0.066, so `_tick_ground` accelerates
		#     the bird UPWARD at 1.84 m/s² and `_tick_fly` makes glide AND dive
		#     gravity negative too — there is no input that brings it down. It rises
		#     roughly 150 m over the dose's scaled 15.6 s and comes back through a
		#     `_tick_ground` fall, which has no `max_fall`, at 90–115 m/s.
		#   * math and special_k make `turn_mult` <= 0 at ANY overdose (robo above
		#     0.867, toad_slime above 0.787, percs above 0.955). `_face()` clamps its
		#     step to `[0, 1]`, so a negative rate is an exact no-op: the heading
		#     freezes for the whole duration while the bird keeps sliding, and the
		#     Almanac cheerfully prints "Turning x0.34" for a multiplier delivered
		#     as zero.
		#
		# 0.05 keeps gravity real but negligible; 0.08 keeps the bird steerable at
		# a twelfth of normal, which is a punishing overdose rather than a frozen
		# one. Asserted at dose 1.0 in `tools/selftest.gd::_the_overdose()` —
		# no gate in this project had ever resolved a substance above 0.6, so the
		# entire overdose branch was unmeasured.
		"gravity_mult": maxf(0.05, 1.0 + (gravity_mult - 1.0) * bad),
		"turn_mult": maxf(0.08, 1.0 + (turn_mult - 1.0) * bad),
		"ragdoll_landings": ragdoll_landings,
		"cannot_idle": cannot_idle,
		"time_scale": time_scale,
		"smash_through": smash_through,
		"camera_detach": camera_detach * bad,
		"grid_snap": grid_snap,
		"hud_amnesia": hud_amnesia,
		"hallucinate": hallucinate * bad,
		"no_fall_damage": no_fall_damage,
		"scale_amp": scale_amp * good,
		"scale_period": scale_period,
		"aggro_cats": aggro_cats,
		"fx_mode": fx_mode,
		"fx_strength": fx_strength * bad,
		"honk_pitch": honk_pitch,
		"chaos_mult": 1.0 + (chaos_mult - 1.0) * good,
		"dopamine": dopamine * good,
		"adrenaline": adrenaline * good,
		"gaba": gaba * good,
		"serotonin": serotonin * good,
		"duration": duration * (1.0 + (dose - 0.5) * 0.6),
		"comedown": comedown * bad,
	}
