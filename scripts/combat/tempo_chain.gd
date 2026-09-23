class_name TempoChain
extends RefCounted

## PSO-style attack rhythm state machine.
##
## Every combo is ALWAYS 3 hits: input 1 (always normal), input 2, input 3 =
## finisher. Each swing runs windup -> active -> recovery with a link window
## whose final portion is the tight yellow just-beat. Pressing on the beat
## chains the next swing at full power (CRITICAL). Pressing off-beat but
## inside the window, during recovery, or during the lapse grace still chains
## as a WEAK quick hit. Spamming during windup/active breaks the combo and
## staggers the hunter.

signal swing_started(technique: String, slot: int)
signal link_window_opened()
signal link_window_closed()
signal chain_died(reason: String)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

## Tempo tuning — loaded from resources/config/tempo_config.json at startup.
## Edit the JSON (or these defaults) to reshape the rhythm windows.
## Inputs this far around the beat still count (touch fairness buffer).
static var early_grace := 0.06
static var late_grace := 0.06
## Presses in the first moments of a swing are ignored (double-tap guard).
static var input_cooldown := 0.08
## Attack lockout after spam or a dropped combo.
static var stagger_time := 0.55
## After a swing ends the chain stays open this long before it counts as dropped.
static var lapse_time := 0.4
## Tightened final fraction of the link window that counts as the yellow beat.
static var yellow_fraction := 0.25
## Tight weak band hugging the beat, in seconds (0 disables weak hits).
static var weak_before := 0.09
## Damage multiplier for off-beat weak hits.
static var quick_scale := 0.6
## Tier labels (not tuning).
const TIER_NORMAL := "normal"
const TIER_JUST := "just"
const TIER_QUICK := "quick"

var phase: int = Phase.IDLE
## Swings started in the current combo minus one (0 during input 1, 1 during
## input 2, 2 during the finisher).
var chain_index := 0
var history: Array[String] = []
var elapsed := 0.0
var attack: AttackDefinition
var window_open := false
var tier := TIER_NORMAL
var stagger_timer := 0.0
var lapse_timer := 0.0
var died_while_busy := false

func is_busy() -> bool:
	return phase != Phase.IDLE

func is_committed() -> bool:
	return phase == Phase.WINDUP or phase == Phase.ACTIVE

func is_recovering() -> bool:
	return phase == Phase.RECOVERY

func staggered() -> bool:
	return stagger_timer > 0.0

## 1-based slot of the running swing: 1 = first input, 2 = second, 3 = finisher.
func slot() -> int:
	return mini(chain_index + 1, 3)

func is_window_open() -> bool:
	return window_open

func yellow_start() -> float:
	if attack == null:
		return 999.0
	return attack.link_close - yellow_fraction * (attack.link_close - attack.link_open)

## 1.0 while the window just opened, toward 0.0 as it closes; -1.0 when hidden.
func window_remaining_ratio() -> float:
	if attack == null or not window_open:
		return -1.0
	var duration := attack.link_close - attack.link_open
	if duration <= 0.0:
		return -1.0
	var passed := clampf(elapsed - attack.link_open, 0.0, duration)
	return 1.0 - passed / duration

## True only when the press lands on the tight yellow just-beat.
func on_beat() -> bool:
	if attack == null or not attack.chains:
		return false
	return elapsed >= yellow_start() - early_grace and elapsed <= attack.link_close + late_grace

## Which window the running swing is in right now: "critical", "weak" or
## "stagger" (used for the joystick ring and the chain pip colors).
func current_zone() -> String:
	if on_beat():
		return "critical"
	if in_weak_band():
		return "weak"
	return "stagger"

## Tight weak band hugging the beat: a short stretch just before it. Anything
## further from the beat is spam.
func in_weak_band() -> bool:
	if attack == null or not attack.chains:
		return false
	var band_start := yellow_start() - early_grace - weak_before
	return elapsed >= band_start and elapsed < yellow_start() - early_grace

## Classifies an incoming attack input:
## "just" (on the yellow beat: full-power chain), "window_early" (off-beat
## within the tight weak band: weak chain), "idle" (fresh input 1), "early"
## (spam before the beat: stagger), "late" (spam after the beat or on a dead
## chain: stagger), "staggered", or "used" (double-tap guard / 4th input).
func offer_input() -> String:
	if stagger_timer > 0.0:
		return "staggered"
	if phase == Phase.IDLE:
		return "late" if lapse_timer > 0.0 else "idle"
	if elapsed < input_cooldown:
		return "used"
	if slot() >= 3:
		# The finisher is running: a 4th input does nothing (never staggers).
		return "used"
	if died_while_busy:
		# The chain already died to spam during this swing: keep punishing.
		return "early" if elapsed < yellow_start() else "late"
	if on_beat():
		return "just"
	if in_weak_band():
		return "window_early"
	return "early" if elapsed < yellow_start() else "late"

func start(technique: String, attack_data: AttackDefinition, isolated := false, start_tier := TIER_NORMAL) -> void:
	attack = attack_data
	elapsed = 0.0
	window_open = false
	tier = start_tier
	lapse_timer = 0.0
	died_while_busy = false
	phase = Phase.WINDUP
	if isolated:
		chain_index = 0
		history.clear()
	else:
		history.append(technique)
	swing_started.emit(technique, slot())

## Chains into the next swing (caller verified the classification).
func chain_to(technique: String, next_attack: AttackDefinition, next_tier := TIER_JUST) -> void:
	chain_index += 1
	start(technique, next_attack, false, next_tier)

func process(delta: float) -> void:
	if stagger_timer > 0.0:
		stagger_timer = maxf(0.0, stagger_timer - delta)
	if phase == Phase.IDLE:
		if lapse_timer > 0.0:
			lapse_timer = maxf(0.0, lapse_timer - delta)
			if lapse_timer <= 0.0:
				# A combo that never reaches its finisher stops -> stagger.
				kill_chain("lapsed")
		return
	if attack == null:
		return
	elapsed += delta
	if phase == Phase.WINDUP and elapsed >= attack.windup:
		phase = Phase.ACTIVE
	elif phase == Phase.ACTIVE and elapsed >= attack.windup + attack.active:
		phase = Phase.RECOVERY
	if not window_open and attack.chains and elapsed >= attack.link_open and elapsed < attack.link_close:
		window_open = true
		link_window_opened.emit()
	if window_open and elapsed >= attack.link_close:
		window_open = false
		link_window_closed.emit()
	if phase == Phase.RECOVERY and elapsed >= attack.windup + attack.active + attack.recovery:
		phase = Phase.IDLE
		if chain_index >= 2:
			# The finisher completed the combo.
			kill_chain("ended")
		elif died_while_busy:
			# The chain already died to spam mid-swing; no extra stagger.
			died_while_busy = false
		else:
			lapse_timer = lapse_time
		attack = null

## Dodge roll-cancel: the swing stops, the chain dies without a stagger.
func abort() -> void:
	phase = Phase.IDLE
	attack = null
	kill_chain("abort")

func kill_chain(reason: String) -> void:
	chain_index = 0
	history.clear()
	lapse_timer = 0.0
	if phase != Phase.IDLE:
		died_while_busy = true
	chain_died.emit(reason)