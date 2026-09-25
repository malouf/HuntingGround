class_name WeaponController
extends Node

## Base combat controller for one equipped weapon. Owns the tempo chain state
## machine, routes gesture/keyboard inputs into chains, and applies damage
## through the main orchestrator's helpers. Weapon subclasses override the
## execute hooks (sword gestures, bow shots...).
##
## Every entry is an AttackDefinition. It may hold a skill, in which case the
## skill runs instead of an attack. After an entry runs, its follow-ups play as
## an automatic combo (no input), depth-first, carrying the opening hit's
## quality. The same four directions + circle drive every weapon.

signal status_message(text: String)

## Guard against a follow-up graph that loops back on itself.
const MAX_FOLLOW_UP_DEPTH := 8

var tempo := TempoChain.new()
var weapon: WeaponDefinition
var main: Node3D
var player: CharacterBody3D
var boss: CharacterBody3D
var last_technique := ""
var repeat_count := 0
var last_clockwise := false

## Queued auto-combo steps: {entry: AttackDefinition, time: float, quality: String}.
var follow_up_queue: Array = []
var follow_up_clock := 0.0

func setup(orchestrator: Node3D, weapon_def: WeaponDefinition, player_ref: CharacterBody3D, boss_ref: CharacterBody3D) -> void:
	main = orchestrator
	weapon = weapon_def
	player = player_ref
	boss = boss_ref
	tempo.chain_died.connect(_on_chain_died)

func process_weapon(delta: float) -> void:
	tempo.process(delta)
	_process_follow_ups(delta)
	_process_tick(delta)

func is_busy() -> bool:
	return tempo.is_busy() or not follow_up_queue.is_empty()

func is_committed() -> bool:
	return tempo.is_committed() or not follow_up_queue.is_empty()

func is_recovering() -> bool:
	return tempo.is_recovering()

func is_staggered() -> bool:
	return tempo.staggered()

## True while the hunter cannot move: rooted during any swing, during an
## auto-combo, and while staggered. Slot-3 recoveries and skills leave the chain
## aborted, so movement is free right after those.
func movement_locked() -> bool:
	if tempo.staggered():
		return true
	if not follow_up_queue.is_empty():
		return true
	if not tempo.is_busy():
		return false
	return not (tempo.is_recovering() and tempo.slot() >= 3)

func technique_from_input(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "R" if direction.x > 0.0 else "L"
	return "U" if direction.y < 0.0 else "D"

func on_gesture(value: Vector2, gesture: String, clockwise: bool) -> void:
	if gesture == "circle":
		handle_circle(clockwise)
		return
	if value.length() < 0.32:
		return
	request_technique(technique_from_input(value))

func request_technique(technique: String) -> void:
	if not _fighters_valid():
		return
	var state := tempo.offer_input()
	match state:
		"just":
			_chain_input(technique, true)
		"window_early":
			_chain_input(technique, false)
		"idle":
			_start_fresh(technique)
		"early":
			tempo.kill_chain("early")
		"late":
			tempo.kill_chain("late")
		"staggered":
			status_message.emit("STAGGERED  •  REGAIN YOUR STANCE")
		_:
			pass

## Weapon-specific interpretation of a closed circle gesture.
func handle_circle(clockwise: bool) -> void:
	last_clockwise = clockwise
	request_technique("C")

## Per-frame weapon logic beyond the tempo chain (flurry ticks...).
func _process_tick(_delta: float) -> void:
	pass

func _fighters_valid() -> bool:
	return is_instance_valid(player) and player.is_inside_tree() \
		and is_instance_valid(boss) and boss.is_inside_tree()

func _start_fresh(technique: String) -> void:
	follow_up_queue.clear()
	follow_up_clock = 0.0
	var entry := _resolve_next_attack(technique)
	if entry == null:
		return
	if entry.skill != null:
		_run_skill(entry.skill, technique)
		_start_combo(entry, "")
		return
	if not main.can_pay(entry.fatigue_cost):
		status_message.emit("TOO TIRED  •  RECOVER FIRST")
		return
	tempo.start(technique, entry, false, TempoChain.TIER_NORMAL)
	_track_repeat(technique)
	_execute_move(entry, technique)
	_start_combo(entry, quality_text())

func _chain_input(technique: String, just: bool) -> void:
	# The finisher is always the 3rd input: the running swing is input 2.
	var is_finisher := tempo.slot() >= 2
	var entry := _resolve_next_attack(technique)
	if entry == null:
		return
	if entry.skill != null:
		# A skill is a standalone action: it cleanly ends the running chain and
		# plays the skill, then its follow-ups.
		tempo.abort()
		_run_skill(entry.skill, technique)
		_start_combo(entry, "")
		return
	if not main.can_pay(entry.fatigue_cost):
		tempo.kill_chain("fatigue")
		return
	tempo.chain_to(technique, entry, TempoChain.TIER_JUST if just else TempoChain.TIER_QUICK)
	var quality := quality_text()
	_track_repeat(technique)
	if is_finisher:
		_execute_finisher(entry, technique)
	else:
		_execute_move(entry, technique)
	_start_combo(entry, quality)

## The entry bound to a gesture position: press 1 reads `moves`, press 2 reads
## `second_moves` (falling back to the first), press 3 reads `finishers`.
func _resolve_next_attack(technique: String) -> AttackDefinition:
	if technique == "C":
		return weapon.circle_move as AttackDefinition
	match tempo.slot():
		1:
			return weapon.moves.get(technique) as AttackDefinition
		2:
			var second := weapon.second_moves.get(technique) as AttackDefinition
			return second if second != null else weapon.moves.get(technique) as AttackDefinition
		_:
			return weapon.finishers.get(technique) as AttackDefinition

## "CRITICAL" for a yellow-beat hit, "WEAK" for an off-beat hit, and "" for a
## normal hit (input 1).
func quality_text() -> String:
	if tempo.tier == TempoChain.TIER_JUST:
		return "CRITICAL"
	if tempo.tier == TempoChain.TIER_QUICK:
		return "WEAK"
	return ""

func _quality_tag() -> String:
	var quality := quality_text()
	if quality == "":
		return ""
	return "  •  %s" % quality

func _track_repeat(technique: String) -> void:
	if technique == last_technique:
		repeat_count += 1
	else:
		repeat_count = 1
		last_technique = technique

## Damage multiplier for the swing that is currently running. Input 1 is
## unscaled (always normal); input 2 uses the weapon's chain scale; weak hits
## take the quick-tier penalty. If the swing does not chain, the scale is skipped.
func _damage_multiplier(attack_data: AttackDefinition) -> float:
	var tier_factor := TempoChain.quick_scale if tempo.tier == TempoChain.TIER_QUICK else 1.0
	if not attack_data.chains:
		return tier_factor
	var scale: float = attack_data.chain_scale[mini(tempo.chain_index, 2)]
	var falloff := maxf(0.4, 1.0 - maxf(0, repeat_count - 1) * 0.16)
	return scale * tier_factor * falloff

func _on_chain_died(reason: String) -> void:
	last_technique = ""
	repeat_count = 0
	if reason == "early":
		tempo.stagger_timer = TempoChain.stagger_time
		status_message.emit("TOO EARLY  •  STAGGERED")
	elif reason == "late":
		tempo.stagger_timer = TempoChain.stagger_time
		status_message.emit("TOO LATE  •  STAGGERED")
	elif reason == "lapsed":
		tempo.stagger_timer = TempoChain.stagger_time
		status_message.emit("CHAIN DROPPED  •  STAGGERED")
	elif reason == "fatigue":
		tempo.stagger_timer = TempoChain.stagger_time
		status_message.emit("TOO TIRED  •  STAGGERED")

func _execute_move(_attack_data: AttackDefinition, _technique: String) -> void:
	pass

func _execute_finisher(_attack_data: AttackDefinition, _technique: String) -> void:
	pass

## Applies one auto-combo step: animation and hit only. No windup, no link
## window, no stagger — follow-ups live outside the rhythm chain.
func _execute_follow_up(_entry: AttackDefinition, _quality: String) -> void:
	pass

## Builds the auto-combo queue from an entry's follow-up list, depth-first:
## step 1 plays, then step 1's own follow-ups, then step 2, and so on. The
## opening hit's quality rides down the whole combo.
func _start_combo(root: AttackDefinition, quality: String) -> void:
	if root == null or root.follow_ups.is_empty():
		return
	follow_up_queue.clear()
	follow_up_clock = 0.0
	_schedule_follow_ups(root, 0.0, quality, 0)

func _schedule_follow_ups(entry: AttackDefinition, start_after: float, quality: String, depth: int) -> float:
	if depth >= MAX_FOLLOW_UP_DEPTH:
		return start_after
	var cursor := start_after
	for link in entry.follow_ups:
		var target := link.attack
		if target == null:
			continue
		var start := cursor + link.delay
		var duration := link.duration if link.duration > 0.0 else _entry_duration(target)
		follow_up_queue.append({"entry": target, "time": start, "quality": quality})
		cursor = _schedule_follow_ups(target, start + duration, quality, depth + 1)
	return cursor

func _entry_duration(entry: AttackDefinition) -> float:
	if entry != null and entry.skill != null:
		return maxf(entry.skill.cast_time, 0.05)
	return maxf(entry.windup + entry.active + entry.recovery, 0.05)

func _process_follow_ups(delta: float) -> void:
	if follow_up_queue.is_empty():
		return
	follow_up_clock += delta
	while not follow_up_queue.is_empty() and float(follow_up_queue[0]["time"]) <= follow_up_clock:
		var event: Dictionary = follow_up_queue.pop_front()
		_fire_follow_up(event["entry"], event["quality"])

func _fire_follow_up(entry: AttackDefinition, quality: String) -> void:
	if entry == null:
		return
	if entry.skill != null:
		_run_skill(entry.skill, "D")
		return
	if not _fighters_valid():
		return
	_execute_follow_up(entry, quality)

## Runs a skill as a standalone action: no tempo timing, no damage. Fatigue
## comes out of the same pool as attacks; invulnerable window and move distance
## come from the skill's own data. A dodge reads the same no matter which weapon
## fires it, so this lives in the base controller.
func _run_skill(skill: SkillDefinition, technique: String) -> void:
	if skill == null:
		return
	if not main.can_pay(skill.fatigue_cost):
		status_message.emit("TOO TIRED  •  RECOVER FIRST")
		return
	main.player_fatigue -= skill.fatigue_cost
	var step := _skill_direction(skill, technique)
	main.defensive_step(step)
	# The skill's own numbers win over the default roll: data-driven dodge.
	main.invulnerable_timer = skill.duration
	main.dodge_timer = skill.distance / 11.0
	status_message.emit("%s   •   INVULNERABLE" % skill.display_name.to_upper())

func _skill_direction(skill: SkillDefinition, technique: String) -> String:
	if skill.kind == SkillDefinition.Kind.BACK_STEP:
		return "back"
	match technique:
		"L":
			return "left"
		"R":
			return "right"
		"U", "D":
			return "back"
		_:
			return "left"
