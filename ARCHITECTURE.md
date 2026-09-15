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

## Verification

The prototype should be runnable in the editor and with the Godot command-line project check. Sword controls must be testable with both touch/mouse joystick input and keyboard fallback before additional weapons are added.
