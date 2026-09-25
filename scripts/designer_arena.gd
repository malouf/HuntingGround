extends Node

## Designer bench launcher: pick a boss and a weapon, then jump into the
## fight with bench controls. Run scenes/designer_arena.tscn with F6 in the
## editor (or set it as the main scene).
##
## UI rule: everything hangs off one full-rect Control that ignores the mouse,
## so the background can never eat a click meant for a button.

var selected := "sword"
var boss_count := 0
var weapon_label: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color("#10181c")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)
	var title := Label.new()
	title.text = "DESIGNER BENCH"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#e8d6ad"))
	title.position = Vector2(38, 40)
	ui.add_child(title)
	var hint := Label.new()
	hint.text = "Pick a boss to fight with bench controls\n(HP jumps, force move, freeze telegraph)."
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("#9fb0a8"))
	hint.position = Vector2(38, 96)
	ui.add_child(hint)

	var weapon_row := HBoxContainer.new()
	weapon_row.position = Vector2(38, 640)
	ui.add_child(weapon_row)
	var sword_button := Button.new()
	sword_button.text = "SWORD"
	sword_button.custom_minimum_size = Vector2(200, 64)
	sword_button.pressed.connect(_pick_sword)
	weapon_row.add_child(sword_button)
	var bow_button := Button.new()
	bow_button.text = "BOW"
	bow_button.custom_minimum_size = Vector2(200, 64)
	bow_button.pressed.connect(_select_bow)
	weapon_row.add_child(bow_button)
	weapon_label = Label.new()
	weapon_label.text = "SWORD SELECTED"
	weapon_label.add_theme_font_size_override("font_size", 18)
	weapon_label.add_theme_color_override("font_color", Color("#d1ddd6"))
	weapon_label.position = Vector2(470, 660)
	ui.add_child(weapon_label)
	var note := Label.new()
	note.text = "Every boss file in resources/bosses/ shows up here —\nthe Designer dock writes them."
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("#6d7d76"))
	note.position = Vector2(38, 1180)
	ui.add_child(note)

	# One button per BossDefinition in the bosses folder.
	var files := DirAccess.get_files_at("res://resources/bosses")
	if files == null:
		return
	files.sort()
	var y := 140.0
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var def := load("res://resources/bosses/" + file) as BossDefinition
		if def == null:
			continue
		var button := Button.new()
		button.text = "%s\n(%s)  •  %d HP  •  %d move(s)" % [def.display_name, file.get_basename(), roundi(def.max_health), def.moves.size()]
		button.position = Vector2(38, y)
		button.size = Vector2(644, 84)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_launch.bind(file.get_basename()))
		ui.add_child(button)
		y += 98.0
		boss_count += 1

func _pick_sword() -> void:
	selected = "sword"
	_update_weapon()

func _select_bow() -> void:
	selected = "bow"
	_update_weapon()

func _update_weapon() -> void:
	if weapon_label:
		weapon_label.text = "%s SELECTED" % selected.to_upper()

func _launch(boss_file: String) -> void:
	Engine.set_meta("bench_boss", boss_file)
	Engine.set_meta("bench_weapon", selected)
	get_tree().change_scene_to_file("res://main.tscn")
