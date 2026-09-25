@tool
extends VBoxContainer

## Boss tab of the Designer: hand-craft BossDefinitions — moves with their
## telegraphs, phases with their cadence and colors, and follow-up chains.
## Every change writes straight to the .tres file.

const BOSSES_DIR := "res://resources/bosses"
const STRIP := preload("res://addons/designer/timeline_strip.gd")
const DEFAULT_TEMPO := {"yellow_fraction": 0.25, "weak_before": 0.09, "early_grace": 0.06}
const HIT_SHAPE_NAMES := ["SPHERE", "BOX", "CAPSULE"]
const ANIMATION_NAMES := ["", "slash_l", "slash_r", "slash_u", "slash_d", "flurry", "whirlwind", "heavy_slash", "back_step", "quick_dodge", "brute_swing", "brute_lunge"]

var boss_list: ItemList
var move_list: ItemList
var phase_list: ItemList
var strip
var move_fields := {}
var move_pick_fields := {}
var move_vector_fields := {}
var phase_fields := {}
var state_edit: LineEdit
var color_button: ColorPickerButton
var chain_caption: Label
var chain_box: VBoxContainer
var add_chain_button: Button
var moveset_button: Button
var info_label: Label
var warning_label: Label
var move_editor: VBoxContainer
var phase_editor: VBoxContainer

var bosses: Array[BossDefinition] = []
## One entry per move row: {move, container} with container "moveset" or "".
var move_rows: Array[Dictionary] = []
var current_boss: BossDefinition
var current_move: BossMove
var current_phase: BossPhase
var tempo := {}
var _loading := false

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_tempo()
	_build_ui()
	_scan_bosses()

## Reads the player-side zone sizes. Boss strips draw no press zones today,
## but the strip gets the same tempo dictionary everywhere.
func _load_tempo() -> void:
	tempo = DEFAULT_TEMPO.duplicate()
	var path := "res://resources/config/tempo_config.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in tempo.keys():
			if parsed.has(key) and (parsed[key] is float or parsed[key] is int):
				tempo[key] = float(parsed[key])

func _build_ui() -> void:
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 40
	add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left_scroll.add_child(left)
	left.add_child(_make_caption("BOSSES"))
	boss_list = ItemList.new()
	boss_list.custom_minimum_size = Vector2(0, 56)
	boss_list.item_selected.connect(_on_boss_selected)
	left.add_child(boss_list)
	var new_boss_button := Button.new()
	new_boss_button.text = "NEW BOSS"
	new_boss_button.pressed.connect(_new_boss)
	left.add_child(new_boss_button)
	var boss_more := HBoxContainer.new()
	var delete_boss_button := Button.new()
	delete_boss_button.text = "DELETE BOSS"
	delete_boss_button.pressed.connect(_delete_boss)
	boss_more.add_child(delete_boss_button)
	left.add_child(boss_more)
	left.add_child(_make_caption("MOVES"))
	move_list = ItemList.new()
	move_list.custom_minimum_size = Vector2(0, 90)
	move_list.item_selected.connect(_on_move_selected)
	left.add_child(move_list)
	var move_buttons := HBoxContainer.new()
	var new_move_button := Button.new()
	new_move_button.text = "NEW MOVE"
	new_move_button.pressed.connect(_new_move)
	move_buttons.add_child(new_move_button)
	var copy_move_button := Button.new()
	copy_move_button.text = "DUPLICATE"
	copy_move_button.pressed.connect(_duplicate_move)
	move_buttons.add_child(copy_move_button)
	moveset_button = Button.new()
	moveset_button.text = "TOGGLE MOVESET"
	moveset_button.pressed.connect(_toggle_moveset)
	move_buttons.add_child(moveset_button)
	left.add_child(move_buttons)
	var move_more := HBoxContainer.new()
	var delete_move_button := Button.new()
	delete_move_button.text = "DELETE MOVE"
	delete_move_button.pressed.connect(_delete_move)
	move_more.add_child(delete_move_button)
	left.add_child(move_more)
	left.add_child(_make_caption("PHASES"))
	phase_list = ItemList.new()
	phase_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phase_list.item_selected.connect(_on_phase_selected)
	left.add_child(phase_list)
	var new_phase_button := Button.new()
	new_phase_button.text = "NEW PHASE"
	new_phase_button.pressed.connect(_new_phase)
	left.add_child(new_phase_button)
	var phase_more := HBoxContainer.new()
	var delete_phase_button := Button.new()
	delete_phase_button.text = "DELETE PHASE"
	delete_phase_button.pressed.connect(_delete_phase)
	phase_more.add_child(delete_phase_button)
	left.add_child(phase_more)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(520, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	strip = STRIP.new()
	strip.custom_minimum_size = Vector2(0, 120)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.zone_dragged.connect(_on_strip_drag)
	strip.edit_committed.connect(_save_move)
	right.add_child(strip)
	info_label = Label.new()
	right.add_child(info_label)
	warning_label = Label.new()
	warning_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.3))
	right.add_child(warning_label)

	# Move editor: timings, reach, pick rules, follow-up chains.
	move_editor = VBoxContainer.new()
	right.add_child(move_editor)
	var grid := GridContainer.new()
	grid.columns = 4
	move_editor.add_child(grid)
	_make_move_field(grid, "telegraph", "TELEGRAPH s", 0.01, 10.0)
	_make_move_field(grid, "active", "ACTIVE s", 0.01, 10.0)
	_make_move_field(grid, "recovery", "RECOVERY s", 0.01, 10.0)
	_make_move_field(grid, "damage", "DAMAGE", 1.0, 1000.0)
	_make_move_field(grid, "reach", "REACH m", 0.1, 50.0)
	_make_move_field(grid, "arc_degrees", "ARC DEG", 5.0, 360.0)
	_make_move_field(grid, "weight", "WEIGHT", 0.1, 100.0)
	_make_move_field(grid, "cooldown", "COOLDOWN s", 0.05, 60.0)
	_make_move_field(grid, "min_range", "MIN RANGE m", 0.1, 50.0)
	_make_move_field(grid, "max_range", "MAX RANGE m", 0.1, 200.0)
	_make_move_field(grid, "hitbox_lifetime", "HITBOX STAY s", 0.01, 10.0)
	var pick_grid := GridContainer.new()
	pick_grid.columns = 4
	move_editor.add_child(pick_grid)
	_make_move_pick(pick_grid, "hitbox_shape", "SHAPE", HIT_SHAPE_NAMES)
	_make_move_pick(pick_grid, "animation_id", "ANIM", ANIMATION_NAMES)
	_make_move_vector_row(move_editor, "hitbox_size", "HITBOX SIZE")
	chain_caption = _make_caption("FOLLOW-UP CHAINS")
	move_editor.add_child(chain_caption)
	var add_chain_row := HBoxContainer.new()
	add_chain_button = Button.new()
	add_chain_button.text = "+ ADD FOLLOW-UP"
	add_chain_button.pressed.connect(_add_follow_up)
	add_chain_row.add_child(add_chain_button)
	move_editor.add_child(add_chain_row)
	chain_box = VBoxContainer.new()
	move_editor.add_child(chain_box)

	# Phase editor: cadence, movement, body color and posture.
	phase_editor = VBoxContainer.new()
	right.add_child(phase_editor)
	var phase_grid := GridContainer.new()
	phase_grid.columns = 4
	phase_editor.add_child(phase_grid)
	_make_phase_field(phase_grid, "hp_below", "HP BELOW x", 0.01, 1.0)
	_make_phase_field(phase_grid, "walk_speed", "WALK SPEED", 0.05, 20.0)
	_make_phase_field(phase_grid, "attack_cadence", "CADENCE s", 0.05, 30.0)
	_make_phase_field(phase_grid, "attack_speed", "ATTACK SPEED x", 0.01, 5.0)
	_make_phase_field(phase_grid, "tilt_degrees", "TILT DEG", 0.5, 45.0, -45.0)
	var text_label := Label.new()
	text_label.text = "STATE TEXT"
	phase_editor.add_child(text_label)
	state_edit = LineEdit.new()
	state_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_edit.text_changed.connect(_on_state_text_changed)
	phase_editor.add_child(state_edit)
	var color_label := Label.new()
	color_label.text = "BODY COLOR"
	phase_editor.add_child(color_label)
	color_button = ColorPickerButton.new()
	color_button.custom_minimum_size = Vector2(90, 26)
	color_button.color_changed.connect(_on_body_color_changed)
	phase_editor.add_child(color_button)

func _make_caption(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	return label

## A loaded .tres that omits a list inherits the script default, which Godot
## locks read-only. Build a fresh, correctly typed copy before mutating.
func _fresh_moves(source: Array[BossMove]) -> Array[BossMove]:
	var out: Array[BossMove] = []
	for item in source:
		out.append(item)
	return out

func _fresh_phases(source: Array[BossPhase]) -> Array[BossPhase]:
	var out: Array[BossPhase] = []
	for item in source:
		out.append(item)
	return out

func _fresh_follow_ups(source: Array[BossFollowUp]) -> Array[BossFollowUp]:
	var out: Array[BossFollowUp] = []
	for item in source:
		out.append(item)
	return out

func _make_move_field(grid: GridContainer, field: String, caption: String, step: float, max_value: float) -> void:
	var label := Label.new()
	label.text = caption
	grid.add_child(label)
	var box := SpinBox.new()
	box.step = step
	box.max_value = max_value
	box.custom_minimum_size = Vector2(80, 0)
	box.value_changed.connect(_on_move_field_changed.bind(field))
	grid.add_child(box)
	move_fields[field] = box

func _make_phase_field(grid: GridContainer, field: String, caption: String, step: float, max_value: float, min_value := 0.0) -> void:
	var label := Label.new()
	label.text = caption
	grid.add_child(label)
	var box := SpinBox.new()
	box.step = step
	box.min_value = min_value
	box.max_value = max_value
	box.custom_minimum_size = Vector2(80, 0)
	box.value_changed.connect(_on_phase_field_changed.bind(field))
	grid.add_child(box)
	phase_fields[field] = box

func _make_move_pick(grid: GridContainer, field: String, caption: String, names: Array) -> void:
	var label := Label.new()
	label.text = caption
	grid.add_child(label)
	var pick := OptionButton.new()
	for name in names:
		pick.add_item(name)
	pick.item_selected.connect(_on_move_pick_changed.bind(field))
	grid.add_child(pick)
	move_pick_fields[field] = pick

func _make_move_vector_row(parent: Control, field: String, caption: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var boxes: Array = []
	for axis in 3:
		var box := SpinBox.new()
		box.step = 0.1
		box.min_value = 0.0
		box.max_value = 50.0
		box.custom_minimum_size = Vector2(64, 0)
		box.value_changed.connect(func(_value): _on_move_vector_changed(field))
		row.add_child(box)
		boxes.append(box)
	move_vector_fields[field] = boxes
	parent.add_child(row)

## Loads every BossDefinition in the bosses folder; BossMove files are loose
## content, not bosses.
func _scan_bosses() -> void:
	bosses.clear()
	boss_list.clear()
	var files := DirAccess.get_files_at(BOSSES_DIR)
	if files == null:
		return
	files.sort()
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var def := load(BOSSES_DIR + "/" + file) as BossDefinition
		if def:
			bosses.append(def)
			boss_list.add_item("%s  (%s)" % [def.display_name, file.get_basename()])
	if bosses.size() > 0:
		boss_list.select(0)
		_select_boss(0)

func _on_boss_selected(index: int) -> void:
	_select_boss(index)

func _select_boss(index: int) -> void:
	if index < 0 or index >= bosses.size():
		return
	current_boss = bosses[index]
	current_boss.moves = _fresh_moves(current_boss.moves)
	current_boss.phases = _fresh_phases(current_boss.phases)
	current_move = null
	current_phase = null
	_reload_move_rows()
	_reload_phase_rows()

## Move rows: the boss's moveset first, then loose BossMove files.
func _reload_move_rows() -> void:
	move_list.clear()
	move_rows.clear()
	if current_boss == null:
		return
	for move in current_boss.moves:
		move_list.add_item("MOVESET — %s" % move.display_name)
		move_rows.append({"move": move, "container": "moveset"})
	var files := DirAccess.get_files_at(BOSSES_DIR)
	if files != null:
		files.sort()
		for file in files:
			if not file.ends_with(".tres"):
				continue
			var res := load(BOSSES_DIR + "/" + file)
			if res is BossMove and not _move_rows_contain(res):
				move_list.add_item("LOOSE — %s" % file.get_basename())
				move_rows.append({"move": res, "container": ""})
	if move_rows.size() > 0:
		move_list.select(0)
		_select_move(0)
	_show_editor()

func _move_rows_contain(move: BossMove) -> bool:
	for row in move_rows:
		if row.move == move:
			return true
	return false

func _on_move_selected(index: int) -> void:
	if index < 0 or index >= move_rows.size():
		return
	current_move = move_rows[index].move
	current_phase = null
	_sync_move()
	_show_editor()

func _select_move(index: int) -> void:
	if index < 0 or index >= move_rows.size():
		return
	current_move = move_rows[index].move
	current_phase = null
	_sync_move()
	_show_editor()

func _reload_phase_rows(keep: BossPhase = null) -> void:
	phase_list.clear()
	current_phase = null
	if current_boss == null:
		return
	for i in current_boss.phases.size():
		var phase := current_boss.phases[i]
		phase_list.add_item("PHASE %d — below %d%% HP" % [i, roundi(phase.hp_below * 100.0)])
		if keep != null and phase == keep:
			phase_list.select(i)
			current_phase = keep

func _on_phase_selected(index: int) -> void:
	if current_boss == null or index < 0 or index >= current_boss.phases.size():
		return
	current_phase = current_boss.phases[index]
	_sync_phase()
	_show_editor()

func _show_editor() -> void:
	move_editor.visible = current_move != null
	phase_editor.visible = current_move == null and current_phase != null

func _sync_move() -> void:
	if current_move == null:
		return
	current_move.follow_ups = _fresh_follow_ups(current_move.follow_ups)
	_loading = true
	for field in move_fields.keys():
		move_fields[field].value = current_move.get(field)
	for field in move_pick_fields.keys():
		var pick: OptionButton = move_pick_fields[field]
		var value = current_move.get(field)
		if field == "hitbox_shape":
			pick.select(clampi(int(value), 0, HIT_SHAPE_NAMES.size() - 1))
		else:
			var index := ANIMATION_NAMES.find(value)
			pick.select(index if index >= 0 else 0)
	for field in move_vector_fields.keys():
		var v: Vector3 = current_move.get(field)
		var boxes: Array = move_vector_fields[field]
		boxes[0].value = v.x
		boxes[1].value = v.y
		boxes[2].value = v.z
	_loading = false
	strip.set_boss_move(current_move, tempo)
	_refresh_info()
	_validate()
	_rebuild_chain_box()

func _sync_phase() -> void:
	if current_phase == null:
		return
	_loading = true
	for field in phase_fields.keys():
		phase_fields[field].value = current_phase.get(field)
	_loading = false
	state_edit.text = current_phase.state_text
	color_button.color = current_phase.body_color

func _refresh_info() -> void:
	if current_move != null:
		info_label.text = "TELEGRAPH %.2fs  •  HIT AT %.2fs  •  %.0f DMG  •  REACH %.1fm  •  ARC %.0f°" % [current_move.telegraph, current_move.telegraph + current_move.active, current_move.damage, current_move.reach, current_move.arc_degrees]
	else:
		info_label.text = ""

func _validate() -> void:
	var notes: Array[String] = []
	if current_boss != null and current_boss.moves.is_empty():
		notes.append("this boss has no moves yet")
	if current_move != null and current_boss != null:
		for link in current_move.follow_ups:
			if current_boss.move_by_id(link.move_id) == null:
				notes.append("follow-up target '%s' is not in the moveset" % link.move_id)
	warning_label.text = "WARNING: " + " / ".join(notes) if notes.size() > 0 else ""

func _on_move_field_changed(value: float, field: String) -> void:
	if _loading or current_move == null:
		return
	current_move.set(field, value)
	_sync_move()
	_save_move()

func _on_move_pick_changed(index: int, field: String) -> void:
	if _loading or current_move == null:
		return
	match field:
		"hitbox_shape":
			current_move.hitbox_shape = index
		"animation_id":
			current_move.animation_id = ANIMATION_NAMES[index] if index > 0 else ""
	_sync_move()
	_save_move()

func _on_move_vector_changed(field: String) -> void:
	if _loading or current_move == null:
		return
	var boxes: Array = move_vector_fields[field]
	current_move.set(field, Vector3(boxes[0].value, boxes[1].value, boxes[2].value))
	_sync_move()
	_save_move()

func _on_strip_drag(field: String, value: float) -> void:
	if _loading or current_move == null:
		return
	# The strip names the first bar "windup"; a boss move calls it telegraph.
	current_move.set("telegraph" if field == "windup" else field, value)
	_sync_move()

func _save_move() -> void:
	if current_move == null or current_move.resource_path == "":
		return
	var err := ResourceSaver.save(current_move, current_move.resource_path)
	if err != OK:
		warning_label.text = "SAVE FAILED (%s)" % error_string(err)
		return
	if warning_label.text.begins_with("SAVE FAILED"):
		warning_label.text = ""

func _save_boss() -> void:
	if current_boss == null or current_boss.resource_path == "":
		return
	ResourceSaver.save(current_boss, current_boss.resource_path)

## Phase edits: apply, keep phases ordered by hp_below, save the boss file.
func _on_phase_field_changed(value: float, field: String) -> void:
	if _loading or current_phase == null or current_boss == null:
		return
	current_phase.set(field, value)
	if current_boss.phases.size() > 1:
		current_boss.phases = _fresh_phases(current_boss.phases)
		current_boss.phases.sort_custom(func(a, b): return a.hp_below > b.hp_below)
	_reload_phase_rows(current_phase)
	_sync_phase()
	_save_boss()

func _on_state_text_changed(text_value: String) -> void:
	if _loading or current_phase == null:
		return
	current_phase.state_text = text_value
	_save_boss()

func _on_body_color_changed(color: Color) -> void:
	if _loading or current_phase == null:
		return
	current_phase.body_color = color
	_save_boss()

## Adds a boss move to (or removes it from) the current moveset.
func _toggle_moveset() -> void:
	if current_move == null or current_boss == null:
		return
	var list: Array[BossMove] = _fresh_moves(current_boss.moves)
	if list.has(current_move):
		list.erase(current_move)
	else:
		list.append(current_move)
	current_boss.moves = list
	_save_boss()
	_reload_move_rows()
	_reselect_move(current_move)
	_reload_phase_rows()

func _reselect_move(move: BossMove) -> void:
	for i in move_rows.size():
		if move_rows[i].move == move:
			move_list.select(i)
			_select_move(i)
			return

## Writes a blank BossMove and leaves it loose for adding to a moveset.
func _new_move() -> void:
	var id := ""
	for i in range(1, 100):
		id = "new_move_%d" % i
		if not FileAccess.file_exists(BOSSES_DIR + "/" + id + ".tres"):
			break
	var move := BossMove.new()
	move.move_id = id
	move.display_name = "New Move"
	move.telegraph = 0.75
	move.damage = 18.0
	move.reach = 3.0
	move.weight = 1.0
	move.max_range = 99.0
	var err := ResourceSaver.save(move, BOSSES_DIR + "/" + id + ".tres")
	if err != OK:
		warning_label.text = "SAVE FAILED (%s)" % error_string(err)
		return
	_reload_move_rows()
	# Select the cached instance the rows now hold, not the built object.
	_reselect_move(load(BOSSES_DIR + "/" + id + ".tres") as BossMove)

func _duplicate_move() -> void:
	if current_move == null:
		return
	var base := current_move.move_id
	if base == "":
		base = "move"
	var id := base + "_copy"
	for i in range(2, 100):
		if not FileAccess.file_exists(BOSSES_DIR + "/" + id + ".tres"):
			break
		id = "%s_copy_%d" % [base, i]
	var copy := current_move.duplicate(true) as BossMove
	copy.move_id = id
	copy.display_name = current_move.display_name + " copy"
	ResourceSaver.save(copy, BOSSES_DIR + "/" + id + ".tres")
	_reload_move_rows()
	_reselect_move(load(BOSSES_DIR + "/" + id + ".tres") as BossMove)

## Writes a new BossDefinition with one FRESH phase and no moves.
func _new_boss() -> void:
	var id := ""
	for i in range(1, 100):
		id = "boss_%d" % i
		if not FileAccess.file_exists(BOSSES_DIR + "/" + id + ".tres"):
			break
	var def := BossDefinition.new()
	def.boss_id = id
	def.display_name = "New Boss"
	def.max_health = 160.0
	def.stance_distance = 2.4
	def.body_scale = 1.55
	def.weapon_prop_path = "res://scenes/weapons/sword.tscn"
	def.phases = [BossPhase.new()]
	var err := ResourceSaver.save(def, BOSSES_DIR + "/" + id + ".tres")
	if err != OK:
		warning_label.text = "SAVE FAILED (%s)" % error_string(err)
		return
	_scan_bosses()
	# Select the freshly written boss.
	for i in bosses.size():
		if bosses[i].boss_id == id:
			boss_list.select(i)
			_select_boss(i)
			break

## Writes a new BossPhase into the current boss, ordered by hp_below.
func _new_phase() -> void:
	if current_boss == null:
		return
	var phase := BossPhase.new()
	phase.hp_below = 0.5
	phase.walk_speed = 1.0
	phase.attack_cadence = 2.35
	phase.attack_speed = 1.0
	phase.body_color = Color(0.7, 0.42, 0.27)
	phase.state_text = "NEW PHASE"
	var phase_list_fresh: Array[BossPhase] = _fresh_phases(current_boss.phases)
	phase_list_fresh.append(phase)
	if phase_list_fresh.size() > 1:
		phase_list_fresh.sort_custom(func(a, b): return a.hp_below > b.hp_below)
	current_boss.phases = phase_list_fresh
	_save_boss()
	_reload_phase_rows()
	for i in current_boss.phases.size():
		if current_boss.phases[i] == phase:
			phase_list.select(i)
			_on_phase_selected(i)
			break

## One row per follow-up: target move, weight, delay, remove.
func _rebuild_chain_box() -> void:
	for child in chain_box.get_children():
		child.queue_free()
	if current_move == null:
		return
	for i in current_move.follow_ups.size():
		chain_box.add_child(_make_chain_row(i))
	chain_caption.text = "FOLLOW-UP CHAINS — after %s, pick one by weight" % current_move.display_name

func _make_chain_row(row_index: int) -> HBoxContainer:
	var link := current_move.follow_ups[row_index]
	var row := HBoxContainer.new()
	var pick := OptionButton.new()
	var selected := -1
	if current_boss != null:
		for move in current_boss.moves:
			pick.add_item(move.move_id)
			if move.move_id == link.move_id:
				selected = pick.item_count - 1
	if selected == -1 and link.move_id != "":
		pick.add_item(link.move_id + " (missing)")
		selected = pick.item_count - 1
	if selected >= 0:
		pick.select(selected)
	pick.item_selected.connect(_on_chain_target_changed.bind(row_index, pick))
	row.add_child(pick)
	var weight := SpinBox.new()
	weight.min_value = 0.0
	weight.max_value = 100.0
	weight.step = 0.1
	weight.value = link.weight
	weight.value_changed.connect(_on_chain_weight_changed.bind(row_index))
	row.add_child(weight)
	var delay := SpinBox.new()
	delay.min_value = 0.0
	delay.max_value = 10.0
	delay.step = 0.05
	delay.value = link.delay
	delay.value_changed.connect(_on_chain_delay_changed.bind(row_index))
	row.add_child(delay)
	var remove := Button.new()
	remove.text = "X"
	remove.pressed.connect(_on_chain_removed.bind(row_index))
	row.add_child(remove)
	return row

## Appends a follow-up pointing at an existing move and pops open the target
## picker, so the row always points at something already created.
func _add_follow_up() -> void:
	if _loading or current_move == null:
		return
	var link := BossFollowUp.new()
	if current_boss != null and not current_boss.moves.is_empty():
		link.move_id = current_boss.moves[0].move_id
	var list: Array[BossFollowUp] = _fresh_follow_ups(current_move.follow_ups)
	list.append(link)
	current_move.follow_ups = list
	_save_move()
	_rebuild_chain_box()
	_open_first_chain_pick()

## Pops the newest row's target dropdown open: the "chooser" that only ever
## lists moves the boss already has.
func _open_first_chain_pick() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if chain_box.get_child_count() == 0:
		return
	var row := chain_box.get_child(0) as HBoxContainer
	if row == null:
		return
	for child in row.get_children():
		if child is OptionButton:
			child.popup()
			break

func _on_chain_target_changed(index: int, row_index: int, pick: OptionButton) -> void:
	if _loading or current_move == null or row_index >= current_move.follow_ups.size():
		return
	current_move.follow_ups[row_index].move_id = pick.get_item_text(index)
	_validate()
	_save_move()

func _on_chain_weight_changed(value: float, row_index: int) -> void:
	if _loading or current_move == null or row_index >= current_move.follow_ups.size():
		return
	current_move.follow_ups[row_index].weight = value
	_save_move()

func _on_chain_delay_changed(value: float, row_index: int) -> void:
	if _loading or current_move == null or row_index >= current_move.follow_ups.size():
		return
	current_move.follow_ups[row_index].delay = value
	_save_move()

func _on_chain_removed(row_index: int) -> void:
	if _loading or current_move == null or row_index >= current_move.follow_ups.size():
		return
	var list: Array[BossFollowUp] = _fresh_follow_ups(current_move.follow_ups)
	list.remove_at(row_index)
	current_move.follow_ups = list
	_save_move()
	_rebuild_chain_box()

## Deletes the selected boss file. grave_brute is loaded on boot, so it is
## protected; every other boss is fair game.
func _delete_boss() -> void:
	if current_boss == null:
		return
	if current_boss.boss_id == "grave_brute":
		warning_label.text = "WARNING: grave_brute is the boot boss and cannot be deleted."
		return
	var path := current_boss.resource_path
	if path == "":
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	current_boss = null
	current_move = null
	current_phase = null
	_scan_bosses()

## Removes the selected move: drops it from the moveset when it is in one,
## otherwise deletes the loose file.
func _delete_move() -> void:
	if current_move == null or current_boss == null:
		return
	if current_boss.moves.has(current_move):
		var list: Array[BossMove] = _fresh_moves(current_boss.moves)
		list.erase(current_move)
		current_boss.moves = list
		_save_boss()
	else:
		var path := current_move.resource_path
		if path != "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	current_move = null
	_reload_move_rows()
	_reload_phase_rows()

## Removes the selected phase. A boss always keeps at least one.
func _delete_phase() -> void:
	if current_boss == null or current_phase == null:
		return
	if current_boss.phases.size() <= 1:
		warning_label.text = "WARNING: a boss needs at least one phase."
		return
	var list: Array[BossPhase] = _fresh_phases(current_boss.phases)
	var index := list.find(current_phase)
	if index >= 0:
		list.remove_at(index)
	current_boss.phases = list
	_save_boss()
	current_phase = null
	_reload_phase_rows()