class_name WeaponDefinition
extends Resource

## Full data contract for one weapon: identity, model, how the shared gesture
## language (L / R / U / D, hold, circle) maps onto the three chain layers, and
## the skills this weapon can use.

@export var weapon_id := ""
@export var display_name := ""
@export var model_path := ""
@export var notes := ""
@export var min_fatigue := 12.0
## Technique key -> AttackDefinition for the FIRST press ("L", "R", "U", "D").
@export var moves := {}
## Technique key -> AttackDefinition for the SECOND press. Falls back to the
## first-press entry when a direction has no 2nd attack.
@export var second_moves := {}
## Technique key -> AttackDefinition for the THIRD press (the finisher, which
## ends the chain).
@export var finishers := {}
## Closed circle gesture entry.
@export var circle_move: Resource
## Skills this weapon can use. An attack entry picks one of these — never from
## the global resources/skills folder directly.
@export var skills: Array[SkillDefinition] = []

## Fresh per-instance containers so a loaded .tres that omits a field does not
## inherit Godot's read-only script default.
func _init() -> void:
	moves = {}
	second_moves = {}
	finishers = {}
	skills = []
