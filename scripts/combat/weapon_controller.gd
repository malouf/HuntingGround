class_name WeaponController
extends Node

## Base combat controller for one equipped weapon. Owns the tempo chain state
## machine, routes gesture/keyboard inputs into chains, and applies damage
## through the main orchestrator's helpers. Weapon subclasses override the
## execute hooks (sword gestures, bow shots...).

signal status_message(text: String)

var tempo := TempoChain.new()
var weapon: WeaponDefinition
var main: Node3D
var player: CharacterBody3D
var boss: CharacterBody3D
var last_technique := ""
var repeat_count := 0
var last_clockwise := false

func setup(orchestrator: Node3D, weapon_def: WeaponDefinition, player_ref: CharacterBody3D, boss_ref: CharacterBody3D) -> void:
	main = orchestrator
	weapon = weapon_def
	player = player_ref
	boss = boss_ref
	tempo.chain_died.connect(_on_chain_died)

func process_weapon(delta: float) -> void:
	tempo.process(delta)
	_process_tick(delta)

func is_busy() -> bool:
	return tempo.is_busy()

func is_committed() -> bool:
	return tempo.is_committed()

func is_recovering() -> bool:
	return tempo.is_recovering()

func is_staggered() -> bool:
	return tempo.staggered()

## True while the hunter cannot move: rooted during any swing (the whole
## windup/active/recovery) and rooted while staggered. Finishers unlock
## quicker — movement returns during their recovery.
func movement_locked() -> bool:
	if tempo.staggered():
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
			status_message.emit("STAGGERED • REGAIN YOUR STANCE")
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
	var attack_data: AttackDefinition = _resolve_next_attack(technique)
	if attack_data == null:
		return
	if not main.can_pay(attack_data.fatigue_cost):
		status_message.emit("TOO TIRED • RECOVER FIRST")
		return
	tempo.start(technique, attack_data, false, TempoChain.TIER_NORMAL)
	_track_repeat(technique)
	_execute_move(attack_data, technique)

func _chain_input(technique: String, just: bool) -> void:
	# The finisher is always the 3rd input: the running swing is input 2.
	var is_finisher := tempo.slot() >= 2
	var next_attack: AttackDefinition = _resolve_next_attack(technique)
	if next_attack == null:
		return
	if not main.can_pay(next_attack.fatigue_cost):
		tempo.kill_chain("fatigue")
		return
	tempo.chain_to(technique, next_attack, TempoChain.TIER_JUST if just else TempoChain.TIER_QUICK)
	_track_repeat(technique)
	if is_finisher:
		_execute_finisher(next_attack, technique)
	else:
		_execute_move(next_attack, technique)

func _resolve_next_attack(technique: String) -> AttackDefinition:
	if tempo.slot() >= 2:
		return weapon.finishers.get(technique)
	if technique == "C":
		return weapon.circle_move
	return weapon.moves.get(technique)

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
	return " • %s" % quality

func _track_repeat(technique: String) -> void:
	if technique == last_technique:
		repeat_count += 1
	else:
		repeat_count = 1
		last_technique = technique

## Damage multiplier for the swing that is currently running. Input 1 is
## unscaled (always normal); input 2 uses the weapon's chain scale; weak hits
## take the quick-tier penalty.
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
		status_message.emit("TOO EARLY • STAGGERED")
	elif reason == "late":
		tempo.stagger_timer = TempoChain.stagger_time
		status_message.emit("TOO LATE • STAGGERED")
	elif reason == "lapsed":
		tempo.stagger_timer = TempoChain.stagger_time
		status_message.emit("CHAIN DROPPED • STAGGERED")
	elif reason == "fatigue":
		tempo.stagger_timer = TempoChain.stagger_time
		status_message.emit("TOO TIRED • STAGGERED")

func _execute_move(_attack_data: AttackDefinition, _technique: String) -> void:
	pass

func _execute_finisher(_attack_data: AttackDefinition, _technique: String) -> void:
	pass