class_name SkillDefinition
extends Resource

## A utility action a weapon can hold: no damage, a movement/defense behavior
## with tunable numbers. Authored as .tres in resources/skills/ and listed on
## each weapon that uses it. An attack entry points at one of its weapon's
## skills; a skill alone never occupies a gesture slot.

enum Kind { BACK_STEP, QUICK_DODGE }
const KIND_NAMES := ["BACK STEP", "QUICK DODGE"]

@export var skill_id := ""
@export var display_name := ""
@export var notes := ""
## Which behavior this skill runs (v1: back step, lateral quick dodge).
@export var kind := Kind.BACK_STEP
## Seconds the skill takes to perform. The auto-combo uses this as the step
## length when the skill runs as a follow-up. "We'll see later for more."
@export var cast_time := 0.35
## Invulnerable window while the skill plays (seconds).
@export var duration := 0.4
## How far the body moves (meters; dodge speed is fixed in the game).
@export var distance := 2.0
## Seconds locked in place after the skill ends.
@export var recovery := 0.35
@export var fatigue_cost := 14.0
## The designer picks the animation the engine knows how to play. Later this
## field points at real animation assets with no dock change.
@export var animation_id := ""
