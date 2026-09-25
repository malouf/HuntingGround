class_name BossMove
extends Resource

## One boss attack: a telegraph the player reads, then a hit, then recovery.
## All timings are seconds at attack_speed 1.0; the active BossPhase divides
## them by its attack_speed.

@export var move_id := ""
@export var display_name := ""
@export var notes := ""
## Seconds the boss stands still and reads as committed before the hit.
@export var telegraph := 0.75
## Seconds the hit window stays open. Damage lands once, at its start.
@export var active := 0.0
## Seconds the boss stays locked in place after the hit.
@export var recovery := 0.0
@export var damage := 18.0
## Hits the player within this distance of the boss.
@export var reach := 3.0
## Hit half-angle in degrees around the boss facing; 360.0 hits all around.
@export var arc_degrees := 360.0
## Pick weight when the boss chooses between moves in range.
@export var weight := 1.0
## Seconds this move cannot be picked again after use.
@export var cooldown := 0.0
## Distance band, stance to reach, in which the move can be picked.
@export var min_range := 0.0
@export var max_range := 99.0
## Moves that may chain right after this one, chosen by weight.
@export var follow_ups: Array[BossFollowUp] = []

## Hitbox the designer bench draws while telegraphing/striking. Designer-only
## visual; normal play never draws it (the telegraph flash is the in-game read).
## Shape: 0 = sphere, 1 = box, 2 = capsule。
@export var hitbox_shape := 1
## Size x/y/z in meters; the box center sits at about the boss's mid-body。
@export var hitbox_size := Vector3(2.2, 1.3, 3.4)
## Seconds the hitbox visual stays after the hit window closes。
@export var hitbox_lifetime := 0.15
##The designer picks the animation this move uses (starter set: brute_swing...）。
## Stored now; boss visual variety comes when a boss animation system exists。
@export var animation_id := ""

## Fresh per-instance list so a loaded .tres that omits follow_ups does not
## inherit Godot's read-only script default.
func _init() -> void:
	follow_ups = []