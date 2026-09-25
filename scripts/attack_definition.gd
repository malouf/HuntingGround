class_name AttackDefinition
extends Resource

## One attack entry a weapon binds to a gesture direction. It carries a chain
## layer (first / 2nd / finisher) and may hold an optional skill from the
## weapon's own skill list. When it holds a skill it is a skill entry: no
## attack, but its follow-ups still run.

enum ChainStage { FIRST, SECOND, FINISHER }
const STAGE_NAMES := ["FIRST", "2ND", "FINISHER"]

enum HitShape { SPHERE, BOX, CAPSULE }
const HIT_SHAPE_NAMES := ["SPHERE", "BOX", "CAPSULE"]

@export var attack_id := ""
@export var display_name := ""
## Which press this entry plays on: input 1 = first, input 2 = 2nd, input 3 =
## finisher (the finisher ends the chain).
@export var chain_stage := ChainStage.FIRST
## Optional skill from the weapon's skill list. When set this entry runs the
## skill instead of an attack; the timing below still drives the rhythm ring.
@export var skill: SkillDefinition
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
## The designer picks the animation this attack uses (slash directions, flurry,
## whirlwind, heavy slash). Later this field points at real animation assets with
## no dock change when a real animation pipeline exists.
@export var animation_id := ""

# How the hitbox is drawn and how long it stays open once spawned.
@export var hitbox_shape := HitShape.SPHERE
@export var hitbox_lifetime := 0.1
# Placeholder effect key; gameplay ignores it until a status system exists.
@export var status_effect := ""

## Full hit sequence for a multi-hit attack (5 rows for Flurry). Empty means
## a single hit using damage/active above.
@export var hits: Array[AttackHit] = []
## Ordered auto-combo steps played after this entry, depth-first. No input is
## needed; each step may chain into its own follow-ups.
@export var follow_ups: Array[AttackFollowUp] = []

## A loaded .tres that omits a list inherits the script default, which Godot
## locks read-only. Give every instance its own fresh list.
func _init() -> void:
	hits = []
	follow_ups = []
