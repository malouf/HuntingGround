@tool
extends EditorPlugin

## Registers the Designer bottom panel: weapon + boss hand-crafting.

const DOCK_SCRIPT := preload("res://addons/designer/designer_dock.gd")

var dock: Control

func _enter_tree() -> void:
	dock = DOCK_SCRIPT.new()
	dock.name = "DesignerDock"
	add_control_to_bottom_panel(dock, "Designer")

func _exit_tree() -> void:
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null