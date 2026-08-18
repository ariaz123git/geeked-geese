extends RefCounted
## Briefing content. Data only — no logic, no nodes.
##
## Everything here is deliberately SHORT. Players read roughly a quarter of the
## words you put in front of them and skip instructional overlays outright, so
## every card is built to be *scanned*: a title, one line of flavour, four or
## five key-cap rows, and at most one callout. If a card ever grows past six
## rows, cut rows — don't shrink the font.
##
## Usage:
##   const BriefDefs := preload("res://scripts/ui/briefing_defs.gd")
##   briefing.show_once(&"flight_first_run", BriefDefs.flight_first_run())
##
## Schema (every field optional except title + rows):
##   title            String     big line, all caps
##   subtitle         String     small line under the title
##   flavour          String     ONE deadpan sentence, wraps if it must
##   rows             Array      [{ keys: PackedStringArray, text: String }]
##   callout          Dictionary { label: String, text: String }
##   diagram          String     "" | "v_formation" | "dose_arc"
##   gamepad          String     one compact line of pad equivalents
##   button           String     label on the dismiss button
##   accent           Color      drives the top border, caps highlight, callout
##   compact          bool       narrower card, smaller type
##   auto_dismiss     float      seconds until it closes itself (0 = never)
##   respects_show_hints bool    honour the Settings > "Show hints" checkbox

const ACCENT_GROUND := Color(0.99, 0.78, 0.28)
const ACCENT_AIR := Color(0.55, 0.78, 0.98)
const ACCENT_DOSE := Color(0.55, 0.92, 0.55)


## Shown once, ever, the very first time a zone loads. The whole ground scheme
## in five rows. Dismissible in under two seconds by someone who doesn't care.
static func zone_first_run() -> Dictionary:
	return {
		"title": "THE LOT",
		"subtitle": "you are a Canada goose. this is your parking lot.",
		"flavour": "Nobody here is going to stop you. They have tried.",
		"rows": [
			{"keys": ["W", "A", "S", "D"], "text": "waddle"},
			{"keys": ["SPACE"], "text": "flap — get a run-up first, you are not a sparrow"},
			{"keys": ["H"], "text": "honk"},
			{"keys": ["E"], "text": "hold to eat whatever is on the ground"},
			{"keys": ["Q"], "text": "share it with the flock"},
		],
		"callout": {
			"label": "ONE THING",
			"text": "When the clock runs out you fly the flock to the next leg — in exactly the condition you left them in.",
		},
		"gamepad": "Gamepad:  left stick move  ·  A flap  ·  B honk  ·  X eat  ·  Y share",
		"button": "HONK",
		"accent": ACCENT_GROUND,
	}


## Shown once, ever, before the first migration. This is the card the whole
## feature exists for: the flight scheme is completely different from the
## ground scheme and it used to start with zero warning.
##
## Lead rotation gets the callout AND the animated diagram because it is the
## best mechanic in the game and it is genuinely hard to say in words.
static func flight_first_run() -> Dictionary:
	return {
		"title": "MIGRATION",
		"subtitle": "different bird. different controls.",
		"flavour": "Two thousand kilometres. One V. Nobody up here is sober but the sky doesn't care.",
		"rows": [
			{"keys": ["W", "A", "S", "D"], "text": "steer inside the corridor"},
			{"keys": ["SPACE"], "text": "climb"},
			{"keys": ["SHIFT"], "text": "drop"},
			{"keys": ["Q"], "text": "hand off the point"},
			{"keys": ["H"], "text": "honk a drifter back into line"},
		],
		"diagram": "v_formation",
		"callout": {
			"label": "LEAD ROTATION",
			"text": "The goose at the point gets no draft and burns out twice as fast. Q hands the point to someone else — but only to a goose sober and rested enough to take it. Party too hard in the lot and nobody can relieve you.",
		},
		"gamepad": "Gamepad:  left stick steer  ·  A climb  ·  RB drop  ·  Y hand off  ·  B honk",
		"button": "GOT IT",
		"accent": ACCENT_AIR,
	}


## Every migration after the first. Four rows, no diagram, no callout, and it
## closes itself after four seconds — a card you have already read is friction,
## so this one is a reminder rather than a gate. Any key kills it instantly.
static func flight_recap() -> Dictionary:
	return {
		"title": "MIGRATION",
		"subtitle": "flight controls, in case you forgot",
		"rows": [
			{"keys": ["W", "A", "S", "D"], "text": "steer"},
			{"keys": ["SPACE"], "text": "climb"},
			{"keys": ["SHIFT"], "text": "drop"},
			{"keys": ["Q"], "text": "hand off the point before you burn out"},
		],
		"button": "YEAH YEAH",
		"accent": ACCENT_AIR,
		"compact": true,
		"auto_dismiss": 4.0,
	}


## Contextual, first time only: fires the first time the player stands over a
## pickup, i.e. exactly when the sweet-spot arc first appears on the HUD.
## Honours the "Show hints" setting because this one is a hint, not a control
## scheme.
static func dose_hint() -> Dictionary:
	return {
		"title": "THE SWEET SPOT",
		"subtitle": "everything here has a dose. most of it has a bad one.",
		"rows": [
			{"keys": ["E"], "text": "hold to charge — let go to commit"},
		],
		"diagram": "dose_arc",
		"callout": {
			"label": "READ THE ARC",
			"text": "Green is the dose. Red is an overdose. Let go too early and you have eaten a cigarette butt for nothing.",
		},
		"button": "FINE",
		"accent": ACCENT_DOSE,
		"compact": true,
		"respects_show_hints": true,
	}


# ------------------------------------------------------------------ reference

## Both schemes, for the always-available controls reference. Kept here so the
## pause-menu card and the briefings can never drift apart.
static func reference_ground() -> Array:
	return [
		{"keys": ["W", "A", "S", "D"], "text": "waddle / steer"},
		{"keys": ["SPACE"], "text": "flap (run up first)"},
		{"keys": ["SHIFT"], "text": "dive"},
		{"keys": ["E"], "text": "hold to dose"},
		{"keys": ["H"], "text": "honk"},
		{"keys": ["Q"], "text": "share with the flock"},
		{"keys": ["J", "K"], "text": "swing the camera"},
		{"keys": ["R"], "text": "restart the run"},
	]


static func reference_flight() -> Array:
	return [
		{"keys": ["W", "A", "S", "D"], "text": "steer the corridor"},
		{"keys": ["SPACE"], "text": "climb"},
		{"keys": ["SHIFT"], "text": "drop"},
		{"keys": ["Q"], "text": "hand off the point"},
		{"keys": ["H"], "text": "rally a drifter"},
		{"keys": ["ENTER"], "text": "skip the results"},
		{"keys": ["ESC"], "text": "pause"},
	]
