@tool
extends Control

## Designer dock: a tab for weapons and a tab for bosses. Both tabs are
## self-contained panels that save straight to .tres files.

const WEAPON_PANEL := preload("res://addons/designer/weapon_panel.gd")
const BOSS_PANEL := preload("res://addons/designer/boss_panel.gd")

var weapon_panel
var boss_panel

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(0, 340)
	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tabs)
	weapon_panel = WEAPON_PANEL.new()
	weapon_panel.name = "WEAPON"
	tabs.add_child(weapon_panel)
	boss_panel = BOSS_PANEL.new()
	boss_panel.name = "BOSS"
	tabs.add_child(boss_panel)