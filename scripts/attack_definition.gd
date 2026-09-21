class_name AttackDefinition
extends Resource

@export var attack_id := ""
@export var display_name := ""
@export var damage := 0.0
@export var fatigue_cost := 0.0
@export var recovery := 0.0
@export var hitbox_size := Vector3.ONE
@export var notes := ""
# Tempo chain phases in seconds, counted from the start of the swing.
@export var windup := 0.15
@export var active := 0.1
# Link window: a chained press inside [link_open, link_close] starts the next
# swing immediately and cancels the remaining recovery. Use 99.0/99.0 for
# attacks that never chain (finishers, defensive arts).
@export var link_open := 0.28
@export var link_close := 0.68
# Damage multiplier per chain slot (1..3).
@export var chain_scale := Vector3(1.0, 1.25, 1.6)
# Finishers and arts are isolated swings: no link window, no chaining.
@export var chains := true
# Effect key applied when this attack is the chain finisher
# (flurry / heavy_slash / back_step / whirlwind).
@export var finisher_id := ""
