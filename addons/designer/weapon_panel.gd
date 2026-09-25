@tool
extends VBoxContainer

## Weapon tab of the Designer: hand-craft WeaponDefinitions and their attacks.
## An attack carries a chain layer (first / 2nd / finisher) and may hold a skill
## from the weapon's own skill list. Follow-ups are ordered auto-combo steps.
## Every change writes straight to the .tres file.

const WEAPONS_DIR := "res://resources/weapons"
const SKILLS_DIR := "res://resources/skills"
const STRIP := preload("res://addons/designer/timeline_strip.gd")
const DEFAULT_TEMPO := {"yellow_fraction": 0.25, "weak_before": 0.09, "early_grace": 0.06}
const DIRECTIONS := ["L", "R", "U", "D"]
const DIR_NAMES := {"L": "LEFT", "R": "RIGHT", "U": "UP", "D": "DOWN"}
const CONTAINERS := ["moves", "second_moves", "finishers"]
const STAGE_NAMES := ["FIRST", "2ND", "FINISHER"]
const ASSIGN_TARGETS := ["LEFT", "RIGHT", "UP", "DOWN", "CIRCLE"]
const SHAPE_NAMES := ["SPHERE", "BOX", "CAPSULE"]
const STATUS_EFFECTS := ["NONE", "BURN", "BLEED", "POISON", "STUN", "SLOW"]
const ANIMATION_NAMES := [
	"",
	"slash_l",
	"slash_r",
	"slash_u",
	"slash_d",
	"flurry",
	"whirlwind",
	"heavy_slash",
	"back_step",
	"quick_dodge",
	"brute_swing",
	"brute_lunge"
]
const SKILL_KIND_NAMES := ["BACK STEP", "QUICK DODGE"]

var weapon_list: ItemList
var attack_list: ItemList
var skill_list: ItemList
var assign_button: OptionButton
var strip
var warning_label: Label
var info_label: Label
var fields := {}
var vector_fields := {}
var pick_fields := {}
var name_edit: LineEdit
var stage_pick: OptionButton
var skill_pick: OptionButton
var attack_editor: VBoxContainer
var combat_panel: VBoxContainer
var hits_caption: Label
var add_hit_row: HBoxContainer
var hits_box: VBoxContainer
var followup_caption: Label
var followup_box: VBoxContainer
var skill_editor: VBoxContainer
var skill_fields := {}
var skill_name_edit: LineEdit
var skill_kind_pick: OptionButton
var skill_anim_pick: OptionButton

var weapons: Array[WeaponDefinition] = []
## One entry per attack row: {attack, container, key}.
var rows: Array[Dictionary] = []
var current_weapon: WeaponDefinition
var current_attack: AttackDefinition
var current_skill: SkillDefinition
var current_container := ""
var current_key := ""
var tempo := {}
var _loading := false

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_tempo()
	_build_ui()
	_scan_weapons()

## Reads the player-side zone sizes so the strip shows the same gold/gray/red
## split the game draws on the joystick ring.
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
	split.split_offset = 340
	add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left_scroll.add_child(left)
	left.add_child(_make_caption("WEAPONS"))
	weapon_list = ItemList.new()
	weapon_list.custom_minimum_size = Vector2(0, 64)
	weapon_list.item_selected.connect(_on_weapon_selected)
	left.add_child(weapon_list)
	left.add_child(_make_caption("ATTACKS"))
	attack_list = ItemList.new()
	attack_list.custom_minimum_size = Vector2(0, 220)
	attack_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attack_list.item_selected.connect(_on_attack_selected)
	left.add_child(attack_list)
	var make_row := HBoxContainer.new()
	var new_button := Button.new()
	new_button.text = "NEW ATTACK"
	new_button.pressed.connect(_new_attack)
	make_row.add_child(new_button)
	var copy_button := Button.new()
	copy_button.text = "DUPLICATE"
	copy_button.pressed.connect(_duplicate_attack)
	make_row.add_child(copy_button)
	var delete_button := Button.new()
	delete_button.text = "DELETE"
	delete_button.pressed.connect(_delete_attack)
	make_row.add_child(delete_button)
	left.add_child(make_row)
	var assign_row := HBoxContainer.new()
	assign_row.add_child(_make_caption("ASSIGN TO"))
	assign_button = OptionButton.new()
	for target in ASSIGN_TARGETS:
		assign_button.add_item(target)
	assign_button.item_selected.connect(_on_assign)
	assign_row.add_child(assign_button)
	left.add_child(assign_row)
	left.add_child(_make_caption("SKILLS (THIS WEAPON)"))
	skill_list = ItemList.new()
	skill_list.custom_minimum_size = Vector2(0, 96)
	skill_list.item_selected.connect(_on_skill_selected)
	left.add_child(skill_list)
	var skill_buttons := HBoxContainer.new()
	var new_skill_button := Button.new()
	new_skill_button.text = "NEW SKILL"
	new_skill_button.pressed.connect(_new_skill)
	skill_buttons.add_child(new_skill_button)
	var remove_skill_button := Button.new()
	remove_skill_button.text = "REMOVE"
	remove_skill_button.pressed.connect(_remove_skill)
	skill_buttons.add_child(remove_skill_button)
	left.add_child(skill_buttons)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(520, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	_build_attack_editor(right)
	_build_skill_editor(right)

func _build_attack_editor(parent: Control) -> void:
	attack_editor = VBoxContainer.new()
	parent.add_child(attack_editor)
	var name_row := HBoxContainer.new()
	name_row.add_child(_make_caption("NAME"))
	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)
	attack_editor.add_child(name_row)
	var stage_row := HBoxContainer.new()
	stage_row.add_child(_make_caption("CHAIN LAYER"))
	stage_pick = OptionButton.new()
	for stage_name in STAGE_NAMES:
		stage_pick.add_item(stage_name)
	stage_pick.item_selected.connect(_on_stage_changed)
	stage_row.add_child(stage_pick)
	attack_editor.add_child(stage_row)
	strip = STRIP.new()
	strip.custom_minimum_size = Vector2(0, 120)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.zone_dragged.connect(_on_strip_drag)
	strip.edit_committed.connect(_save_attack)
	attack_editor.add_child(strip)
	var timing_grid := GridContainer.new()
	timing_grid.columns = 4
	attack_editor.add_child(timing_grid)
	_make_field(timing_grid, "windup", "WINDUP s", 0.01)
	_make_field(timing_grid, "active", "ACTIVE s", 0.01)
	_make_field(timing_grid, "recovery", "RECOVERY s", 0.01)
	_make_field(timing_grid, "link_open", "LINK OPEN s", 0.01)
	_make_field(timing_grid, "link_close", "LINK CLOSE s", 0.01)
	combat_panel = VBoxContainer.new()
	attack_editor.add_child(combat_panel)
	var combat_grid := GridContainer.new()
	combat_grid.columns = 4
	combat_panel.add_child(combat_grid)
	_make_field(combat_grid, "damage", "DAMAGE", 1.0, 1000.0)
	_make_field(combat_grid, "fatigue_cost", "FATIGUE", 1.0)
	_make_field(combat_grid, "hitbox_lifetime", "HITBOX STAY s", 0.01, 10.0)
	_make_vector_row(combat_panel, "hitbox_size", "HITBOX SIZE")
	var pick_grid := GridContainer.new()
	pick_grid.columns = 4
	combat_panel.add_child(pick_grid)
	_make_pick_field(pick_grid, "hitbox_shape", "SHAPE", SHAPE_NAMES)
	_make_pick_field(pick_grid, "status_effect", "STATUS", STATUS_EFFECTS)
	_make_pick_field(pick_grid, "animation_id", "ANIM", ANIMATION_NAMES)
	var skill_row := HBoxContainer.new()
	skill_row.add_child(_make_caption("SKILL"))
	skill_pick = OptionButton.new()
	skill_pick.item_selected.connect(_on_skill_pick)
	skill_row.add_child(skill_pick)
	attack_editor.add_child(skill_row)
	info_label = Label.new()
	attack_editor.add_child(info_label)
	warning_label = Label.new()
	warning_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.3))
	attack_editor.add_child(warning_label)
	hits_caption = _make_caption("HITS")
	attack_editor.add_child(hits_caption)
	add_hit_row = HBoxContainer.new()
	var add_hit_button := Button.new()
	add_hit_button.text = "+ ADD HIT"
	add_hit_button.pressed.connect(_add_hit)
	add_hit_row.add_child(add_hit_button)
	attack_editor.add_child(add_hit_row)
	hits_box = VBoxContainer.new()
	attack_editor.add_child(hits_box)
	followup_caption = _make_caption("FOLLOW-UP COMBO")
	attack_editor.add_child(followup_caption)
	var add_followup_row := HBoxContainer.new()
	var add_followup_button := Button.new()
	add_followup_button.text = "+ ADD FOLLOW-UP"
	add_followup_button.pressed.connect(_add_follow_up)
	add_followup_row.add_child(add_followup_button)
	attack_editor.add_child(add_followup_row)
	followup_box = VBoxContainer.new()
	attack_editor.add_child(followup_box)

func _build_skill_editor(parent: Control) -> void:
	skill_editor = VBoxContainer.new()
	skill_editor.visible = false
	parent.add_child(skill_editor)
	skill_editor.add_child(_make_caption("SKILL"))
	var name_label := Label.new()
	name_label.text = "NAME"
	skill_editor.add_child(name_label)
	skill_name_edit = LineEdit.new()
	skill_name_edit.text_changed.connect(_on_skill_name_changed)
	skill_editor.add_child(skill_name_edit)
	var skill_grid := GridContainer.new()
	skill_grid.columns = 4
	skill_editor.add_child(skill_grid)
	_make_skill_field(skill_grid, "cast_time", "CAST s", 0.01, 5.0)
	_make_skill_field(skill_grid, "duration", "INVULN s", 0.01, 5.0)
	_make_skill_field(skill_grid, "distance", "DISTANCE m", 0.05, 20.0)
	_make_skill_field(skill_grid, "recovery", "RECOVERY s", 0.05, 10.0)
	_make_skill_field(skill_grid, "fatigue_cost", "FATIGUE", 0.5, 100.0)
	skill_editor.add_child(_make_caption("KIND"))
	skill_kind_pick = OptionButton.new()
	for kind_name in SKILL_KIND_NAMES:
		skill_kind_pick.add_item(kind_name)
	skill_kind_pick.item_selected.connect(_on_skill_kind_changed)
	skill_editor.add_child(skill_kind_pick)
	skill_editor.add_child(_make_caption("ANIMATION"))
	skill_anim_pick = OptionButton.new()
	for anim_name in ANIMATION_NAMES:
		skill_anim_pick.add_item(anim_name)
	skill_anim_pick.item_selected.connect(_on_skill_anim_changed)
	skill_editor.add_child(skill_anim_pick)

func _make_caption(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	return label

## A loaded .tres that omits a list inherits the script default, which Godot
## locks read-only. Build a fresh, correctly typed copy before mutating.
func _fresh_hits(source: Array[AttackHit]) -> Array[AttackHit]:
	var out: Array[AttackHit] = []
	for item in source:
		out.append(item)
	return out

func _fresh_follow_ups(source: Array[AttackFollowUp]) -> Array[AttackFollowUp]:
	var out: Array[AttackFollowUp] = []
	for item in source:
		out.append(item)
	return out

func _fresh_skills(source: Array[SkillDefinition]) -> Array[SkillDefinition]:
	var out: Array[SkillDefinition] = []
	for item in source:
		out.append(item)
	return out

func _fresh_dict(source: Dictionary) -> Dictionary:
	var out := {}
	for key in source.keys():
		out[key] = source[key]
	return out

func _make_field(grid: GridContainer, field: String, caption: String, step: float, max_value := 100.0) -> void:
	var label := Label.new()
	label.text = caption
	grid.add_child(label)
	var box := SpinBox.new()
	box.step = step
	box.max_value = max_value
	box.custom_minimum_size = Vector2(90, 0)
	box.value_changed.connect(_on_field_changed.bind(field))
	grid.add_child(box)
	fields[field] = box

func _make_vector_row(parent: Control, field: String, caption: String) -> void:
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
		box.value_changed.connect(func(_value): _on_vector_changed(field))
		row.add_child(box)
		boxes.append(box)
	vector_fields[field] = boxes
	parent.add_child(row)

func _make_pick_field(grid: GridContainer, field: String, caption: String, options: Array) -> void:
	var label := Label.new()
	label.text = caption
	grid.add_child(label)
	var pick := OptionButton.new()
	for option in options:
		pick.add_item(option)
	pick.item_selected.connect(func(index): _on_pick_changed(index, field))
	grid.add_child(pick)
	pick_fields[field] = pick

func _make_skill_field(grid: GridContainer, field: String, caption: String, step: float, max_value: float) -> void:
	var label := Label.new()
	label.text = caption
	grid.add_child(label)
	var box := SpinBox.new()
	box.step = step
	box.max_value = max_value
	box.custom_minimum_size = Vector2(90, 0)
	box.value_changed.connect(_on_skill_field_changed.bind(field))
	grid.add_child(box)
	skill_fields[field] = box

## Loads every WeaponDefinition in the weapons folder.
func _scan_weapons() -> void:
	weapons.clear()
	weapon_list.clear()
	var files := DirAccess.get_files_at(WEAPONS_DIR)
	if files == null:
		return
	files.sort()
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var def := load(WEAPONS_DIR + "/" + file) as WeaponDefinition
		if def:
			weapons.append(def)
			weapon_list.add_item("%s  (%s)" % [def.display_name, file.get_basename()])
	if weapons.size() > 0:
		weapon_list.select(0)
		_select_weapon(0)

func _on_weapon_selected(index: int) -> void:
	_select_weapon(index)

func _select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	current_weapon = weapons[index]
	current_weapon.moves = _fresh_dict(current_weapon.moves)
	current_weapon.second_moves = _fresh_dict(current_weapon.second_moves)
	current_weapon.finishers = _fresh_dict(current_weapon.finishers)
	current_weapon.skills = _fresh_skills(current_weapon.skills)
	current_attack = null
	current_skill = null
	current_container = ""
	current_key = ""
	_reload_skill_rows()
	_reload_attack_rows()

## Rebuilds the attack rows: the three chain layers, the circle entry, then any
## attack in the folder this weapon does not reference (loose).
func _reload_attack_rows() -> void:
	attack_list.clear()
	rows.clear()
	if current_weapon == null:
		return
	for container_index in CONTAINERS.size():
		var dict: Dictionary = current_weapon.get(CONTAINERS[container_index])
		for key in DIRECTIONS:
			var entry = dict.get(key)
			if entry is AttackDefinition:
				_add_row(_entry_label(DIR_NAMES[key], STAGE_NAMES[container_index], entry), entry, CONTAINERS[container_index], key)
	if current_weapon.circle_move is AttackDefinition:
		var circle: AttackDefinition = current_weapon.circle_move
		_add_row(_entry_label("CIRCLE", "", circle), circle, "circle", "")
	var files := DirAccess.get_files_at(WEAPONS_DIR)
	if files != null:
		for file in files:
			if not file.ends_with(".tres"):
				continue
			var res := load(WEAPONS_DIR + "/" + file)
			if res is AttackDefinition and not _rows_contain(res):
				_add_row("UNASSIGNED — %s" % res.display_name, res, "", "")
	if rows.size() > 0:
		attack_list.select(0)
		_select_attack(0)
	else:
		current_attack = null
		attack_editor.visible = false
		skill_editor.visible = false

func _entry_label(slot: String, stage: String, entry: AttackDefinition) -> String:
	var tag := " (SKILL)" if entry.skill != null else ""
	if stage == "":
		return "%s — %s%s" % [slot, entry.display_name, tag]
	return "%s · %s — %s%s" % [slot, stage, entry.display_name, tag]

func _rows_contain(entry: AttackDefinition) -> bool:
	for row in rows:
		if row.attack == entry:
			return true
	return false

func _add_row(text_value: String, attack: AttackDefinition, container: String, key: String) -> void:
	attack_list.add_item(text_value)
	rows.append({"attack": attack, "container": container, "key": key})

func _refresh_row_labels() -> void:
	for i in rows.size():
		var row: Dictionary = rows[i]
		var entry: AttackDefinition = row.attack
		var slot := "UNASSIGNED"
		var stage := ""
		if row.container == "circle":
			slot = "CIRCLE"
		elif row.container != "":
			slot = DIR_NAMES.get(row.key, row.key)
			if CONTAINERS.has(row.container):
				stage = STAGE_NAMES[CONTAINERS.find(row.container)]
		attack_list.set_item_text(i, _entry_label(slot, stage, entry))

func _on_attack_selected(index: int) -> void:
	_select_attack(index)

func _select_attack(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	var row: Dictionary = rows[index]
	current_attack = row.attack
	current_container = row.container
	current_key = row.key
	skill_list.deselect_all()
	_sync_from_attack()

## Pushes the selected attack into the strip, the fields, and the labels. In
## skill mode the attack combat fields hide and the skill editor shows.
func _sync_from_attack() -> void:
	if current_attack == null:
		attack_editor.visible = false
		skill_editor.visible = false
		return
	current_attack.hits = _fresh_hits(current_attack.hits)
	current_attack.follow_ups = _fresh_follow_ups(current_attack.follow_ups)
	attack_editor.visible = true
	_loading = true
	name_edit.text = current_attack.display_name
	stage_pick.select(clampi(int(current_attack.chain_stage), 0, STAGE_NAMES.size() - 1))
	for field in fields.keys():
		var value = current_attack.get(field)
		if value != null:
			fields[field].value = value
	for field in vector_fields.keys():
		var vector: Vector3 = current_attack.get(field)
		var boxes: Array = vector_fields[field]
		boxes[0].value = vector.x
		boxes[1].value = vector.y
		boxes[2].value = vector.z
	for field in pick_fields.keys():
		_pick_select(field)
	_loading = false
	var skill_mode := current_attack.skill != null
	combat_panel.visible = not skill_mode
	hits_caption.visible = not skill_mode
	add_hit_row.visible = not skill_mode
	hits_box.visible = not skill_mode
	current_skill = current_attack.skill
	_rebuild_skill_pick()
	if skill_mode:
		_fill_skill_editor(current_skill)
		skill_editor.visible = true
	else:
		skill_editor.visible = false
	strip.set_attack(current_attack, tempo)
	_refresh_info()
	_validate()
	_rebuild_hit_box()
	_rebuild_followup_box()

func _pick_select(field: String) -> void:
	var pick: OptionButton = pick_fields[field]
	match field:
		"hitbox_shape":
			pick.select(clampi(int(current_attack.hitbox_shape), 0, SHAPE_NAMES.size() - 1))
		"status_effect":
			var effect_index := STATUS_EFFECTS.find(current_attack.status_effect)
			pick.select(effect_index if effect_index >= 0 else 0)
		"animation_id":
			var anim_index := ANIMATION_NAMES.find(current_attack.animation_id)
			pick.select(anim_index if anim_index >= 0 else 0)

func _refresh_info() -> void:
	if current_attack == null:
		info_label.text = ""
		return
	if current_attack.skill != null:
		info_label.text = "SKILL ENTRY — %s  •  cast %.2fs" % [current_attack.skill.display_name, current_attack.skill.cast_time]
		return
	var total := current_attack.windup + current_attack.active + current_attack.recovery
	var link_span := current_attack.link_close - current_attack.link_open
	var text := "SWING %.2fs  •  LINK %.2fs  •  HIT AT %.2fs" % [total, link_span, current_attack.windup + current_attack.active]
	if current_attack.hits.size() > 0:
		text += "  •  %d HITS" % current_attack.hits.size()
	if current_attack.status_effect != "":
		text += "  •  %s" % current_attack.status_effect
	if not current_attack.chains:
		text += "  •  NO CHAIN"
	info_label.text = text

func _validate() -> void:
	var notes: Array[String] = []
	if current_attack != null and current_attack.skill == null:
		if current_attack.chains:
			if current_attack.link_close <= current_attack.link_open:
				notes.append("link window closes before it opens")
			if current_attack.link_open < current_attack.windup + current_attack.active:
				notes.append("link window opens during the hit — presses there are spam staggers")
		for link in current_attack.follow_ups:
			if link.attack == null:
				notes.append("a follow-up has no target")
	warning_label.text = "WARNING: " + " / ".join(notes) if notes.size() > 0 else ""

func _on_name_changed(text_value: String) -> void:
	if _loading or current_attack == null:
		return
	current_attack.display_name = text_value
	_save_attack()
	_refresh_row_labels()

func _on_stage_changed(index: int) -> void:
	if _loading or current_attack == null:
		return
	var moved := current_attack
	moved.chain_stage = index
	if current_container != "" and current_container != "circle":
		var key := current_key
		_remove_entry(moved)
		var container: String = CONTAINERS[clampi(index, 0, CONTAINERS.size() - 1)]
		var dict := _fresh_dict(current_weapon.get(container))
		dict[key] = moved
		current_weapon.set(container, dict)
		current_container = container
		_save_weapon()
		_save_attack()
		_reload_attack_rows()
		_reselect_attack(moved)
	else:
		_save_attack()
		_sync_from_attack()

func _on_field_changed(value: float, field: String) -> void:
	if _loading or current_attack == null:
		return
	current_attack.set(field, value)
	_sync_from_attack()
	_save_attack()

func _on_vector_changed(field: String) -> void:
	if _loading or current_attack == null:
		return
	var boxes: Array = vector_fields[field]
	current_attack.set(field, Vector3(boxes[0].value, boxes[1].value, boxes[2].value))
	_sync_from_attack()
	_save_attack()

func _on_pick_changed(index: int, field: String) -> void:
	if _loading or current_attack == null:
		return
	match field:
		"hitbox_shape":
			current_attack.hitbox_shape = index
		"status_effect":
			current_attack.status_effect = "" if index == 0 else STATUS_EFFECTS[index]
		"animation_id":
			current_attack.animation_id = ANIMATION_NAMES[index] if index > 0 else ""
	_sync_from_attack()
	_save_attack()

func _on_strip_drag(field: String, value: float) -> void:
	if _loading or current_attack == null:
		return
	current_attack.set(field, value)
	_sync_from_attack()

func _save_attack() -> void:
	if current_attack == null or current_attack.resource_path == "":
		return
	var err := ResourceSaver.save(current_attack, current_attack.resource_path)
	if err != OK:
		warning_label.text = "SAVE FAILED (%s)" % error_string(err)
		return
	if warning_label.text.begins_with("SAVE FAILED"):
		warning_label.text = ""

## Removes an entry from every place it is assigned on the current weapon.
func _remove_entry(entry: AttackDefinition) -> void:
	for container in CONTAINERS:
		var dict := _fresh_dict(current_weapon.get(container))
		var changed := false
		for key in dict.keys():
			if dict[key] == entry:
				dict.erase(key)
				changed = true
		if changed:
			current_weapon.set(container, dict)
	if current_weapon.circle_move == entry:
		current_weapon.circle_move = null

## Assigns the selected attack to a direction. The attack's own chain layer
## decides which press it plays on; assigning to CIRCLE sets the circle move.
func _on_assign(target: int) -> void:
	if _loading or current_weapon == null or current_attack == null:
		return
	var entry := current_attack
	_remove_entry(entry)
	if target >= 4:
		current_weapon.circle_move = entry
	else:
		var key: String = DIRECTIONS[clampi(target, 0, DIRECTIONS.size() - 1)]
		var container: String = CONTAINERS[clampi(int(entry.chain_stage), 0, CONTAINERS.size() - 1)]
		var dict := _fresh_dict(current_weapon.get(container))
		dict[key] = entry
		current_weapon.set(container, dict)
	_save_weapon()
	_reload_attack_rows()
	_reselect_attack(entry)

## Writes a blank AttackDefinition and leaves it loose for assigning.
func _new_attack() -> void:
	var id := ""
	for i in range(1, 100):
		id = "new_attack_%d" % i
		if not FileAccess.file_exists(WEAPONS_DIR + "/" + id + ".tres"):
			break
	var attack := AttackDefinition.new()
	attack.attack_id = id
	attack.display_name = "New Attack"
	attack.chain_stage = AttackDefinition.ChainStage.FIRST
	attack.fatigue_cost = 12.0
	attack.recovery = 0.5
	attack.windup = 0.15
	attack.active = 0.1
	attack.link_open = 0.28
	attack.link_close = 0.68
	attack.chain_scale = Vector3(1.0, 1.25, 1.6)
	attack.chains = true
	var err := ResourceSaver.save(attack, WEAPONS_DIR + "/" + id + ".tres")
	if err != OK:
		warning_label.text = "SAVE FAILED (%s)" % error_string(err)
		return
	_reload_attack_rows()
	_reselect_attack(load(WEAPONS_DIR + "/" + id + ".tres") as AttackDefinition)

## Copies the selected attack to a new .tres and leaves it loose.
func _duplicate_attack() -> void:
	if current_attack == null:
		return
	var base := current_attack.attack_id
	if base == "":
		base = "attack"
	var id: String = base + "_copy"
	for i in range(2, 100):
		if not FileAccess.file_exists(WEAPONS_DIR + "/" + id + ".tres"):
			break
		id = "%s_copy_%d" % [base, i]
	var copy := current_attack.duplicate(true) as AttackDefinition
	copy.attack_id = id
	copy.display_name = current_attack.display_name + " copy"
	ResourceSaver.save(copy, WEAPONS_DIR + "/" + id + ".tres")
	_reload_attack_rows()
	_reselect_attack(load(WEAPONS_DIR + "/" + id + ".tres") as AttackDefinition)

## Removes the selected attack: unassigns it from the weapon when it is bound,
## otherwise deletes the loose .tres file.
func _delete_attack() -> void:
	if current_attack == null or current_weapon == null:
		return
	var entry := current_attack
	if current_container != "":
		_remove_entry(entry)
		_save_weapon()
	else:
		var path := entry.resource_path
		if path != "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	current_attack = null
	current_container = ""
	current_key = ""
	_reload_attack_rows()

func _reselect_attack(entry: AttackDefinition) -> void:
	for i in rows.size():
		if rows[i].attack == entry:
			attack_list.select(i)
			_select_attack(i)
			return

func _save_weapon() -> void:
	if current_weapon == null or current_weapon.resource_path == "":
		return
	ResourceSaver.save(current_weapon, current_weapon.resource_path)

# --- Skills -----------------------------------------------------------------

func _on_skill_selected(index: int) -> void:
	_select_skill(index)

func _select_skill(index: int) -> void:
	if current_weapon == null or index < 0 or index >= current_weapon.skills.size():
		return
	current_skill = current_weapon.skills[index]
	current_attack = null
	attack_list.deselect_all()
	attack_editor.visible = false
	skill_editor.visible = true
	_fill_skill_editor(current_skill)

func _sync_from_skill() -> void:
	if current_skill == null:
		skill_editor.visible = false
		return
	attack_editor.visible = false
	skill_editor.visible = true
	_fill_skill_editor(current_skill)

func _fill_skill_editor(skill: SkillDefinition) -> void:
	if skill == null:
		skill_editor.visible = false
		return
	_loading = true
	skill_name_edit.text = skill.display_name
	skill_kind_pick.select(clampi(int(skill.kind), 0, SKILL_KIND_NAMES.size() - 1))
	for field in skill_fields.keys():
		var value = skill.get(field)
		if value != null:
			skill_fields[field].value = value
	var anim_index := ANIMATION_NAMES.find(skill.animation_id)
	skill_anim_pick.select(anim_index if anim_index >= 0 else 0)
	_loading = false

func _reload_skill_rows() -> void:
	skill_list.clear()
	if current_weapon == null:
		return
	for skill in current_weapon.skills:
		skill_list.add_item(skill.display_name if skill != null else "(missing)")

func _new_skill() -> void:
	if current_weapon == null:
		return
	var id := ""
	for i in range(1, 100):
		id = "new_skill_%d" % i
		if not FileAccess.file_exists(SKILLS_DIR + "/" + id + ".tres"):
			break
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SKILLS_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SKILLS_DIR))
	var skill := SkillDefinition.new()
	skill.skill_id = id
	skill.display_name = "New Skill"
	skill.kind = SkillDefinition.Kind.BACK_STEP
	var err := ResourceSaver.save(skill, SKILLS_DIR + "/" + id + ".tres")
	if err != OK:
		warning_label.text = "SAVE FAILED (%s)" % error_string(err)
		return
	var loaded := load(SKILLS_DIR + "/" + id + ".tres") as SkillDefinition
	var fresh := _fresh_skills(current_weapon.skills)
	fresh.append(loaded)
	current_weapon.skills = fresh
	_save_weapon()
	_reload_skill_rows()
	var index := current_weapon.skills.find(loaded)
	if index >= 0:
		skill_list.select(index)
		_select_skill(index)

## Drops a skill from this weapon and clears any attack that referenced it.
func _remove_skill() -> void:
	if current_weapon == null or current_skill == null:
		return
	for container in CONTAINERS:
		var dict := _fresh_dict(current_weapon.get(container))
		var changed := false
		for key in dict.keys():
			var entry: AttackDefinition = dict[key]
			if entry != null and entry.skill == current_skill:
				entry.skill = null
				ResourceSaver.save(entry, entry.resource_path)
				changed = true
		if changed:
			current_weapon.set(container, dict)
	if current_weapon.circle_move is AttackDefinition:
		var circle: AttackDefinition = current_weapon.circle_move
		if circle.skill == current_skill:
			circle.skill = null
			ResourceSaver.save(circle, circle.resource_path)
	var fresh := _fresh_skills(current_weapon.skills)
	fresh.erase(current_skill)
	current_weapon.skills = fresh
	_save_weapon()
	current_skill = null
	_reload_skill_rows()
	_reload_attack_rows()

func _on_skill_pick(index: int) -> void:
	if _loading or current_attack == null or current_weapon == null:
		return
	if index <= 0:
		current_attack.skill = null
	elif index - 1 < current_weapon.skills.size():
		current_attack.skill = current_weapon.skills[index - 1]
	_save_attack()
	_sync_from_attack()

func _rebuild_skill_pick() -> void:
	if skill_pick == null:
		return
	skill_pick.clear()
	skill_pick.add_item("NONE")
	var selected := 0
	if current_weapon != null:
		for i in current_weapon.skills.size():
			var skill: SkillDefinition = current_weapon.skills[i]
			skill_pick.add_item(skill.display_name if skill != null else "(missing)")
			if current_attack != null and current_attack.skill == skill:
				selected = i + 1
	skill_pick.select(selected)

func _on_skill_field_changed(value: float, field: String) -> void:
	if _loading or current_skill == null:
		return
	current_skill.set(field, value)
	_save_skill()
	_refresh_info()

func _on_skill_kind_changed(index: int) -> void:
	if _loading or current_skill == null:
		return
	current_skill.kind = index
	_save_skill()

func _on_skill_anim_changed(index: int) -> void:
	if _loading or current_skill == null:
		return
	current_skill.animation_id = ANIMATION_NAMES[index] if index > 0 else ""
	_save_skill()

func _on_skill_name_changed(text_value: String) -> void:
	if _loading or current_skill == null:
		return
	current_skill.display_name = text_value
	_save_skill()
	_reload_skill_rows()
	_rebuild_skill_pick()
	_refresh_row_labels()

func _save_skill() -> void:
	if current_skill == null or current_skill.resource_path == "":
		return
	var err := ResourceSaver.save(current_skill, current_skill.resource_path)
	if err != OK:
		warning_label.text = "SAVE FAILED (%s)" % error_string(err)
		return
	if warning_label.text.begins_with("SAVE FAILED"):
		warning_label.text = ""

# --- Multi-hit sequence -----------------------------------------------------

func _rebuild_hit_box() -> void:
	for child in hits_box.get_children():
		child.queue_free()
	if current_attack == null:
		hits_caption.text = "HITS"
		return
	for i in current_attack.hits.size():
		hits_box.add_child(_make_hit_row(i))
	hits_caption.text = "HITS — %d total (5 = Flurry)" % current_attack.hits.size()

func _make_hit_row(row_index: int) -> HBoxContainer:
	var hit := current_attack.hits[row_index]
	var row := HBoxContainer.new()
	var delay := SpinBox.new()
	delay.min_value = 0.0
	delay.max_value = 5.0
	delay.step = 0.01
	delay.value = hit.delay
	delay.custom_minimum_size = Vector2(70, 0)
	delay.value_changed.connect(func(value): _on_hit_field(value, row_index, "delay"))
	row.add_child(delay)
	var damage := SpinBox.new()
	damage.min_value = 0.0
	damage.max_value = 1000.0
	damage.step = 1.0
	damage.value = hit.damage
	damage.custom_minimum_size = Vector2(80, 0)
	damage.value_changed.connect(func(value): _on_hit_field(value, row_index, "damage"))
	row.add_child(damage)
	var shape := OptionButton.new()
	shape.add_item("INHERIT")
	for name in SHAPE_NAMES:
		shape.add_item(name)
	shape.select(clampi(int(hit.hitbox_shape) + 1, 0, SHAPE_NAMES.size()))
	shape.item_selected.connect(func(index): _on_hit_shape(index, row_index))
	row.add_child(shape)
	var status := OptionButton.new()
	for name in STATUS_EFFECTS:
		status.add_item(name)
	var status_index := STATUS_EFFECTS.find(hit.status_effect)
	status.select(status_index if status_index >= 0 else 0)
	status.item_selected.connect(func(index): _on_hit_status(index, row_index))
	row.add_child(status)
	var remove := Button.new()
	remove.text = "X"
	remove.pressed.connect(func(): _on_hit_removed(row_index))
	row.add_child(remove)
	return row

func _add_hit() -> void:
	if current_attack == null:
		return
	var hit := AttackHit.new()
	var last := current_attack.hits.back() if not current_attack.hits.is_empty() else null
	if last != null:
		hit.delay = last.delay + 0.13
		hit.damage = last.damage
		hit.hitbox_shape = last.hitbox_shape
		hit.status_effect = last.status_effect
	else:
		hit.damage = current_attack.damage if current_attack.damage > 0.0 else 18.0
	var list: Array[AttackHit] = _fresh_hits(current_attack.hits)
	list.append(hit)
	current_attack.hits = list
	_save_attack()
	_rebuild_hit_box()
	_refresh_info()

func _on_hit_field(value: float, row_index: int, field: String) -> void:
	if _loading or current_attack == null or row_index >= current_attack.hits.size():
		return
	current_attack.hits[row_index].set(field, value)
	_refresh_info()
	_save_attack()

func _on_hit_shape(index: int, row_index: int) -> void:
	if _loading or current_attack == null or row_index >= current_attack.hits.size():
		return
	current_attack.hits[row_index].hitbox_shape = -1 if index == 0 else index - 1
	_save_attack()

func _on_hit_status(index: int, row_index: int) -> void:
	if _loading or current_attack == null or row_index >= current_attack.hits.size():
		return
	current_attack.hits[row_index].status_effect = "" if index == 0 else STATUS_EFFECTS[index]
	_save_attack()

func _on_hit_removed(row_index: int) -> void:
	if _loading or current_attack == null or row_index >= current_attack.hits.size():
		return
	var list: Array[AttackHit] = _fresh_hits(current_attack.hits)
	list.remove_at(row_index)
	current_attack.hits = list
	_save_attack()
	_rebuild_hit_box()
	_refresh_info()

# --- Follow-up auto-combo ---------------------------------------------------

func _attack_choices() -> Array[AttackDefinition]:
	var out: Array[AttackDefinition] = []
	var files := DirAccess.get_files_at(WEAPONS_DIR)
	if files == null:
		return out
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var res := load(WEAPONS_DIR + "/" + file)
		if res is AttackDefinition:
			out.append(res)
	return out

func _rebuild_followup_box() -> void:
	for child in followup_box.get_children():
		child.queue_free()
	if current_attack == null:
		followup_caption.text = "FOLLOW-UP COMBO"
		return
	for i in current_attack.follow_ups.size():
		followup_box.add_child(_make_followup_row(i))
	followup_caption.text = "FOLLOW-UP COMBO — auto, in order, depth-first (step %d)" % current_attack.follow_ups.size()

func _make_followup_row(row_index: int) -> HBoxContainer:
	var link := current_attack.follow_ups[row_index]
	var row := HBoxContainer.new()
	var pick := OptionButton.new()
	var choices := _attack_choices()
	var selected := -1
	for i in choices.size():
		var choice: AttackDefinition = choices[i]
		pick.add_item(choice.display_name if choice.display_name != "" else choice.attack_id)
		if choice == link.attack:
			selected = i
	if selected == -1 and link.attack != null:
		pick.add_item(link.attack.display_name + " (missing)")
		selected = pick.item_count - 1
	if selected >= 0:
		pick.select(selected)
	pick.item_selected.connect(func(index): _on_followup_target(index, row_index))
	row.add_child(pick)
	var delay := SpinBox.new()
	delay.min_value = 0.0
	delay.max_value = 10.0
	delay.step = 0.01
	delay.value = link.delay
	delay.custom_minimum_size = Vector2(70, 0)
	delay.tooltip_text = "delay (s)"
	delay.value_changed.connect(func(value): _on_followup_field(value, row_index, "delay"))
	row.add_child(delay)
	var duration := SpinBox.new()
	duration.min_value = 0.0
	duration.max_value = 10.0
	duration.step = 0.01
	duration.value = link.duration
	duration.custom_minimum_size = Vector2(70, 0)
	duration.tooltip_text = "duration (s, 0 = attack length)"
	duration.value_changed.connect(func(value): _on_followup_field(value, row_index, "duration"))
	row.add_child(duration)
	var remove := Button.new()
	remove.text = "X"
	remove.pressed.connect(func(): _on_followup_removed(row_index))
	row.add_child(remove)
	return row

func _add_follow_up() -> void:
	if current_attack == null:
		return
	var link := AttackFollowUp.new()
	var choices := _attack_choices()
	if choices.size() > 0:
		link.attack = choices[0]
	var list: Array[AttackFollowUp] = _fresh_follow_ups(current_attack.follow_ups)
	list.append(link)
	current_attack.follow_ups = list
	_save_attack()
	_rebuild_followup_box()

func _on_followup_target(index: int, row_index: int) -> void:
	if _loading or current_attack == null or row_index >= current_attack.follow_ups.size():
		return
	var choices := _attack_choices()
	if index < choices.size():
		current_attack.follow_ups[row_index].attack = choices[index]
	_validate()
	_save_attack()

func _on_followup_field(value: float, row_index: int, field: String) -> void:
	if _loading or current_attack == null or row_index >= current_attack.follow_ups.size():
		return
	current_attack.follow_ups[row_index].set(field, value)
	_save_attack()

func _on_followup_removed(row_index: int) -> void:
	if _loading or current_attack == null or row_index >= current_attack.follow_ups.size():
		return
	var list: Array[AttackFollowUp] = _fresh_follow_ups(current_attack.follow_ups)
	list.remove_at(row_index)
	current_attack.follow_ups = list
	_save_attack()
	_rebuild_followup_box()
