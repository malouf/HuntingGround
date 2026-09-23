class_name SwordController
extends WeaponController

## Hunter's Sword: tempo chain of directional cuts. The 3rd input is always a
## finisher: UP = flurry, LEFT/RIGHT = heavy slash, DOWN = backward step,
## CIRCLE = heavy whirlwind. Circle also swings mid-chain as a chain-scaled
## whirlwind. Missing the yellow beat or dropping the chain staggers.

const FLURRY_TICK_INTERVAL := 0.13
const FLURRY_TICKS := 5

var flurry_ticks := 0
var flurry_timer := 0.0
var flurry_tick_damage := 0.0
var flurry_popup_emitted := false

func _process_tick(delta: float) -> void:
	super(delta)
	if flurry_ticks > 0:
		flurry_timer -= delta
		if flurry_timer <= 0.0:
			flurry_timer += FLURRY_TICK_INTERVAL
			flurry_ticks -= 1
			_flurry_tick()

func _flurry_tick() -> void:
	if not is_instance_valid(boss) or not is_instance_valid(player):
		flurry_ticks = 0
		return
	main.show_attack_hitbox(main.facing_direction, 2)
	if main.boss_distance() < 3.3 and main.boss_in_front():
		main.deal_boss_damage(flurry_tick_damage, 0.1)
		if not flurry_popup_emitted:
			flurry_popup_emitted = true
			main.spawn_hit_popup(quality_text())

func _execute_move(attack_data: AttackDefinition, technique: String) -> void:
	var is_whirlwind := attack_data.finisher_id == "whirlwind"
	if is_whirlwind:
		main.show_whirlwind_hitbox(last_clockwise)
	var amount := attack_data.damage * _damage_multiplier(attack_data)
	main.animate_sword_attack(_direction_vector(technique))
	main.show_attack_hitbox(main.facing_direction, tempo.slot())
	status_message.emit("CHAIN %d/3%s • %s" % [tempo.slot(), _quality_tag(), attack_data.display_name])
	var reach := 3.5 if is_whirlwind else 3.0
	if not main.boss_in_front() or main.boss_distance() >= reach:
		return
	main.deal_boss_damage(amount, 0.3 if is_whirlwind else 0.25)
	main.spawn_hit_popup(quality_text())

func _quality_tag() -> String:
	var quality := quality_text()
	if quality == "":
		return ""
	return " • %s" % quality

func _execute_finisher(attack_data: AttackDefinition, technique: String) -> void:
	var quality := quality_text()
	var tier_factor := TempoChain.quick_scale if tempo.tier == TempoChain.TIER_QUICK else 1.0
	match attack_data.finisher_id:
		"flurry":
			status_message.emit("CHAIN 3/3 • FLURRY FINISHER%s" % _quality_tag())
			flurry_ticks = FLURRY_TICKS
			flurry_timer = 0.33
			flurry_tick_damage = attack_data.damage * tier_factor / float(FLURRY_TICKS)
			flurry_popup_emitted = false
			main.animate_sword_attack(Vector2.RIGHT)
			main.show_attack_hitbox(main.facing_direction, 3)
		"back_step":
			main.defensive_step("back")
			status_message.emit("CHAIN 3/3 • BACK STEP FINISHER • INVULNERABLE")
		"whirlwind":
			main.show_whirlwind_hitbox(last_clockwise)
			if main.boss_distance() < 3.5 and main.boss_in_front():
				main.deal_boss_damage(attack_data.damage * tier_factor, 0.5)
				main.spawn_hit_popup(quality)
			status_message.emit("CHAIN 3/3 • HEAVY WHIRLWIND FINISHER%s" % _quality_tag())
		_:
			main.animate_sword_attack(_direction_vector(technique))
			main.show_attack_hitbox(main.facing_direction, 3)
			if main.boss_in_front() and main.boss_distance() < 3.2:
				main.deal_boss_damage(attack_data.damage * tier_factor, 0.45)
				main.spawn_hit_popup(quality)
			status_message.emit("CHAIN 3/3 • HEAVY SLASH FINISHER%s" % _quality_tag())

## Dodge roll-cancel during recovery.
func cancel_for_dodge() -> void:
	tempo.abort()

func _direction_vector(technique: String) -> Vector2:
	match technique:
		"L":
			return Vector2.LEFT
		"R":
			return Vector2.RIGHT
		"D":
			return Vector2.DOWN
		_:
			return Vector2.UP

func _on_chain_died(reason: String) -> void:
	super(reason)
	flurry_ticks = 0
