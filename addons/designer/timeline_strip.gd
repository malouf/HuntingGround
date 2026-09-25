@tool
extends Control

## The swing timeline, shared by the weapon and boss tabs: bars for
## windup/active/recovery, the link window colored by press zone, and
## draggable handles. The boss tab maps "windup" to its move's telegraph.

signal zone_dragged(field: String, value: float)
signal edit_committed()

const PAD := 14.0
const BAR_Y := 58.0
const BAR_H := 30.0
const BAND_Y := 12.0
const BAND_H := 30.0

var windup := 0.15
var active := 0.1
var recovery := 0.5
var link_open := 0.28
var link_close := 0.68
var chains := true
var tempo := {}
var drag_field := ""
var has_data := false
var empty_text := "Select an attack"
var no_chain_text := "NO CHAIN (FINISHER)"

## Raw entry point: all values in seconds; link values ignored when chains
## is false. empty: text shown with nothing selected. no_chain: the band
## label for attacks without a link window.
func set_data(windup_value: float, active_value: float, recovery_value: float, link_open_value: float, link_close_value: float, chains_value: bool, tempo_data: Dictionary, empty: String, no_chain: String) -> void:
	windup = windup_value
	active = active_value
	recovery = recovery_value
	link_open = link_open_value
	link_close = link_close_value
	chains = chains_value
	tempo = tempo_data
	has_data = true
	empty_text = empty
	no_chain_text = no_chain
	queue_redraw()

func set_attack(attack: AttackDefinition, tempo_data: Dictionary) -> void:
	if attack == null:
		has_data = false
		queue_redraw()
		return
	set_data(attack.windup, attack.active, attack.recovery, attack.link_open, attack.link_close, attack.chains, tempo_data, "Select an attack", "NO CHAIN (FINISHER)")

func set_boss_move(move: BossMove, tempo_data: Dictionary) -> void:
	if move == null:
		has_data = false
		queue_redraw()
		return
	set_data(move.telegraph, move.active, move.recovery, 99.0, 99.0, false, tempo_data, "Select a boss move", "NO LINK WINDOW")

func _total() -> float:
	return windup + active + recovery

func _span() -> float:
	var span := _total()
	if chains:
		span = maxf(span, link_close)
	return maxf(span, 0.6)

func _px_per_s() -> float:
	return (size.x - PAD * 2.0) / (_span() * 1.06)

func _x(t: float) -> float:
	return PAD + t * _px_per_s()

func _t(x: float) -> float:
	return (x - PAD) / _px_per_s()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.13, 0.15))
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	if not has_data:
		draw_string(font, Vector2(PAD, BAR_Y), empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.55, 0.6, 0.58))
		return
	# Ruler: ticks every 0.1s, labels every 0.2s.
	var tick := 0.0
	while tick <= _span() + 0.001:
		var tick_x := _x(tick)
		var tall: bool = absf(fmod(tick, 0.2)) < 0.001
		draw_line(Vector2(tick_x, BAR_Y + BAR_H + (12.0 if tall else 6.0)), Vector2(tick_x, BAR_Y + BAR_H), Color(0.35, 0.4, 0.38), 1.0)
		if tall:
			draw_string(font, Vector2(tick_x + 2, BAR_Y + BAR_H + 22), "%.1f" % tick, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color(0.5, 0.56, 0.54))
		tick += 0.1
	# Swing segments.
	draw_rect(Rect2(Vector2(_x(0), BAR_Y), Vector2(windup * _px_per_s(), BAR_H)), Color(0.42, 0.5, 0.66))
	draw_rect(Rect2(Vector2(_x(windup), BAR_Y), Vector2(active * _px_per_s(), BAR_H)), Color(0.92, 0.58, 0.22))
	draw_rect(Rect2(Vector2(_x(windup + active), BAR_Y), Vector2(maxf(recovery, 0.0) * _px_per_s(), BAR_H)), Color(0.33, 0.4, 0.38))
	# Link window zones, from open to close: stagger / weak / critical.
	if chains and link_close > link_open:
		var span := link_close - link_open
		var yellow_start: float = link_close - float(tempo.get("yellow_fraction", 0.25)) * span
		var critical_start: float = yellow_start - float(tempo.get("early_grace", 0.06))
		var weak_start: float = critical_start - float(tempo.get("weak_before", 0.09))
		draw_rect(Rect2(Vector2(_x(link_open), BAND_Y), Vector2(_x(weak_start) - _x(link_open), BAND_H)), Color(0.8, 0.35, 0.28, 0.45))
		draw_rect(Rect2(Vector2(_x(weak_start), BAND_Y), Vector2(_x(critical_start) - _x(weak_start), BAND_H)), Color(0.6, 0.72, 0.75, 0.55))
		draw_rect(Rect2(Vector2(_x(critical_start), BAND_Y), Vector2(_x(link_close) - _x(critical_start), BAND_H)), Color(1.0, 0.82, 0.35, 0.8))
	else:
		draw_string(font, Vector2(PAD, BAND_Y + 22), no_chain_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color(0.6, 0.55, 0.45))
	# Draggable handles.
	for handle in _handle_list():
		draw_line(Vector2(_x(handle.t), BAR_Y - 8.0), Vector2(_x(handle.t), BAR_Y + BAR_H + 2.0), Color(0.95, 0.95, 0.88), 2.0)
	draw_string(font, Vector2(PAD, size.y - 6), "drag the white handles — RED spam • GRAY weak • GOLD critical", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color(0.42, 0.48, 0.46))

func _handle_list() -> Array:
	var handles := [
		{"field": "windup", "t": windup},
		{"field": "active", "t": windup + active},
		{"field": "recovery", "t": _total()},
	]
	if chains and link_close > link_open:
		handles.append({"field": "link_open", "t": link_open})
		handles.append({"field": "link_close", "t": link_close})
	return handles

func _field_at(point: Vector2) -> String:
	for handle in _handle_list():
		if absf(point.x - _x(handle.t)) <= 6.0:
			return handle.field
	return ""

func _gui_input(event: InputEvent) -> void:
	if not has_data:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_field = _field_at(event.position)
		elif drag_field != "":
			drag_field = ""
			edit_committed.emit()
		accept_event()
	elif event is InputEventMouseMotion and drag_field != "":
		var t := maxf(_t(event.position.x), 0.0)
		var value := t
		match drag_field:
			"windup":
				value = maxf(t, 0.01)
			"active":
				value = maxf(t - windup, 0.01)
			"recovery":
				value = maxf(t - windup - active, 0.0)
			"link_open":
				value = maxf(t, windup + active)
			"link_close":
				value = maxf(t, link_open + 0.02)
		zone_dragged.emit(drag_field, value)
		accept_event()