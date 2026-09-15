extends Control

signal changed(value: Vector2)
signal released(value: Vector2)
signal gesture_released(value: Vector2, gesture: String, clockwise: bool)

@export var radius := 92.0
@export var knob_radius := 38.0
var active := false
var pointer_id := -1
var value := Vector2.ZERO
var path_points: Array[Vector2] = []

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0 + 20.0, radius * 2.0 + 20.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not active:
			active = true
			pointer_id = event.index
			path_points.clear()
			_set_value(event.position)
		elif not event.pressed and active and event.index == pointer_id:
			_finish_input()
	elif event is InputEventScreenDrag and active and event.index == pointer_id:
		_set_value(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			active = true
			path_points.clear()
			_set_value(event.position)
		else:
			_finish_input()
	elif event is InputEventMouseMotion and active:
		_set_value(event.position)

var _last_value := Vector2.ZERO

func _set_value(input_position: Vector2) -> void:
	var center := size * 0.5
	var offset := input_position - center
	_last_value = offset.limit_length(radius) / radius
	value = _last_value
	if path_points.size() == 0 or path_points[-1].distance_to(_last_value) > 0.06:
		path_points.append(_last_value)
		if path_points.size() > 48:
			path_points.pop_front()
	changed.emit(value)
	queue_redraw()

func _finish_input() -> void:
	active = false
	value = Vector2.ZERO
	var gesture := "direction"
	var clockwise := false
	if path_points.size() >= 6:
		var start_index := -1
		for index in range(path_points.size()):
			if path_points[index].length() > 0.35:
				start_index = index
				break
		if start_index >= 0 and path_points.size() - start_index >= 6:
			var total_angle := 0.0
			for index in range(start_index + 1, path_points.size()):
				var previous := path_points[index - 1]
				var current := path_points[index]
				if previous.length() > 0.2 and current.length() > 0.2:
					total_angle += atan2(previous.x * current.y - previous.y * current.x, previous.dot(current))
			var circle_start := path_points[start_index]
			var closed_loop := circle_start.distance_to(path_points[-1]) < 0.65
			if absf(total_angle) > 4.4 and closed_loop:
				gesture = "circle"
				clockwise = total_angle > 0.0
	released.emit(_last_value)
	gesture_released.emit(_last_value, gesture, clockwise)
	changed.emit(value)
	path_points.clear()
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var tint := Color(0.12, 0.16, 0.19, 0.78)
	draw_circle(center, radius, tint)
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.55, 0.7, 0.72, 0.7), 3.0)
	draw_circle(center + value * radius, knob_radius, Color(0.78, 0.87, 0.82, 0.92))
