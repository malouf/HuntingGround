class_name BossDefinition
extends Resource

## Full data for one boss: stats, moveset, and phases. The fight reads this
## plus nothing else; BossController turns it into behavior.

@export var boss_id := ""
@export var display_name := ""
@export var notes := ""
@export var max_health := 160.0
## The boss stops walking and attacks at this distance.
@export var stance_distance := 2.4
@export var body_scale := 1.55
@export var weapon_prop_path := "res://scenes/weapons/sword.tscn"
@export var moves: Array[BossMove] = []
@export var phases: Array[BossPhase] = []

## Fresh per-instance lists so a loaded .tres that omits a field does not
## inherit Godot's read-only script default.
func _init() -> void:
	moves = []
	phases = []

## Index of the active phase for a health fraction (0.0 dead .. 1.0 full).
## The LAST phase whose hp_below is at or above the fraction wins.
func phase_index_for(health_fraction: float) -> int:
	var index := 0
	for i in phases.size():
		if health_fraction <= phases[i].hp_below:
			index = i
	return index

## Weighted pick among moves whose distance band contains the target and
## whose cooldown has expired. Falls back to the first cooled-down move so a
## boss never freezes; returns null only with an empty moveset.
func pick_move(distance: float, cooldowns: Dictionary) -> BossMove:
	var eligible: Array[BossMove] = []
	var weights: Array[float] = []
	for move in moves:
		if cooldowns.get(move.move_id, 0.0) > 0.0:
			continue
		if distance < move.min_range or distance > move.max_range:
			continue
		eligible.append(move)
		weights.append(maxf(move.weight, 0.0))
	if eligible.is_empty():
		for move in moves:
			if cooldowns.get(move.move_id, 0.0) <= 0.0:
				return move
		return moves[0] if not moves.is_empty() else null
	var total := 0.0
	for value in weights:
		total += value
	var roll := randf() * total
	for i in eligible.size():
		roll -= weights[i]
		if roll <= 0.0:
			return eligible[i]
	return eligible.back()

## Weighted pick among a move's follow-ups; null when there are none or all
## weights are 0.
func follow_up_for(move: BossMove) -> BossFollowUp:
	if move == null or move.follow_ups.is_empty():
		return null
	var total := 0.0
	for link in move.follow_ups:
		total += maxf(link.weight, 0.0)
	if total <= 0.0:
		return null
	var roll := randf() * total
	for link in move.follow_ups:
		roll -= maxf(link.weight, 0.0)
		if roll <= 0.0:
			return link
	return move.follow_ups.back()

func move_by_id(id: String) -> BossMove:
	for move in moves:
		if move.move_id == id:
			return move
	return null