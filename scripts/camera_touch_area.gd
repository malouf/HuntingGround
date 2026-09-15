extends Control

signal dragged(delta: Vector2)
var active := false
var pointer_id := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not active:
			active = true
			pointer_id = event.index
		elif not event.pressed and active and event.index == pointer_id:
			active = false
			pointer_id = -1
	elif event is InputEventScreenDrag and active and event.index == pointer_id:
		dragged.emit(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		active = event.pressed
	elif event is InputEventMouseMotion and active:
		dragged.emit(event.relative)
