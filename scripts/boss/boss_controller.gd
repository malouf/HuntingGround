class_name BossController
extends Node

## Runs one boss from a BossDefinition: stalk the player, pick a move,
## telegraph, strike, recover, chain follow-ups. Phases come from the health
## fraction. Timing: telegraph, active and recovery are divided by the
## phase's attack_speed; cadence and walk speed come straight from the phase.

signal move_started(move: BossMove)

enum State { STALK, TELEGRAPH, ACTIVE, RECOVER }

## Cadence floor an interrupt (trip) can never push the next move past.
const INTERRUPT_FLOOR := 2.2

var main: Node
var definition: BossDefinition
var boss: CharacterBody3D
var player: CharacterBody3D

var state: int = State.STALK
var phase_index := -1
var picked_move: BossMove
## Follow-up rolled at the end of the last move; starts after its delay.
var next_follow_up: BossFollowUp
var follow_up_delay := 0.0
var cadence_timer := 2.2
var telegraph_timer := 0.0
var active_timer := 0.0
var recover_timer := 0.0
var move_cooldowns := {}
## Bench freeze: hold every move timer in place. The boss walks but never
## picks or finishes a move, so a telegraph can be studied at leisure.
var frozen := false

func setup(main_ref: Node, boss_def: BossDefinition, boss_body: CharacterBody3D, player_body: CharacterBody3D) -> void:
	main = main_ref
	definition = boss_def
	boss = boss_body
	player = player_body
	cadence_timer = 2.2
	refresh_phase(true)

func process_boss(delta: float) -> void:
	if definition == null or not is_instance_valid(boss) or not is_instance_valid(player):
		return
	_tick_cooldowns(delta)
	refresh_phase()
	if frozen:
		return
	# Cadence ticks in every state, like the old attack_timer: the next
	# telegraph starts attack_cadence seconds after the previous one did.
	cadence_timer -= delta
	match state:
		State.STALK:
			_stalk_tick(delta)
			if cadence_timer <= 0.0:
				_start_move()
		State.TELEGRAPH:
			_telegraph_tick(delta)
		State.ACTIVE:
			_active_tick(delta)
		State.RECOVER:
			_recover_tick(delta)

## Cancels a committed move and delays the next one (trip finisher).
func interrupt() -> void:
	state = State.STALK
	telegraph_timer = 0.0
	active_timer = 0.0
	recover_timer = 0.0
	next_follow_up = null
	picked_move = null
	cadence_timer = maxf(cadence_timer, INTERRUPT_FLOOR)
	if is_instance_valid(boss):
		boss.velocity = Vector3.ZERO

## Bench: start a move immediately from stalk.
func force_move() -> void:
	if state != State.STALK:
		return
	_start_move()

## Applies the phase matching the current health fraction: body color, tilt,
## state label. Cheap enough to call every frame; changes apply on change.
func refresh_phase(force := false) -> void:
	if definition == null or definition.phases.is_empty():
		return
	var fraction := 1.0
	if main:
		fraction = clampf(main.boss_health / maxf(definition.max_health, 0.001), 0.0, 1.0)
	var index := definition.phase_index_for(fraction)
	if index == phase_index and not force:
		return
	phase_index = index
	var phase := definition.phases[index]
	if is_instance_valid(boss):
		boss.rotation_degrees.z = phase.tilt_degrees
		var body := boss.get_node_or_null("Body") as MeshInstance3D
		if body:
			var material := StandardMaterial3D.new()
			material.roughness = 0.88
			material.albedo_color = phase.body_color
			body.material_override = material
	if main and main.boss_state_label:
		main.boss_state_label.text = "%s  •  %s" % [definition.display_name.to_upper(), phase.state_text]

func current_phase() -> BossPhase:
	if definition == null or definition.phases.is_empty():
		return null
	return definition.phases[maxi(phase_index, 0)]

func _stalk_tick(delta: float) -> void:
	var distance := boss.global_position.distance_to(player.global_position)
	if distance > definition.stance_distance:
		var direction := boss.global_position.direction_to(player.global_position)
		boss.velocity = direction * current_phase().walk_speed
		if boss.is_inside_tree():
			boss.move_and_slide()
			_face_player()
	else:
		boss.velocity = Vector3.ZERO

func _telegraph_tick(delta: float) -> void:
	telegraph_timer -= delta
	if telegraph_timer > 0.0:
		return
	_apply_strike()
	var active_time := maxf(picked_move.active, 0.0) / current_phase().attack_speed
	if active_time <= 0.0:
		_finish_move()
		return
	active_timer = active_time
	state = State.ACTIVE

func _active_tick(delta: float) -> void:
	active_timer -= delta
	if active_timer <= 0.0:
		_finish_move()

func _recover_tick(delta: float) -> void:
	recover_timer -= delta
	if recover_timer <= 0.0:
		_finish_recovery()

func _start_move() -> void:
	var move: BossMove = null
	if next_follow_up != null:
		move = definition.move_by_id(next_follow_up.move_id)
		follow_up_delay = next_follow_up.delay
		next_follow_up = null
	if move == null:
		var distance := boss.global_position.distance_to(player.global_position)
		move = definition.pick_move(distance, move_cooldowns)
	if move == null:
		cadence_timer = current_phase().attack_cadence
		return
	picked_move = move
	move_cooldowns[move.move_id] = move.cooldown
	cadence_timer = current_phase().attack_cadence
	telegraph_timer = (follow_up_delay + move.telegraph) / current_phase().attack_speed
	follow_up_delay = 0.0
	state = State.TELEGRAPH
	move_started.emit(move)
	if main:
		main.set_status("DANGER  •  %s IS COMMITTING TO %s" % [definition.display_name.to_upper(), move.display_name.to_upper()])

## The hit lands once, at the start of the active window (or at telegraph end
## for moves with no active window, like the brute's strike).
func _apply_strike() -> void:
	if main == null or picked_move == null:
		return
	var distance := boss.global_position.distance_to(player.global_position)
	if distance >= picked_move.reach:
		return
	if picked_move.arc_degrees < 360.0:
		var to_player := boss.global_position.direction_to(player.global_position)
		var boss_forward := -boss.global_transform.basis.z
		if rad_to_deg(boss_forward.angle_to(to_player)) > picked_move.arc_degrees * 0.5:
			return
	main.take_boss_hit(picked_move.damage)

func _finish_move() -> void:
	var recover_time := maxf(picked_move.recovery, 0.0) / current_phase().attack_speed
	if recover_time > 0.0:
		recover_timer = recover_time
		state = State.RECOVER
		return
	_finish_recovery()

## At the move's end, roll its follow-up chain. A hit chains into the next
## telegraph after the link's delay; no hit goes back to stalking.
func _finish_recovery() -> void:
	next_follow_up = definition.follow_up_for(picked_move)
	picked_move = null
	if next_follow_up != null:
		_start_move()
		return
	state = State.STALK

func _tick_cooldowns(delta: float) -> void:
	for id in move_cooldowns.keys():
		move_cooldowns[id] = move_cooldowns[id] - delta
		if move_cooldowns[id] <= 0.0:
			move_cooldowns.erase(id)

func _face_player() -> void:
	if boss.is_inside_tree() and player.is_inside_tree():
		boss.look_at(Vector3(player.global_position.x, boss.global_position.y, player.global_position.z), Vector3.UP)