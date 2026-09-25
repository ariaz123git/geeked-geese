# GODOT 4.7 — API RULES FOR THIS PROJECT

**Written:** 2026-08-04, against Godot **4.7.1-stable**, by fetching the docs.
**Nothing in this file was written from memory.** Every claim below is either
(a) quoted from a page listed in §8, (b) read out of this repo's own source, or
(c) explicitly flagged as unverified in §7. If you add to this file, keep that
property — a document whose entire job is to stop a model hallucinating an API
is worthless the moment it contains one.

**Read for:** the reader is a competent Godot programmer whose knowledge stops
somewhere around 4.4/4.5. This is a delta, not a tutorial.

---

## Contents

- [§0 Version facts](#0-version-facts)
- [§1 What changed in 4.7 (from 4.6)](#1-what-changed-in-47-from-46)
- [§2 What changed in 4.6 (from 4.5)](#2-what-changed-in-46-from-45)
- [§3 What changed in 4.5 (from 4.4)](#3-what-changed-in-45-from-44)
- [§4 APIs this project already relies on, confirmed against 4.7](#4-apis-this-project-already-relies-on-confirmed-against-47)
- [§5 The traps that have actually bitten *this* project](#5-the-traps-that-have-actually-bitten-this-project)
- [§6 How to check an API you are unsure about](#6-how-to-check-an-api-you-are-unsure-about)
- [§7 What I could not verify](#7-what-i-could-not-verify)
- [§8 Sources](#8-sources)

---

## 0. Version facts

| | |
|---|---|
| Engine | **4.7.1-stable**. Confirmed: `version.py` on the `4.7.1-stable` tag reads `major=4, minor=7, patch=1, status="stable", docs="4.7"`. |
| 4.7.1 released | **14 July 2026** (maintenance release, 78 fixes / 42 contributors). |
| 4.7 released | mid-June 2026. The 4.7.1 announcement says "approximately four weeks prior"; I did not pin the exact day. `CLAUDE.md` says 18 June 2026 and nothing I read contradicts it. |
| Docs branch | `https://docs.godotengine.org/en/4.7/`. As of Aug 2026, `/en/stable/` also resolves to 4.7. |
| This project | `project.godot` declares `config/features=PackedStringArray("4.7", "GL Compatibility")` and `renderer/rendering_method="gl_compatibility"`. |

Nothing in the 4.7.1 patch notes touches GDScript, CharacterBody3D, audio,
physics or CanvasItem line drawing. The 4.7.1 rendering fixes are: flickering
lighting on non-uniformly-scaled mesh instances, orthographic directional shadow
culling, a stale-transform-for-2-frames bug, and a shader variant payload read.

---

## 1. What changed in 4.7 (from 4.6)

Ordered by how likely each is to cause a bug **in this repo**, not by how the
upstream guide orders them.

### 1.1 🔴 `CanvasItem` no longer feathers lines — every `_draw()` hairline got thinner

Verbatim from the upgrade guide:

> "`CanvasItem` now avoids adding the antialiasing feather when drawing lines.
> The feather made lines appear thicker than intended, projects that relied on
> this behavior will have to be updated to draw a thicker line width."

**Why this matters here.** This project's UI is almost entirely `_draw()`, and it
draws a *lot* of sub-2px rules: `draw_rect(..., 1.0)` separators in `briefing.gd`,
`control_card.gd`, `flock_roster.gd` and `hud.gd`; `draw_polyline(..., 1.5)`;
`draw_line(..., 1.6/1.8)`; `draw_rect(..., false, 1.0)` outlines. Under 4.6 those
rendered visibly fatter than their nominal width. Under 4.7 they render at their
nominal width and can drop to near-invisible.

This is **not** a bug to fix by turning antialiasing on. If a separator has gone
faint, raise the width. Do not raise it blind — render it and look.

Signatures, confirmed against the 4.7 `CanvasItem` docs (note `width` defaults to
**-1.0**, and that a negative width switches to a line *primitive*, not a quad):

```gdscript
draw_line(from: Vector2, to: Vector2, color: Color, width := -1.0, antialiased := false)
draw_polyline(points: PackedVector2Array, color: Color, width := -1.0, antialiased := false)
draw_arc(center: Vector2, radius: float, start_angle: float, end_angle: float,
         point_count: int, color: Color, width := -1.0, antialiased := false)
draw_circle(position: Vector2, radius: float, color: Color, filled := true,
            width := -1.0, antialiased := false)
draw_rect(rect: Rect2, color: Color, filled := true, width := -1.0, antialiased := false)
```

Docs notes worth keeping in your head:
- `draw_polyline`: antialiasing is "supported only for positive `width`".
- `draw_circle` / `draw_rect`: "`width` is only effective if `filled` is `false`".
- `draw_arc`: "If `width` is negative, it will be ignored and the arc will be
  drawn using `RenderingServer.PRIMITIVE_LINE_STRIP`."

### 1.2 🔴 GDScript: an override now inherits its parent's typed return

Verbatim:

> "Methods that inherit from a method with a typed return now inherit the return
> type as well, requiring an explicit return statement in the override. Add
> `return null` to the end of the method to fix the error."

So overriding a base method declared `-> Something` and falling off the end of the
override is now a **compile error**, even where you wrote no return type yourself.

Current exposure in this repo: **low but not zero, and there is one live
inheritance chain to watch.**

- No top-level `.gd` file in `scripts/` extends another project script — every
  file-level `extends` is an engine class.
- **One inner class does:** `zone_finale.gd:1289`,
  `class CreditSlab extends CHAOS_PROP`. It overrides `shove()`, `hit()` and
  `_maybe_score()`, all of which return `void` in `chaos_prop.gd`, so it is safe
  today. But `chaos_prop.gd` also has `func _impact_sound() -> StringName` — the
  day something overrides *that* and falls off the end, this rule fires.
- The other way in is overriding an engine virtual with a typed return
  (`_get_configuration_warnings`, `_get_drag_data`, `_make_custom_tooltip`,
  `_property_can_revert`, …). None of those are overridden today.

### 1.3 🟠 GDScript: packed-array element writes no longer fire the property setter

Verbatim:

> "Setting the element of packed arrays no longer calls the setter for the entire
> packed array property."

i.e. `some_node.packed_property[3] = x` no longer runs `set_packed_property()`.
If you need the setter to run, read the array out, mutate it, and assign it back.

### 1.4 🟠 `AudioStreamPlayer` positional `area_mask` default changed 1 → 0

Verbatim (filed under Physics in the guide, which is confusing — it is an audio
change):

> "The default `area_mask` for `AudioStreamPlayer` was changed from 1 to 0
> (disabled). If you use the `audio_bus_override` feature on `Area2D` or `Area3D`,
> and you use the `AudioStreamPlayer` default `area_mask` (just layer 1 ticked),
> you will need to reset the mask to layer 1 — otherwise, the bus overrides will
> stop working."

Confirmed in the class reference: `AudioStreamPlayer3D.area_mask` default is now
**0**, described as "Determines which `Area3D` layers affect the sound for reverb
and audio bus effects." Plain `AudioStreamPlayer` has **no** `area_mask` property
at all, so the guide means the positional players.

**Exposure here: zero today.** Nothing in `scripts/` sets `area_mask` or
`audio_bus_override`. But `docs/MUSIC_NOTES.md` builds its reverb/filter graph on
`AudioServer` buses, and the obvious next step — Area3D-driven reverb zones, e.g.
"under the overpass" — will silently do nothing in 4.7 unless you set
`area_mask` explicitly on every `AudioStreamPlayer3D`.

### 1.5 🟡 Input device IDs for mouse and keyboard moved off 0

> "The device IDs for mouse and keyboard were changed from 0 to
> `InputEvent.DEVICE_ID_MOUSE` and `InputEvent.DEVICE_ID_KEYBOARD` because some
> joypads may use 0 as their ID. Check the input event by type or compare the
> device ID to the constants instead."

Any `if event.device == 0:` is now wrong. This repo checks event *type*
everywhere (`_unhandled_input` in `main.gd`, `goose_controller.gd`,
`goose_camera.gd`, and the UI `_input` handlers), so it is currently clean. Keep
it that way — matters for the split-screen work in `docs/MULTIPLAYER_SPEC.md`,
where device IDs would otherwise be the natural way to split players.

### 1.6 🟡 Jolt physics behaviour changes

These only apply **when Jolt is the 3D physics engine** — see §7, because I could
not determine which engine this project actually runs.

- `WorldBoundaryShape3D` now interprets the sign of `plane.d` the same way Godot
  Physics does, i.e. **opposite to Godot 4.6 under Jolt**. Flip the sign to keep
  4.6 behaviour.
- `SoftBody3D` mass no longer defaults to 0 (which auto-computed 1 kg per point);
  it now defaults to 1 kg for the whole body, matching Godot Physics.
- `SoftBody3D.linear_stiffness` is applied differently; "you will need to re-tweak
  properties".
- `Area3D` now reports overlaps with `SoftBody3D`.

No `SoftBody3D` or `WorldBoundaryShape3D` in this repo, so no exposure today. The
`Area3D` change is worth knowing because this project uses 25 `Area3D`s.

### 1.7 🟡 Rendering

> "The `LinearToSRGB` visual shader no longer clamps to the range `[0.0, 1.0]`
> when using the Mobile or Forward+ renderer."

No visual shaders here (`shaders/screen_fx.gdshader` is hand-written), and this
project is on GL Compatibility anyway.

### 1.8 Changed defaults in 4.7

| Class / setting | Member | Old | New |
|---|---|---|---|
| `LookAtModifier3D` | `relative` | `true` | `false` |
| `ProjectSettings` | `rendering/reflections/sky_reflections/roughness_layers` | 7 | 8 |
| `RichTextLabel` | `add_image()` / `update_image()` `width_in_percent`, `height_in_percent` | `false` | `0` |
| `ResourceImporterDynamicFont` | `hinting` | 1 | 3 |

### 1.9 Signature changes in 4.7 that are source-compatible for GDScript

All of these are additive optional parameters or type refinements — GDScript
callers keep working. Listed so you don't "discover" them and think something is
broken. From the 4.7 upgrade guide's Breaking-changes tables:

- `Object.is_class()` — `class` param `String` → `StringName`.
- `ZIPPacker.start_file()` — adds optional `permissions`, `modified_time`.
- `OptimizedTranslation.generate()` — return `void` → `bool`.
- `CPUParticles2D/3D.request_particles_process()`,
  `GPUParticles2D/3D.request_particles_process()` — add optional
  `process_time_residual`.
- `Control.accessibility_live` — type moved from
  `DisplayServer.AccessibilityLiveMode` to `AccessibilityServer.AccessibilityLiveMode`.
- `Font.find_variation()` — adds optional `palette_index`, `custom_colors`.
- `TreeItem.select()` — adds optional `set_as_cursor`.
- `Image.save_exr()` / `save_exr_to_buffer()` — add optional `color_image`,
  `max_linear_value`.
- `ImageTexture.get_format()` and `PortableCompressedTexture2D.get_format()` moved
  up to `Texture2D`.
- `RenderingServer.viewport_set_size()` — adds optional `view_count`.
- `RenderingServer.particles_request_process_time()` — `time` renamed to
  `process_time`, adds optional `process_time_residual`.
- `Animation.length` — metadata `float` → `double`.
- `AnimationNodeBlendSpace1D/2D.add_blend_point()` — add optional `name`.
- `PhysicsServer2D.body_set_shape_as_one_way_collision()` — adds optional `direction`.
- `EditorSceneFormatImporter`'s seven `IMPORT_*` constants moved into an
  `ImportFlags` enum.

**GDScript-incompatible in 4.7** (these actually break source):

- `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → renamed
  `UPDATE_WIDTH_UNIT`.
- `RichTextLabel.add_image()` / `update_image()` — `width_in_percent` /
  `height_in_percent` renamed to `width_unit` / `height_unit`, and their type went
  `bool` → `RichTextLabel.ImageUnit`. `width`/`height` went `int` → `float`.
- `AudioEffectSpectrumAnalyzer.tap_back_pos` — **property removed.**
- `OpenXRExtensionWrapper._on_register_metadata()`,
  `PhysicsServer2DExtension._body_set_shape_as_one_way_collision()`,
  `EditorVCSInterface._commit()` — added required params.

### 1.10 New in 4.7 that is genuinely useful here

- **`Tween.tween_await(signal: Signal) -> AwaitTweener`** — "This method can be
  used to await a signal and create asynchronous animations." Every place in this
  codebase that currently does `tw.tween_interval(x)` and hopes, or chains a
  `tween_callback` into an `await`, can now sequence on a real signal.
  `zone_finale.gd`'s credits roll and `mission_hud.gd`'s toast chain are the
  obvious candidates.
- **`Control` offset transforms** — `offset_transform_enabled`,
  `offset_transform_position`, `offset_transform_position_ratio`,
  `offset_transform_rotation`, `offset_transform_scale`, `offset_transform_pivot`,
  `offset_transform_pivot_ratio`, `offset_transform_visual_only`. These animate a
  `Control` **without affecting layout**. That is exactly what most of the UI
  juice in `mission_hud.gd` is faking today by tweening `position` and
  `custom_minimum_size` inside containers.
- `AreaLight3D`, HDR output, an inline shader preview in the editor, a virtual
  joystick node, a `MeshLibrary` editor, `Tween.tween_await`. (From the release
  announcement; only the two above are relevant to this project.)

---

## 2. What changed in 4.6 (from 4.5)

Included because a model trained before 4.6 will get these wrong too.

### 2.1 🔴 Changed defaults that alter how the game *looks*

| Setting | Old | New |
|---|---|---|
| `Environment.glow_blend_mode` | 2 | 1 (**Screen**, brighter than the previous Soft Light) |
| `Environment.glow_intensity` | 0.8 | 0.3 |
| `Environment.glow_levels/2` | 0.0 | 0.8 |
| `Environment.glow_levels/3` | 1.0 | 0.4 |
| `Environment.glow_levels/4` | 0.0 | 0.1 |
| `Environment.glow_levels/5` | 1.0 | 0.0 |
| `Environment.ssr_depth_tolerance` | 0.2 | 0.5 |
| `ProjectSettings .../sky_reflections/roughness_layers` | 8 | 7 (then back to 8 in 4.7) |
| `MeshInstance3D.skeleton` | `NodePath("..")` | `NodePath("")` |
| `PopupMenu.submenu_popup_delay` | 0.3 | 0.2 |

Also: "Volumetric fog blending adjusted for physical accuracy, appearing
brighter. Recommend decreasing volumetric fog density/brightness or light
energy."

**Exposure here:** `zone_finale.gd` and the other zones build `Environment`
objects in code and set fog, ambient and tonemap explicitly, but do **not** set
any `glow_*` property. Any glow they get is the 4.7 default, not the 4.5 one you
may remember. If you are tuning night lighting in `zone_cottage.gd`, set glow
explicitly rather than relying on a default you learned three versions ago.

### 2.2 🟠 New-project defaults changed

- Windows rendering driver → **D3D12** (new projects only). Irrelevant here: this
  project pins `gl_compatibility`.
- 3D physics engine → **Jolt Physics** (new projects only). See §7 — I could not
  determine what this project actually runs.

### 2.3 🟡 `.tscn` format changed

> "Scene file format (`tscn`) changed: `load_steps` no longer written; unique node
> IDs now saved. Changes remain backward and forward compatible. Significant
> version control diffs expected when upgrading 4.5 scenes to 4.6."

Barely matters for a project that is ~99% code-built node trees, but it means a
hand-written `.tscn` copied from a pre-4.6 tutorial will look wrong next to one
the editor saved.

### 2.4 Signature changes in 4.6 (GDScript-compatible unless noted)

- `FileAccess.get_as_text()` — **`skip_cr` parameter removed.**
- `FileAccess.create_temp()` — `mode_flags` `int` → `FileAccess.ModeFlags`.
- `Performance.add_custom_monitor()` — adds optional `type`.
- `AnimationPlayer.assigned_animation` / `autoplay` / `current_animation` —
  `String` → `StringName`; `get_queue()` returns `StringName[]`;
  `current_animation_changed` signal param is a `StringName`.
- `Control.grab_focus()` — adds optional `hide_focus`.
- `Control.has_focus()` — adds optional `ignore_hidden_focus`.
- `LineEdit.edit()` — adds optional `hide_focus`.
- `FileDialog.add_filter()` — adds optional `mime_type`.
- `SplitContainer.clamp_split_offset()` — adds optional `priority_index`.
- `StreamPeerTCP.disconnect_from_host()/get_status()/poll()` moved to
  `StreamPeerSocket`; `TCPServer.is_connection_available()/is_listening()/stop()`
  moved to `SocketServer`.
- Navigation: `AStar2D.get_point_path`, `AStar3D.get_point_path`,
  `AStarGrid2D.get_id_path`, `AStarGrid2D.get_point_path` "will now return an
  empty path when `from_id` is a disabled/solid point."

---

## 3. What changed in 4.5 (from 4.4)

Short list; most of it is irrelevant here, but two items are not.

- 🔴 **`Resource.duplicate(true)` now duplicates only *internal* resources.** Use
  `duplicate_deep(DEEP_DUPLICATE_ALL)` for the old behaviour. This project loads
  `Substance` `.tres` resources into `Subs.library`; if anything ever starts
  duplicating them to make per-run variants, this is the trap.
- 🟠 **Text drawing gained an `oversampling` parameter.** `CanvasItem.draw_string`,
  `draw_string_outline`, `Font.*`, `TextLine.*`, `TextParagraph.*` all take an
  optional trailing `oversampling: float = 0.0`. Purely additive, but it means the
  `draw_string` signature you remember is short by one argument.
- `Node.get_rpc_config` renamed `get_node_rpc_config` (GDScript-breaking).
- `Node.set_name` param `String` → `StringName`.
- `JSONRPC.set_scope` replaced by `set_method`.
- `RenderingServer.instance_reset_physics_interpolation` and
  `instance_set_interpolated` **removed**.
- `RichTextLabel.add_image` — `size_in_percent` replaced by `width_in_percent` +
  `height_in_percent` (and then both renamed again in 4.7, see §1.9).
- `ProjectSettings.add_property_info()` now warns about missing/invalid keys.
- Jolt: Area3D/static-body overlaps now reported by default.

---

## 4. APIs this project already relies on, confirmed against 4.7

Everything in this section was checked against the 4.7 class reference on
**2026-08-04**. You do not need to re-check these before using them.

### 4.1 `CharacterBody3D` — `scripts/goose/goose_controller.gd`

Confirmed present in 4.7 with these signatures and defaults:

```gdscript
move_and_slide() -> bool
is_on_floor() -> bool                     # "on the last call of move_and_slide"
is_on_floor_only() / is_on_wall() / is_on_wall_only()
is_on_ceiling() / is_on_ceiling_only() -> bool
get_slide_collision_count() -> int
get_slide_collision(slide_idx: int) -> KinematicCollision3D
get_last_slide_collision() -> KinematicCollision3D    # null if none
apply_floor_snap() -> void                # no-op when is_on_floor() is true
get_floor_normal() / get_wall_normal() / get_platform_velocity() -> Vector3
get_floor_angle(up_direction := Vector3(0, 1, 0)) -> float
get_real_velocity() / get_last_motion() / get_position_delta() -> Vector3
```

Properties and **engine defaults** (this project overrides two of them):

| Property | Engine default | This project |
|---|---|---|
| `velocity` | `Vector3(0,0,0)` | used every frame |
| `up_direction` | `Vector3(0,1,0)` | set explicitly, `goose_controller.gd:125` |
| `floor_snap_length` | **0.1** | **0.4**, `goose_controller.gd:126` — deliberate |
| `motion_mode` | `MOTION_MODE_GROUNDED` (0) | default |
| `max_slides` | 6 | default |
| `safe_margin` | 0.001 | default |
| `floor_max_angle` | 0.7853982 (45°) | default |
| `floor_block_on_wall` | `true` | default |
| `floor_stop_on_slope` | `true` | default |
| `floor_constant_speed` | `false` | default |
| `slide_on_ceiling` | `true` | default |
| `wall_min_slide_angle` | 0.2617994 (15°) | default |
| `platform_on_leave` | `PLATFORM_ON_LEAVE_ADD_VELOCITY` (0) | default |
| `platform_floor_layers` | 4294967295 | default |
| `platform_wall_layers` | 0 | default |

The `velocity` doc still says, verbatim: *"Current velocity vector (typically
meters per second), used and modified during `move_and_slide` calls. **Do not
multiply by delta when setting this property.**"* — i.e. `CLAUDE.md`'s rule is
still the 4.7 rule.

`move_and_slide()` takes **no arguments** in 4.x. (Godot 3's
`move_and_slide(velocity)` is on the instant-reject list in `CLAUDE.md`.)

### 4.2 `Node3D` — and the −Z question, settled

`Node3D.look_at()` in 4.7:

```gdscript
look_at(target: Vector3, up := Vector3(0, 1, 0), use_model_front := false) -> void
look_at_from_position(position: Vector3, target: Vector3,
                      up := Vector3(0, 1, 0), use_model_front := false) -> void
```

Description, verbatim: *"Rotates the node so that the local forward axis (**−Z**)
points toward the target position"*, and `use_model_front` chooses whether the
"+Z axis (asset front)" or the "−Z axis (camera forward)" is treated as forward.

**That is the citation for `CLAUDE.md`'s "−Z is forward" rule.** Every model in
this project is authored facing −Z, which matches `use_model_front = false`, the
default. If you ever pass `use_model_front = true` you will invert every bird in
the flock.

Also confirmed present: `position`, `rotation` (radians, parent space),
`rotation_degrees`, `quaternion`, `basis`, `scale`, `transform`,
`global_position`, `global_rotation`, `global_basis`, `global_transform`,
`rotation_order` (default 2), `top_level`, `visible`, `visibility_parent`,
`rotate/rotate_x/rotate_y/rotate_z/rotate_object_local/global_rotate`,
`translate/global_translate/translate_object_local`, `to_local`, `to_global`,
`orthonormalize`, `set_identity`, `show`, `hide`, `is_visible_in_tree`,
`force_update_transform`, `get_global_transform_interpolated`,
`get_parent_node_3d`, `get_world_3d`, and the `visibility_changed` signal.

### 4.3 `SurfaceTool` / `ArrayMesh` — `scripts/goose/lowpoly_builder.gd`

The winding rule is **still true in 4.7** and is stated in the class reference
itself:

> "Godot uses clockwise winding order for front faces of triangle primitive
> modes."

That single sentence is the whole justification for `_emit()` reversing its
vertex order. See §5.2.

Confirmed signatures for everything the builder uses:

```gdscript
begin(primitive: int)                     # Mesh.PRIMITIVE_TRIANGLES
set_normal(normal: Vector3)
set_color(color: Color)                   # needs vertex_color_use_as_albedo on the material
set_uv(uv: Vector2)
add_vertex(vertex: Vector3)               # call LAST, after the attribute setters
commit(existing: ArrayMesh = null, flags: int = 0) -> ArrayMesh
```

Also confirmed available and not used here: `set_uv2`, `set_tangent`,
`set_smooth_group` (0 = smooth, **−1 = flat**), `set_bones`, `set_weights`,
`set_custom`/`set_custom_format`, `set_material`, `add_index`, `add_triangle_fan`,
`index`, `deindex`, `optimize_indices_for_cache`, `create_from`,
`create_from_arrays`, `create_from_blend_shape`, `append_from`, `clear`,
`generate_normals(flip := false)`, `generate_tangents`, `commit_to_arrays`,
`get_aabb`, `get_primitive_type`, `get_skin_weight_count`/`set_skin_weight_count`.

**Deprecated in 4.7:** `SurfaceTool.generate_lod()` — "Unused internally; does not
preserve normals or UVs. Consider `ImporterMesh.generate_lods` instead."

Note: the builder gives every triangle its own three vertices and sets an explicit
normal, so it never calls `generate_normals()` and never needs
`set_smooth_group(-1)`. Both are correct — don't "optimise" one into the other.

### 4.4 `CanvasItem._draw()` — the UI

Signatures in §1.1. Also confirmed for 4.7:

```gdscript
draw_string(font: Font, pos: Vector2, text: String, alignment := 0, width := -1,
            font_size := 16, modulate := Color(1,1,1,1), justification_flags := 3,
            direction := 0, orientation := 0, oversampling := 0.0)
draw_string_outline(font, pos, text, alignment := 0, width := -1, font_size := 16,
            size := 1, modulate := Color(1,1,1,1), justification_flags := 3,
            direction := 0, orientation := 0, oversampling := 0.0)
draw_colored_polygon(points: PackedVector2Array, color: Color,
            uvs := PackedVector2Array(), texture: Texture2D = null)
draw_set_transform(position: Vector2, rotation := 0.0, scale := Vector2(1, 1))
draw_style_box(style_box: StyleBox, rect: Rect2)
draw_dashed_line(from, to, color, width := -1.0, dash := 2.0, aligned := true,
            antialiased := false)
draw_multiline(points: PackedVector2Array, color: Color, width := -1.0,
            antialiased := false)
```

`results_screen.gd` uses `draw_arc`, `draw_circle`, `draw_colored_polygon`,
`draw_polyline`, `draw_rect`, `draw_set_transform`, `draw_string`,
`draw_string_outline`, `draw_style_box` — all of the above, all still current.

### 4.5 `Control` / `CanvasLayer` — the UI layer stack

Confirmed in 4.7: `set_anchors_preset(preset: int, keep_offsets := false)`,
`set_anchors_and_offsets_preset(preset, resize_mode := 0, margin := 0)`, `size`,
`custom_minimum_size`, `pivot_offset`, `mouse_filter`, `size_flags_horizontal`,
and the four theme-override calls this project leans on heavily:

```gdscript
add_theme_color_override(name: StringName, color: Color)
add_theme_constant_override(name: StringName, constant: int)
add_theme_font_size_override(name: StringName, font_size: int)
add_theme_stylebox_override(name: StringName, stylebox: StyleBox)
```

`ThemeDB` is confirmed present with `fallback_font`, `fallback_font_size`
(default 16), `fallback_base_scale` (1.0), `fallback_icon`, `fallback_stylebox`,
`get_default_theme()`, `get_project_theme()`. The project's 14 uses of
`ThemeDB.fallback_font` are current API.

See §1.10 for the new offset-transform properties, which are the right tool for
new UI animation.

**Measured on 4.7.1, 2026-09-25, by printing the engine — not remembered** (D-055,
D-056):

- **The built-in `ui_*` actions have no pad buttons for accept or cancel.**
  `ui_cancel` is Escape alone; `ui_accept` is Enter, Keypad Enter and Space;
  `ui_select` is Space and pad Y; `ui_up/down/left/right` do carry the D-pad and
  the left stick. Older Godot put pad A and B on accept and cancel, and two of this
  repo's own documents still said so. `Game._setup_input()` adds Start and A.
- **`Slider` has no `custom_step`.** `ClassDB` lists `Range` as `min_value,
  max_value, step, page, value, ratio, exp_edit, rounded, allow_greater,
  allow_lesser` and `Slider` as `editable, scrollable, tick_count,
  ticks_on_borders, ticks_position`. Assigning `custom_step` compiles — a property
  write on a native type is resolved at run time, so `--gate` cannot see it — and
  raises `SCRIPT ERROR` when it runs. A focused slider moves by `step` on the arrow
  keys and the D-pad.
- **Hiding a `CanvasLayer` releases focus from any Control inside it.** Measured by
  disabling an explicit `release_focus()` and seeing nothing focused anyway.
- **Pad buttons do not auto-repeat;** held keys send echoes. `is_action_pressed(a,
  true)` accepts the echoes.
- **Headless, `Input.parse_input_event()` mouse events never reach GUI picking**;
  `get_viewport().push_input(ev, true)` does. A full-screen Button clicked at its
  centre was pressed 0 times the first way and once the second. Keys and actions
  sent with `parse_input_event()` do reach `_input()`, GUI focus navigation and
  `_unhandled_input()` — it is mouse picking specifically. Headless also never
  honours `MOUSE_MODE_CAPTURED`.
- **`MOUSE_FILTER_STOP` does not stop a mouse WHEEL.** Only a Control that consumes
  the wheel (ScrollContainer, Slider) does; a wheel pushed through a full-screen
  STOP Control still reached `_unhandled_input`. A click through it did not.

### 4.6 `Tween`

All of these are confirmed in 4.7:

```gdscript
tween_property(object, property: NodePath, final_val, duration) -> PropertyTweener
tween_callback(callback: Callable) -> CallbackTweener
tween_interval(time: float) -> IntervalTweener
tween_method(method: Callable, from, to, duration) -> MethodTweener
tween_subtween(subtween: Tween) -> SubtweenTweener
tween_await(signal: Signal) -> AwaitTweener          # NEW in 4.7
chain() -> Tween
parallel() -> Tween
set_parallel(parallel := true) -> Tween
set_loops(loops := 0) -> Tween                       # no args = infinite
set_trans(trans) -> Tween                            # default TRANS_LINEAR
set_ease(ease) -> Tween                              # default EASE_IN_OUT
set_pause_mode(mode) -> Tween                        # default TWEEN_PAUSE_BOUND
set_process_mode(mode) -> Tween                      # default TWEEN_PROCESS_IDLE
set_speed_scale(speed: float) -> Tween
set_ignore_time_scale(ignore := true) -> Tween
bind_node(node: Node) -> Tween
kill() / pause() / play() / stop() -> void
custom_step(delta: float) -> bool
is_valid() / is_running() / has_tweeners() -> bool
get_total_elapsed_time() -> float ; get_loops_left() -> int
Tween.interpolate_value(...)                          # static
```

Two things the docs state that matter here:

1. *"Tweens created manually (i.e. by using `Tween.new()`) are invalid and can't be
   used for tweening values."* Always `create_tween()` on a Node or SceneTree —
   which is what every call site in this repo does.
2. *"When you bind a Node with the Tween, the Tween will halt the animation when
   the object is not inside tree and the Tween will be automatically killed when
   the bound object is freed."* `Node.create_tween()` binds to that node, which is
   why `tw.tween_callback(queue_free)` at the end of a chain in `mission_hud.gd`
   is safe.

3. **`set_ignore_time_scale(true)` is the correct fix for menu tweens.**
   This project instead divides `delta` by `Engine.time_scale` by hand in nine
   places (`hud.gd`, `briefing.gd`, `results_screen.gd`, `flock_roster.gd`,
   `pause_menu.gd`). That is hand-rolled and it works, but for any *new* tween in
   a menu, `set_ignore_time_scale(true)` is the supported API. Do not retrofit the
   existing hand-rolled sites without being asked — see `CLAUDE.md` on scope.

### 4.7 Audio — `sfx.gd`, `music.gd`, `honk.gd`, `prefs.gd`

`AudioStreamPlayer` (non-positional): `autoplay` (false), `bus` (`"Master"`),
`max_polyphony` (1), `mix_target` (0), `pitch_scale` (1.0), `playback_type` (0),
`playing` (false), `stream`, `stream_paused` (false), `volume_db` (0.0),
`volume_linear`; methods `play(from_position)`, `stop()`, `seek(to_position)`,
`get_playback_position()`, `get_stream_playback()`, `has_stream_playback()`.
**No `area_mask`.**

`AudioStreamPlayer3D` adds: `area_mask` (**default 0** — see §1.4), `unit_size`
(10.0), `max_distance` (0.0), `max_db` (3.0), `attenuation_model` (0),
`panning_strength` (1.0), `doppler_tracking` (0). `play()` is documented as
*"Queues the audio to play on the next physics frame"* — it is not instantaneous.

`AudioStreamWAV` (what `tools/gen_audio.py` and `gen_music.py` emit): `data`
(PackedByteArray), `format` (`AudioStreamWAV.Format`), `loop_begin`, `loop_end`,
`loop_mode` (`AudioStreamWAV.LoopMode`), `mix_rate` (44100), `stereo` (false);
statics `load_from_file(path, options := {})`, `load_from_buffer(stream_data,
options := {})`; `save_to_wav(path) -> Error`.
`Format`: `FORMAT_8_BITS`=0, `FORMAT_16_BITS`=1, `FORMAT_IMA_ADPCM`=2,
`FORMAT_QOA`=3. `LoopMode`: `LOOP_DISABLED`=0, `LOOP_FORWARD`=1,
`LOOP_PINGPONG`=2, `LOOP_BACKWARD`=3. `gen_music.py`'s comment "loop_mode=1 is
LOOP_FORWARD" is correct.

`playback_type` on both players is marked **experimental** in the 4.7 docs. Do not
start using it.

### 4.8 `ResourceLoader` / `ResourceUID` / `DirAccess`

```gdscript
ResourceLoader.load(path: String, type_hint := "", cache_mode := 1) -> Resource
ResourceLoader.exists(path: String, type_hint := "") -> bool
ResourceLoader.load_threaded_request(path, type_hint := "", use_sub_threads := false, cache_mode := 1) -> Error
ResourceLoader.load_threaded_get(path) -> Resource
ResourceLoader.load_threaded_get_status(path, progress := []) -> ThreadLoadStatus
ResourceLoader.get_cached_ref(path) -> Resource
ResourceLoader.has_cached(path) -> bool
ResourceLoader.list_directory(directory_path) -> PackedStringArray
ResourceLoader.get_resource_uid(path) -> int          # -1 if none
ResourceLoader.set_abort_on_missing_resources(abort: bool)
```

`CacheMode`: `CACHE_MODE_IGNORE`=0 (main + subresources bypass cache, dependencies
use REUSE), `CACHE_MODE_REUSE`=1 (**the default**), `CACHE_MODE_REPLACE`=2,
`CACHE_MODE_IGNORE_DEEP`=3, `CACHE_MODE_REPLACE_DEEP`=4.

`tools/gate.gd` relies on all five of those distinctions and its comment about
`CACHE_MODE_IGNORE_DEEP` re-parsing the preload graph is consistent with the
documented "IGNORE behavior applied recursively through dependency tree".

`ResourceLoader.list_directory()` is the shipping-safe directory listing;
`DirAccess` does not see inside an exported PCK the same way. `substance_manager.gd`
uses `DirAccess.open("res://data/substances")` — that works in the editor and in a
`--path` run, and is a known limitation for export. `tools/gate.gd` uses
`DirAccess` deliberately and documents why (dev tooling, never exported).

`ResourceUID` — "A singleton that manages the unique identifiers of all resources
within a project." `create_id()` generates "a random resource UID which is
guaranteed to be unique within the list of currently loaded UIDs";
`create_id_for_path()` seeds it with the path and project name; `id_to_text()`
converts to a `uid://` string; `text_to_id()` extracts the value; `get_id_path()`,
`set_id()`, `add_id()`, `remove_id()`, `has_id()`, `ensure_path()`, and the
`INVALID_ID` constant "for example if the resource could not be loaded".

This is the API-level reason `CLAUDE.md` says never to invent a `uid://` value:
UIDs are *allocated* by the engine into a cache, not chosen. A made-up one either
collides or resolves to nothing.

### 4.9 Shaders — `shaders/screen_fx.gdshader`

Confirmed for a `canvas_item` shader in 4.7:

- Render modes include `blend_mix`, `blend_add`, `blend_sub`, `blend_mul`,
  `blend_premul_alpha`, `blend_disabled`, **`unshaded`** (what this shader uses),
  `light_only`, `skip_vertex_transform`, `world_vertex_coords`.
- `fragment()` built-ins include `SCREEN_UV`, `COLOR`, `UV`, `SCREEN_PIXEL_SIZE`.
  `TIME` is a global built-in available everywhere, not a fragment-only one.
- **`SCREEN_TEXTURE` is removed.** The docs say verbatim: *"Removed in Godot 4.
  Use a `sampler2D` with `hint_screen_texture` instead."* Which is exactly what
  `screen_fx.gdshader` line 12 does:
  `uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;`

I could **not** find documentation for the `repeat_disable` / `filter_linear` hint
qualifiers on the canvas_item shader page — they are documented elsewhere in the
shading-language reference, which I did not fetch. They compile and work in this
project, so leave them alone; just don't cite this file as having verified them.

### 4.10 Physics bodies

`CollisionShape3D.disabled`, verbatim: *"A disabled collision shape has no effect
in the world. **This property should be changed with `Object.set_deferred`.**"*
That is the doc citation for `CLAUDE.md`'s rule. (The docs do not add a separate
warning about physics callbacks; the `set_deferred` sentence is the whole of it.)

`RigidBody3D.contact_monitor`, verbatim: *"If `true`, the RigidBody3D will emit
signals when it collides with another body. **Note:** By default the maximum
contacts reported is set to 0, meaning nothing will be recorded, see
`max_contacts_reported`."*

`RigidBody3D.max_contacts_reported`, verbatim: *"The maximum number of contacts
that will be recorded. **Requires a value greater than 0** and `contact_monitor`
to be set to `true` to start to register contacts."*

`body_entered` / `body_exited` / `body_shape_entered` each repeat the requirement.
So `CLAUDE.md`'s "`contact_monitor = true` does nothing until
`max_contacts_reported > 0`" is confirmed verbatim by the 4.7 class reference.

### 4.11 Singletons this project uses, all current in 4.7

`Engine.time_scale` · `Time.get_ticks_msec()` (**not** `OS.get_ticks_msec()`,
which is Godot 3) · `Input.mouse_mode` / `is_action_pressed` /
`is_action_just_pressed` / `get_vector` / `get_action_strength` /
`is_mouse_button_pressed` / `parse_input_event` · `OS.get_cmdline_user_args()` ·
`AudioServer.*` (bus creation, effects, volume) · `ThemeDB.fallback_font` ·
`RenderingServer.frame_post_draw` (signal) · `ResourceLoader.*` · `DirAccess.open`.

---

## 5. The traps that have actually bitten *this* project

These are not general Godot advice. Each one has a scar in this repo.

### 5.1 🔴 `var x := <anything Variant>` is a parse error

```gdscript
var x := some_dictionary.key          # PARSE ERROR — cannot infer the type of x
var y := node.some_untyped_property   # same
var z := TABLE[i][0]                  # same
```

Anything out of a **Dictionary**, an **Array element**, an **untyped Node
property**, or `.get()` is a `Variant`, and `:=` cannot infer from a Variant.
Annotate instead:

```gdscript
var x: float = some_dictionary.key
```

`Subs.mods`, `Subs.brain`, `Flock.birds[i]`, `COMBOS[...]` and every `params`
dictionary in the model builders are Dictionaries. Every read out of them needs an
explicit type. `if c is Foo:` does **not** narrow a Variant loop variable — annotate
the property read, not the loop.

This is the single most common way this codebase breaks. It is also the error that
proved the old compile gate was fake: `tools/gate.gd` records that a file
containing exactly this error passed
`godot --headless --path . --import | grep ERROR` in silence, on 2026-08-04.

**Honesty note:** the 4.7 static-typing docs page describes `:=` inference and
describes `Variant`, but does **not** contain an explicit statement that inference
from a Variant is an error, and I could not find the error string quoted anywhere
in the docs. The rule above is confirmed by this project's own repeated
experience, not by a doc citation. It is nonetheless true.

### 5.2 🔴 Front faces are CLOCKWISE — the builder reverses winding on purpose

`SurfaceTool`'s own 4.7 class reference: *"Godot uses clockwise winding order for
front faces of triangle primitive modes."*

That is the **opposite handedness** to the right-hand-rule normal
`(b-a).cross(c-a)` that every mesh routine naturally computes. So
`lowpoly_builder.gd::_emit()` emits `a, c, b` while keeping the computed normal:

```gdscript
for v in [a, c, b]:
    _st.set_normal(n)
    ...
```

Emitting in natural order produces geometry that is correct, shades plausibly, and
is **entirely back-facing** — invisible on open surfaces, silently lit from the
wrong side on closed ones. That bug shipped once. **Do not "simplify" that loop.**

Corollary, and this is current as of 2026-08-04: because the builder is fixed at
source, every downstream material is `CULL_BACK`. Confirmed:
`lowpoly_builder.gd:274`, `prop_models.gd:150`, `prop_models_cottage.gd:131,147`,
`prop_models_finale.gd:98`. The only `CULL_DISABLED` in the project are
`tex.gd:102` and the finale's water fan (`prop_models_finale.gd:114`), both
deliberate and commented. **If you ever see a builder-produced mesh set
`CULL_FRONT`, that is a bug, not a workaround.** `docs/prop_models_notes.md` used
to say the opposite; it was corrected on 2026-08-04.

### 5.3 🔴 `-Z` is forward. `basis.z` is BACK

Cited in §4.2 from `Node3D.look_at`. `CLAUDE.md` notes that the "Using 3D
transforms" tutorial page contains a sentence claiming Z is forward; the class
reference is the authority and it says −Z. Every model in this project is authored
facing −Z. A goose was once built facing +Z and flew tail-first for three builds
while "correctly" turning toward its heading.

### 5.4 🟠 `is_on_floor()` **before** `move_and_slide()` returns last tick's state

The 4.7 doc is explicit: `is_on_floor()` "Returns `true` if the body collided with
the floor **on the last call of `move_and_slide`**". Same for `is_on_wall`,
`is_on_ceiling`, `get_floor_normal`, `get_wall_normal`, `get_platform_velocity`,
`get_real_velocity`. Reading any of them before this frame's `move_and_slide()`
gives you last frame's answer. `goose_controller.gd` reads `is_on_floor()` at line
345 and calls `move_and_slide()` at 274 — check the ordering before you move code
between those.

### 5.5 🟠 `class_name` vs `preload`

Prefer `const X := preload("res://path.gd")` over a bare `class_name` reference.
Global class registration only exists after an editor import pass, so a
`class_name` reference breaks in a fresh checkout and in headless CI.
`prop_models.gd:49` does this and says why.

`class_name` is also **one flat global namespace** shared with every engine class
and every autoload — grep before adding one, duplicates are silent and last-wins.

This also has a gate consequence: `tools/gate.gd` has to strip `class_name` from
its parse copy, because the real script is already registered under that name and
leaving the declaration in produces nine false failures of the form
`Class "Cat" hides a global script class`.

### 5.6 🟠 `.owner = root` on every node a builder creates

In a builder script, every non-root node needs `.owner = root` or it is silently
dropped when the scene is saved. This only bites when someone converts a
code-built zone to a real `.tscn` — which is on the roadmap.

### 5.7 🟠 Never invent a `uid://`

See §4.8. Omit `uid=` from anything you author; never copy a `.tscn`/`.tres`
without deleting the `uid=` from its header; `git mv` a `.gd` together with its
`.gd.uid` sidecar in the same commit.

### 5.8 🟠 `CollisionShape3D.disabled` → `set_deferred`

Confirmed verbatim in §4.10.

### 5.9 🟠 `contact_monitor` needs `max_contacts_reported > 0`

Confirmed verbatim in §4.10.

### 5.10 🟡 The compile gate

`--import` does **not** compile GDScript. The 4.7 command-line reference describes
it as: *"Starts the editor, waits for any resources to be imported, and then
quits."* Resources, not scripts. And `--check-only` is documented as *"Only parse
for errors and quit (use with `--script`)"* — which parses **one file in
isolation**, so every script touching an autoload reports
`Compile Error: Identifier not found: Subs`.

**There is no documented Godot command-line option that compiles every GDScript in
a project.** That is why `tools/gate.gd` exists. The gate is:

```
godot --headless --path . -- --gate
```

Exit 0 = clean, exit 1 = something did not compile. Read `tools/gate.gd`'s header
comment before changing anything about it.

---

## 6. How to check an API you are unsure about

### 6.1 The URL pattern

```
https://docs.godotengine.org/en/4.7/classes/class_<lowercased_classname>.html
```

e.g. `class_characterbody3d.html`, `class_surfacetool.html`,
`class_audiostreamplayer3d.html`. No underscores inside the class name —
`CharacterBody3D` → `characterbody3d`.

Tutorials and migration guides:
```
https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html
https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.6.html
https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.5.html
```

### 6.2 How to tell a 4.7 page from a 4.6 page

Three checks, cheapest first:

1. **The URL.** `/en/4.7/` is 4.7. `/en/4.6/` is not. `/en/stable/` currently
   resolves to 4.7 — but "currently" is doing work in that sentence; it will move
   to 4.8 without warning, so **always pin `/en/4.7/` in anything you write down.**
   `/en/latest/` tracks the development branch and is ahead of any release.
2. **The page banner / title.** A 4.7 page's title is "… — Godot Engine (4.7)
   documentation in English" and the docs home reads "Godot Docs – 4.7 branch".
   The page metadata carries `meta-doc_version: 4.7`.
3. **A version-mismatch banner.** If you followed a search result and landed on an
   older branch, Sphinx shows a notice at the top of the page. Do not ignore it.

A search-engine result is very likely to be a 4.2 or 4.4 page. Rewrite the URL to
`/en/4.7/` and reload before believing anything on it.

### 6.3 The trick that actually works for an agent

**The rendered HTML class pages are mostly navigation sidebar.** A fetch of
`class_characterbody3d.html` returns hundreds of nav links and gets truncated
before it reaches a single method signature. Two of my first four fetches failed
this way.

Fetch the **source** instead. It is plain text, has no chrome, and is the exact
input the HTML is generated from:

```
# Class reference (XML, from the engine repo, pinned to the release tag):
https://raw.githubusercontent.com/godotengine/godot/4.7-stable/doc/classes/CharacterBody3D.xml
https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/doc/classes/Tween.xml

# Tutorials and migration guides (reStructuredText, from the docs repo):
https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/migrating/upgrading_to_godot_4.7.rst
https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/editor/command_line_tutorial.rst
```

Class name in the XML path is the **real** CamelCase name, not lowercased.
Everything in §4 of this file was gathered that way.

Note: direct `curl` to `docs.godotengine.org` is blocked by the egress proxy in the
Cowork container (403 on CONNECT). `WebFetch` works. `raw.githubusercontent.com`
works for both.

### 6.4 The procedure

1. Is it in §4 of this file? Then use it, don't re-check.
2. Otherwise fetch the class XML at the `4.7-stable` tag (§6.3).
3. If the answer looks different from what you expected, check
   `upgrading_to_godot_4.7.rst`, then `4.6`, then `4.5` — a thing you "remember"
   that is now wrong will be in one of those three tables.
4. Write what you found into §4 of this file, with the date.
5. **Then compile it**: `godot --headless --path . -- --gate`. The docs tell you
   the signature; only the gate tells you the project still builds.
6. **Then render it**, if it is visual. `CLAUDE.md` is right about this: the first
   render is always wrong.

---

## 7. What I could not verify

Stated plainly, because the point of this file is that you can trust the rest of it.

1. **Which 3D physics engine this project runs.** Godot 4.6 changed the default to
   Jolt Physics *for newly created projects*. This repo's `project.godot` has a
   `[physics]` section with `common/physics_ticks_per_second` and
   `3d/default_gravity` but **no `3d/physics_engine` key**, so the engine's
   built-in default applies, and I could not determine what that default is for an
   existing project in 4.7 without running the engine (there is no Godot binary in
   this container). Everything in §1.6 is conditional on the answer. **Find out
   before touching physics**: print `ProjectSettings.get_setting("physics/3d/physics_engine")`
   at runtime, or check Project Settings → Physics → 3D → Physics Engine.

2. **The exact 4.7 release day.** The 4.7.1 announcement says 4.7 shipped
   "approximately four weeks" before 14 July 2026. `CLAUDE.md` says 18 June 2026.
   Consistent, but not independently confirmed.

3. **The GDScript "cannot infer the type" error itself.** See the honesty note in
   §5.1 — the behaviour is certain from this project's history, but I could not
   find it stated in the 4.7 static-typing documentation, so I cannot give you a
   doc citation for it.

4. **`repeat_disable` / `filter_linear` shader hint qualifiers.** Used in
   `screen_fx.gdshader` and working, but the canvas_item shader page I fetched does
   not document them; they live in the shading-language reference, which I did not
   read. Not verified here.

5. **`RenderingServer.frame_post_draw`.** Used in 11 places in this project. I did
   not fetch `RenderingServer.xml` (it is enormous) so this one is *not* confirmed
   against 4.7 — it is simply working in the current build.

6. **Whether the 4.7 upgrade guide's Breaking-changes tables are complete as I
   reproduced them.** I read them via a text conversion of the `.rst` source. I
   believe §1.9 is complete for Core/2D/3D/GUI/Text/Rendering/Animation/Physics/
   Audio/XR/Editor, but a table row could have been dropped in conversion. If a
   signature surprises you, go back to the source (§6.3) rather than trusting §1.9.

7. **I could not run the gate.** No Godot binary is available in this container, so
   nothing in this file has been compile-checked against the actual engine. It is
   a documentation change only; it touches no code.

---

## 8. Sources

Everything cited above came from one of these, fetched 2026-08-04:

- `https://docs.godotengine.org/en/4.7/` — docs home, version confirmation
- `https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/migrating/upgrading_to_godot_4.7.rst`
- `https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/migrating/upgrading_to_godot_4.6.rst`
- `https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/migrating/upgrading_to_godot_4.5.rst`
- `https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/editor/command_line_tutorial.rst`
- `https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/shaders/shader_reference/canvas_item_shader.rst`
- `https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/scripting/gdscript/static_typing.rst`
- `https://raw.githubusercontent.com/godotengine/godot/4.7-stable/doc/classes/{CharacterBody3D,Node3D,SurfaceTool,CanvasItem,Control,Tween,AudioStreamPlayer,AudioStreamPlayer3D,AudioStreamWAV,ResourceLoader,ResourceUID,RigidBody3D,CollisionShape3D,ThemeDB}.xml`
- `https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/version.py`
- `https://godotengine.org/releases/4.7/` — release announcement
- `https://godotengine.org/article/maintenance-release-godot-4-7-1/` — 4.7.1 notes

And, for the project-specific half: this repo's own `CLAUDE.md`, `docs/HANDOFF.md`,
`tools/gate.gd`, `scripts/goose/lowpoly_builder.gd`, `scripts/goose/goose_controller.gd`,
`scripts/world/prop_models.gd`, `scripts/core/substance_manager.gd`,
`shaders/screen_fx.gdshader`, `scripts/ui/results_screen.gd` and `project.godot`.
