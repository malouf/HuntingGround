# Architecture

## Principles

- Keep the first slice easy to inspect and modify.
- Prefer Godot scenes and Resources when content grows.
- Keep combat rules independent from menu presentation.
- Use signals for UI-to-gameplay requests.
- Avoid a global manager until shared state genuinely needs one.

## Current prototype

`main.tscn` contains the scripted root plus two explicit containers: `WorldRoot` for runtime 3D content and `InterfaceRoot` for runtime UI. The script builds the hub, loadout, arena, actors, camera, and HUD at runtime so the first playable slice has minimal asset and scene overhead.

`scripts/joystick.gd` emits continuous values, a release value, and a classified gesture. `scripts/camera_touch_area.gd` owns the upper-screen camera gesture so camera input cannot overlap the movement or attack joysticks.

The attack joystick selects sword technique only. Movement is converted from camera space, and the player's movement-facing direction is used as the sword hit direction. The gesture classifier supports directional branches and closed clockwise/counter-clockwise circles. The bow reuses the same joystick with hold duration for charge, a visible `arrow.tscn` projectile, opposite horizontal turning while nocked, and a multi-touch router for item/element swipes.

Visible reusable scenes now exist at `scenes/actors/player.tscn`, `scenes/actors/boss.tscn`, `scenes/weapons/sword.tscn`, `scenes/world/arena.tscn`, and `scenes/ui/mobile_hud.tscn`. Attack tuning resources live in `resources/weapons/` and use `scripts/attack_definition.gd`.

## Planned growth path

When the sword feel is approved, split the runtime prototype into:

- `scenes/world/hub.tscn`
- `scenes/ui/loadout.tscn`
- `scenes/hunts/hunt_arena.tscn`
- `scenes/actors/player.tscn`
- `scenes/actors/boss.tscn`
- `scenes/ui/mobile_hud.tscn`
- `scripts/combat/weapon_controller.gd`
- `scripts/combat/attack_definition.gd`
- `resources/weapons/*.tres`
- `resources/bosses/*.tres`

## Data contracts

A weapon definition should contain identity, model, attack directions, fatigue costs, timing windows, damage, range, and optional charge rules. A boss definition should contain health, movement, telegraphs, attacks, recovery windows, and unlock id.

## Save data

Use one small JSON save at `user://hunting_ground_save.json` for unlocked boss ids, selected weapon id, and future settings. Keep save migration simple by using default values when keys are missing.

## Mobile rules

Use portrait 720x1280 logical space with canvas stretching. Keep the camera and combat readable on a small screen, use compatibility rendering first, avoid per-frame allocations in combat, and test touch zones against a real Android build.

## UI input rules

Runtime UI lives on the `InterfaceRoot` CanvasLayer under `main.tscn`. It is a
flat stack, and Godot gives a click to the top-most control under the pointer:

1. `menu` (a full-rect `Control`, created first) — hub, loadout, result, and
   any panel the script builds.
2. HUD controls added by `make_fight_ui` — `camera_touch_area` (a Stop box over
   x 0-720, y 155-805), the two joysticks, and the DODGE / PAUSE / LOCK buttons.
3. `pause_overlay` (added last) — the pause menu.

So `menu` sits at the bottom of the click stack. A panel added to `menu` after
the HUD is built is **behind** the HUD, and its buttons cannot be clicked. That
was the Designer bench bug.

Rules:

- Put a new fight panel on its own `CanvasLayer` with a higher `layer` (the
  Designer bench uses `BenchLayer` at layer 2), or add it after the HUD and
  hide it while paused.
- Decorative backgrounds and overlays set `mouse_filter = IGNORE`. Only the
  controls that should take input stay at the default `STOP`.
- Give each screen one full-rect `Control` parent and add its buttons to that,
  instead of hanging buttons directly off a `CanvasLayer`.
- Keep long editor panels inside a `ScrollContainer` so no control is clipped
  out of reach.

Button won't click? Check, in order: the `pressed` signal is connected; no
`STOP` control is above it (camera touch area, joystick, overlay); the button
is inside a visible, sized `Control`; the control is not clipped or below the
fold; the terminal prints no errors while the scene runs.

A loaded resource keeps the script's default lists, and Godot marks those
read-only. `Array is in read-only state` / `Dictionary is in read-only state`
means a script tried to add to or remove from a default list. The schemas give
every instance fresh lists in `_init()`, and the designer panels still rebuild
a list before mutating it: `_fresh_hits`, `_fresh_follow_ups`, `_fresh_skills`,
`_fresh_moves`, `_fresh_phases` build a correctly typed copy. A plain fresh `[]`
is not enough — typed `Array[...]` properties reject it with "Invalid
assignment" — so the rebuild is always typed. Panels call it when a resource is
**selected** (`_sync_from_attack`, `_select_boss`, `_select_weapon`) and at
every add/remove. Any new list-touching code must go through it. Plain headless
tests do not always reproduce this, so a test should call `make_read_only()` on
the list and add through a freshly loaded `.tres` that omits the field.

## Attacks, skills, and the three chain layers — one joystick

Every gesture entry is an **AttackDefinition**. It carries a **chain layer** —
`FIRST`, `SECOND`, or `FINISHER` (the finisher is what ends the chain). A weapon
stores three direction dictionaries: `moves` (press 1), `second_moves`
(press 2), `finishers` (press 3), plus `circle_move`. `second_moves` falls back
to `moves` when a direction has no 2nd attack.

An attack may hold a **skill** (`skill`, an optional `SkillDefinition`) picked
from **the weapon's own `skills` list**, never the global folder. When a skill
is set the entry is a **skill entry**: no attack, and the dock hides the combat
fields (damage / hitbox / hits / status) while keeping the timing for the
rhythm ring. The runtime runs the skill instead of an attack. A skill alone
never occupies a slot; it always rides on an attack.

The dock's ASSIGN TO list is just **LEFT / RIGHT / UP / DOWN / CIRCLE**; the
entry's own chain layer decides which press it lands on. Rows read
`LEFT · FIRST — Slash Left`, `LEFT · 2ND — …`, `LEFT · FINISHER — …`.

## Follow-up auto-combo

Each attack carries an ordered `follow_ups` list of `AttackFollowUp` steps.
They play **automatically, with no input**, after the attack. A step points at
another attack (which may be a skill entry). Steps can nest: dive into a step's
own list **depth-first** — step 1, then 1's children, then step 2.

Timing is scheduled from each step's `delay` and `duration` (0 duration uses
the attack's own length, or the skill's cast time), so the whole combo plays
without hand-guessing total time. Follow-ups bypass the tempo ring entirely: no
windup, no link window, no stagger — they only apply the target's hit or its
skill. The opening hit's quality (**CRITICAL** / **WEAK**) rides down the whole
combo.

## Animation ids

Every attack, skill, and boss move carries an `animation_id` — a dropdown in
the dock over the example list (`slash_l/r/u/d`, `flurry`, `whirlwind`,
`heavy_slash`, `back_step`, `quick_dodge`, `brute_swing`, `brute_lunge`). The
runtime maps known ids to the engine's existing behaviors (`sword_controller`
uses `animation_id` to pick the swing direction and the finisher behavior —
flurry ticks, whirlwind hitbox). When real animation assets arrive, the same
string becomes the asset id — the dock does not change. Stored-but-unused is
fine; the field is the contract.

## Hitboxes are bench-only

`show_attack_hitbox` and `show_whirlwind_hitbox` gate on `debug_mode`: normal
fights never draw them. Boss moves carry `hitbox_shape / hitbox_size /
hitbox_lifetime`; the bench draws a translucent boss-red box in front of the
boss while he telegraphs or strikes (`_update_boss_hitbox_visual`), and it
lingers the move's `hitbox_lifetime` after the active window so FREEZE + study
works. In normal play the boss telegraph flash is the intended read — no box.

## Follow-up chooser

"+ ADD FOLLOW-UP" never creates a blank row. In the weapon panel it prefills
the step with an existing attack from `resources/weapons/`; in the boss panel
it does the same from the boss's own moves. A row can't point at "nothing".

## Verification

The prototype should be runnable in the editor and with the Godot command-line project check. Sword controls must be testable with both touch/mouse joystick input and keyboard fallback before additional weapons are added.
