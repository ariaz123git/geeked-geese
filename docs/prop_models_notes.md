# prop_models.gd — model inventory

> **Audited and corrected 2026-08-04.** This file used to contain a section
> headed *"`shared_material()` sets `cull_mode = CULL_FRONT` — do not 'fix' it"*.
> **That was wrong, and following it would have inverted every environment mesh
> in the game** — the exact bug the section thought it was preventing. The
> winding bug it described was fixed at source in `lowpoly_builder.gd::_emit()`
> and the material went back to `CULL_BACK`; the note was never updated. It is
> now §"Culling and winding" below, rewritten to match the code. Everything else
> in this file was checked against `scripts/world/prop_models.gd` on the same
> date and is unchanged except where marked.

Faceted low-poly replacements for the `BoxMesh` props and buildings in
`zone_strip_mall.gd` and `zone_suburbia.gd`. Built entirely through
`LowPolyBuilder`; no `SphereMesh`/`CylinderMesh`/`PrismMesh`/`TorusMesh`
anywhere; no `randf()`/`randi()` anywhere.

The original pass was **3663 triangles across 20 models**, all sharing **one
material** (white albedo, `vertex_color_use_as_albedo`). As of 2026-08-04
`FOOTPRINTS` registers **25** kinds — `stop_sign`, `hedge`, `basketball_hoop`,
`basketball` and `fly_agaric` were added after that measurement and are **not**
included in the 3663. Their triangle counts are not recorded here because they
were not measured; `build()` writes the real number onto every model as metadata,
so read it rather than trusting a table:

```gdscript
var m := PropModels.build(&"basketball_hoop", body)
print(m.get_meta("tri_count"))
```

---

## THE ANCHORING CONTRACT — read this first

Every model is built **base-anchored**: local origin on the ground at the
centre of the footprint, growing up `+Y`.

The zones' colliders are `BoxShape3D`s **centred** on the body origin, so drop
the model by half the footprint height when you hang it under a `ChaosProp` or
`StaticBody3D`:

```gdscript
var m := PropModels.build(&"shopping_cart", body)
m.position.y = -PropModels.footprint(&"shopping_cart").y * 0.5
```

For a prop that exists at two sizes across the zones, pass `size` and the model
is scaled so its footprint matches exactly:

```gdscript
PropModels.build(&"recycling_bin", body, {"size": Vector3(0.6, 0.9, 0.55)})
```

**Orientation:** the minivan's bonnet and the house's front facade are both at
local `-Z`, matching Godot's forward and matching `zone_suburbia.gd`'s
`rot = atan2(pos.x, pos.z)` convention, where the node's `-Z` maps to `front`.

---

## Culling and winding — `shared_material()` is `CULL_BACK`, and that is correct

**`PropModels.shared_material()` sets `cull_mode = BaseMaterial3D.CULL_BACK`**
(`prop_models.gd:150`). So does `LowPolyBuilder.make_material()`
(`lowpoly_builder.gd:274`), `prop_models_cottage.gd:131`, and
`prop_models_finale.gd:98`. **Leave them that way.** If you find a
builder-produced mesh set to `CULL_FRONT`, that is a bug, not a workaround.

### Why the winding is safe

Godot's front faces are **clockwise** — confirmed against the Godot 4.7
`SurfaceTool` class reference, which states: *"Godot uses clockwise winding order
for front faces of triangle primitive modes."* That is the opposite handedness
from the right-hand-rule normal `(b-a).cross(c-a)` that every mesh routine
naturally computes.

`LowPolyBuilder._emit()` handles this **at source**. It computes the normal in
right-hand-rule terms and then emits the vertices reversed while keeping that
normal:

```gdscript
var n := (b - a).cross(c - a)      # right-hand-rule outward normal
...
for v in [a, c, b]:                # emitted REVERSED — clockwise for Godot
    _st.set_normal(n)
```

Every face-emitting call above `_emit` (`tri`, `quad`, `loft`, `box`, the caps
and annuli) takes an `inside` reference point and orients itself outward relative
to it, so authors never reason about winding at all. **Do not "simplify" that
`for v in [a, c, b]` loop.** See `CLAUDE.md` § Mesh authoring and
`docs/GODOT_4.7_RULES.md` §5.2.

### The history, so nobody re-derives the wrong conclusion

There genuinely was an inverted-winding bug. `_emit()` originally submitted
`(a, b, c)` directly, which made every mesh the builder produced back-facing.
On closed convex shapes it was nearly undetectable — identical silhouette, and
the wrong shading just read as the key light having moved — which is how it
survived in `goose_visual_lowpoly.gd`. On open shapes it was fatal: the kiddie
pool rendered as a bare rim with no floor and no water, the trampoline lost its
mat, and the minivan's flanks and the house's roof pitches went to unlit black.

It was found by rendering an isolated `quad()` with a `+Z` normal and sampling
the centre pixel: it was culled when viewed from `+Z` and visible from `-Z`, and
a `box()` from the same library showed its bottom face's interior where the top
should have been.

The first fix was a workaround — flip `cull_mode` to `CULL_FRONT` on the
environment's own material, because `lowpoly_builder.gd` is shared with the goose
and re-winding it would silently re-light the finished bird. **That workaround is
gone.** The builder was corrected properly, the bird was re-checked, and every
material went back to `CULL_BACK`. `prop_models.gd:115-118` records the same
thing in code:

> `NOTE: this used to force CULL_FRONT to work around lowpoly_builder.gd`
> `emitting inside-out winding. That bug was found by rendering an isolated`
> `quad and sampling the centre pixel, and has since been FIXED in the`
> `builder itself (see the WINDING comment in _emit). Back to CULL_BACK.`

The paragraphs underneath that note in `prop_models.gd` still describe the *old*
broken state in the present tense. They are stale comment text kept for history,
sitting below a NOTE that supersedes them — **read the NOTE, not the paragraphs
after it**, and check `shared_material()` itself, which is four lines long and
unambiguous.

### The two deliberate exceptions

`CULL_DISABLED` appears in exactly two places in the project and both are
intentional and commented:

- `scripts/core/tex.gd:102`
- `scripts/world/prop_models_finale.gd:114` — the sprinkler's water fan, which
  is a single-sided fan that has to be visible from both sides.

---

## Model table

Footprint is `(x, y, z)` in metres, base-anchored. "Replaces" cites the call
site whose collider the footprint is matched to.

| kind | tris | footprint (x,y,z) | replaces | parameters |
|---|---:|---|---|---|
| `shopping_cart` | 480 | 0.80 × 1.00 × 1.30 | strip mall `_props()` `Vector3(0.8,1.0,1.3)` (×20 carts) | `colour` |
| `minivan` | 556 | 2.10 × 1.90 × 4.60 | strip mall `_parking()` `Vector3(2.1,1.9,4.6)`; suburbia `_driveways_and_cars()` `Vector3(1.9,1.6,4.2)` via `size` | `body_colour` |
| `house` | 486 | `w*1.08` × `wall_h+roof_h` × `d*1.08` | suburbia `_build_house()` body box + `_roof()` PrismMesh | `w`, `d`, `wall_h`, `roof_h`, `wall_colour`, `roof_colour`, `garage_side` |
| `dumpster` | 184 | 3.50 × 2.25 × 2.10 | strip mall `_sources()` `Vector3(3.4,2.0,2.0)` + lid decal | `colour` |
| `bench` | 180 | 1.80 × 0.85 × 0.62 | *(new — no existing call site)* | `colour` |
| `tree_deciduous` | 179 | 4.20 × 6.00 × 4.00 | strip mall `_trees()` and suburbia `_crabapple_tree()`: trunk `Vector3(0.5,3.2,0.5)` @ y 1.6 + canopy sphere r 2.4 @ y 4.2 | `colour` (bark), `leaf_colour`, `variant` |
| `bbq` | 172 | 1.00 × 1.05 × 0.55 | suburbia `_bbq_patio()` `Vector3(1.0,1.05,0.55)` | `colour` |
| `trampoline` | 170 | 3.95 × 0.70 × 3.95 | suburbia `_trampoline()` r 1.9 leg ring + rim @ 0.62 + mat @ 0.58 | `colour` |
| `patio_chair` | 144 | 0.60 × 0.90 × 0.60 | strip mall `Vector3(0.6,0.9,0.6)`; suburbia `Vector3(0.55,0.85,0.55)` via `size` | `colour` |
| `recycling_bin` | 144 | 1.00 × 1.20 × 0.80 | strip mall `Vector3(1.0,1.2,0.8)`; suburbia `Vector3(0.6,0.9,0.55)` via `size` | `colour` |
| `fence_panel` | 148 | 2.20 × 1.70 × 0.16 | suburbia `_fence_run()` pickets `Vector3(0.10,h,0.16)` @ 0.55 pitch, h 1.7 | `colour` |
| `lamp_post` | 114 | 1.40 × 8.40 × 0.70 | strip mall `Vector3(0.3,8.0,0.3)` + head decal; suburbia `Vector3(0.22,6.8,0.22)` via `size` | `colour` |
| `hydrant` | 108 | 0.40 × 0.80 × 0.40 | suburbia `_street_furniture()` `Vector3(0.4,0.8,0.4)` | `colour` |
| `garbage_bag` | 108 | 0.48 × 0.55 × 0.50 | suburbia `_garbage_day()` `Vector3(0.48,0.55,0.5)`; strip mall garbage `Vector3(0.5,0.7,0.5)` via `size` | `colour`, `variant` |
| `tree_conifer` | 93 | 2.40 × 6.00 × 2.40 | *(new — no existing call site)* | `colour` (bark), `leaf_colour` |
| `lawn_sign` | 92 | 1.10 × 0.80 × 0.08 | strip mall `_props()` `Vector3(1.1,0.8,0.08)` | `colour`, `ink_colour` |
| `gnome` | 81 | 0.32 × 0.55 × 0.32 | suburbia `_gnomes()` `Vector3(0.32,0.55,0.32)` | `colour` |
| `kiddie_pool` | 80 | 2.50 × 0.32 × 2.50 | suburbia `_kiddie_pool()` r 1.25 torus rim @ 0.16 + water disc | `colour` |
| `mailbox` | 76 | 0.42 × 0.30 × 0.60 | suburbia `_street_furniture()` `_on_post(..., Vector3(0.42,0.3,0.6), ...)` | `colour` |
| `cattail` | 68 | 0.30 × 1.40 × 0.30 | strip mall `_pond()` `_decal_box(..., Vector3(0.08,1.2,0.08))` | `colour` |

**Added after the measurement pass (2026-08-04).** These five are registered in
`FOOTPRINTS` and dispatched by `build()`, but they were not part of the 3663-tri
harness run, so their triangle counts and AABB-vs-footprint checks are **not**
recorded here. Read `model.get_meta("tri_count")` for the real number, and
re-run the harness before trusting the footprints as collider-matched.

| kind | tris | footprint (x,y,z) | replaces | parameters |
|---|---:|---|---|---|
| `stop_sign` | *unmeasured* | 0.72 × 2.26 × 0.16 | suburbia's spawn-point stop sign (the graybox called out in `HANDOFF.md` §4) | `colour` |
| `hedge` | *unmeasured* | 1.60 × 0.74 × 0.60 | *(new)* | `colour`, `variant` |
| `basketball_hoop` | *unmeasured* | 1.20 × 3.40 × 0.95 | *(new)* | `colour` |
| `basketball` | *unmeasured* | 0.42 × 0.42 × 0.42 | *(new)* | `colour` |
| `fly_agaric` | *unmeasured* | 1.00 × 0.87 × 1.00 | *(new — the substance pickup)* | `colour`, `variant` |

**Unknown kinds still build.** `build()`'s `match` falls through to `_fallback()`,
a faceted crate, so nothing in the world is ever invisible. `has_model(kind)`
tests `FOOTPRINTS` and is the way to ask before falling back to your own box.

Every model in the **first twenty** had its measured mesh AABB checked against its
declared footprint in the harness. All fit, with three deliberate exceptions:

* **house** — the chimney rises `roof_h*0.30 + 0.10` above the ridge and the
  front step projects 0.28 m past the eave. Both already behaved this way in
  `zone_suburbia.gd` (the chimney is separate geometry and the roof collider is
  a flat plateau), so nothing regresses.
* **minivan** — 2.13 wide against a 2.10 collider, because the door mirrors
  stand 1.5 cm proud of each flank. Mirrors are supposed to stick out.
* **fence_panel** — 2.29 against a 2.20 tiling pitch, because the end post is
  centred on the panel joint. That is what makes it tile: butt panels at 2.20
  and each post lands exactly on the seam.

**Budget:** the three signature props land at 480 / 556 / 486, inside the
250–600 band. Of the rest, `dumpster` (184), `bench` (180), `tree_deciduous`
(179) and `trampoline` (170) sit over the ~150 guideline; all four are large
objects (2–6 m) where the extra facets are load-bearing for the silhouette.
Everything under 1.5 m is at or below 150.

---

## Notes on individual models

**shopping_cart** — the game's signature prop, so it got the most attention.
The basket is a real container: an outer skin, a rim lip and an inner skin, so
you can look down into it. Four corner posts are built from the actual basket
corner points and two wire bands are interpolated along the wall, which is what
makes it read as wire rather than as a trough — the first pass used
constant-`x` boxes and they floated visibly off the tapered wall. Nose is much
lower and narrower than the tail, which is the single strongest "cart" cue.
Confirmed legible at 18 m in the harness.

**minivan** — 8-station lower body and a 5-station greenhouse, both lofted from
cross-section tables. The windscreen rake comes from 0.62 m of run between the
cowl and the A-pillar. All the glass — windscreen, side windows, quarter
lights, tailgate — is one per-face colour callback (`_van_colour`) and costs
zero extra triangles; the B and C pillars are just body-coloured bands in the
same function. Wheels are 7-sided with a dark sidewall annulus and a small hub
cap: capping straight to a hub-coloured apex, as the first pass did, paints the
entire wheel face pale and it stops reading as a tyre. Door shut lines are
lofted struts (8 tris) rather than pairs of boxes (24), which paid for the
wheel detail.

**house** — gable ridge running front-to-back along `Z` so the pitched triangle
faces the road, matching the `PrismMesh` it replaces. Each pitch is split into
three bands with a slight fold, so the away-facing slope always has at least
one facet catching a light instead of going to a flat black void. Facade layout
is driven off `w` and `garage_side` and was re-laid-out after round one, where
the door and the small window overlapped at `w = 10`.

**tree_deciduous** — three interpenetrating angular blobs, not one sphere, so
the outline changes as you orbit it. Two branch stubs exist so the canopy has
something to sit on; a canopy floating above a bare trunk is the classic
low-poly tree failure. All lumpiness is `sin`/`cos` of the ring and vertex
indices, keyed off the `variant` parameter.

**garbage_bag** — the one object that must not look manufactured. Six-sided
rings pushed around per-vertex and a leaning spine, plus a twist-tie knot,
which is the detail that turns a lump into a bag of garbage.

---

## Verification performed

Scratch Godot 4.7.1 project, `xvfb` + `opengl3`, three-point lighting (warm
key with shadows, cool fill, white rim), 14 camera set-ups including two-angle
closeups of the cart, minivan and house, an 18 m distance test, and
side-by-side before/after against plain `BoxMesh`es at identical footprints.
Every render was read back and inspected. Five iteration rounds.

Also verified: mesh AABB vs declared footprint for every model, and an
ambient-only pass (directional lights killed) to separate genuine inverted
faces from surfaces that were merely unlit.

**Scope.** All of the above covers the original twenty models only. The five
kinds added later (`stop_sign`, `hedge`, `basketball_hoop`, `basketball`,
`fly_agaric`) have not been through this harness as far as this document knows.
The ambient-only pass is the one to repeat first if anything looks wrongly lit —
it is what separates a genuinely inverted face from a face that is merely facing
away from the key light, and guessing between those two is what produced the
`CULL_FRONT` error this file was corrected for.
