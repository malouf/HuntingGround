extends Control

signal two_finger_swipe(axis: String, direction: int)

var touches: Dictionary = {}
var tracking := false
var had_two_fingers := false
var start_center := Vector2.ZERO
var last_center := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 2:
				tracking = true
				had_two_fingers = true
				start_center = _center()
				last_center = start_center
		elif touches.has(event.index):
			touches.erase(event.index)
			if tracking and had_two_fingers and touches.is_empty():
				_finish()
	elif event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index] = event.position
		if tracking and touches.size() >= 2:
			last_center = _center()

func _center() -> Vector2:
	var result := Vector2.ZERO
	for point in touches.values():
		result += point
	return result / maxf(1.0, float(touches.size()))

func _finish() -> void:
	var delta := last_center - start_center
	tracking = false
	had_two_fingers = false
	if delta.length() < 45.0:
		return
	if absf(delta.x) > absf(delta.y):
		two_finger_swipe.emit("horizontal", 1 if delta.x > 0.0 else -1)
	else:
		two_finger_swipe.emit("vertical", 1 if delta.y > 0.0 else -1)
