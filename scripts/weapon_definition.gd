class_name WeaponDefinition
extends Resource

## Full data contract for one weapon: identity, model, and how the shared
## gesture language (L / R / U / D, hold, circle) maps onto the tempo chain.

@export var weapon_id := ""
@export var display_name := ""
@export var model_path := ""
@export var notes := ""
@export var min_fatigue := 12.0
## Technique key -> AttackDefinition for chain swings 1 and 2 ("L", "R", "U", "D").
@export var moves := {}
## Technique key -> AttackDefinition for the slot-3 finisher
## ("L"/"R" heavy slash, "U" flurry, "D" backward step).
@export var finishers := {}
## Closed circle gesture attack (chain-scaled whirlwind for the sword).
@export var circle_move: AttackDefinition
