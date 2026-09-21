extends Node3D

const Joystick = preload("res://scripts/joystick.gd")
const CameraTouchArea = preload("res://scripts/camera_touch_area.gd")
const MultiTouchGestureRouter = preload("res://scripts/multi_touch_gesture_router.gd")
const ArrowScene = preload("res://scenes/weapons/arrow.tscn")
const SwordController = preload("res://scripts/combat/sword_controller.gd")
const HunterSword = preload("res://resources/weapons/hunter_sword.tres")
const PLAYER_SPEED := 4.2
const PLAYER_TURN_SPEED := deg_to_rad(240.0)
const DODGE_SPEED := 11.0
const BOW_TURN_SPEED := deg_to_rad(120.0)
const MAX_HEALTH := 100.0
const MAX_FATIGUE := 100.0

var screen := "hub"
var player: CharacterBody3D
var boss: CharacterBody3D
var camera: Camera3D
var camera_pivot: Node3D
var left_stick: Control
var right_stick: Control
var camera_touch_area: Control
var world_root: Node3D
var interface_root: CanvasLayer
var hud: CanvasLayer
var menu: Control
var status_label: Label
var debug_label: Label
var health_bar: ProgressBar
var fatigue_bar: ProgressBar
var boss_bar: ProgressBar
var boss_state_label: Label
var lock_button: Button
var pause_button: Button
var pause_overlay: Control
var player_weapon: Node3D
var nocked_arrow: Node3D
var multi_touch_router: Control
var bow_state_label: Label
var item_label: Label
var element_label: Label
var sword_controller: Node
var chain_pips: Array[ColorRect] = []
var chain_label: Label
var selected_weapon := "sword"
var bow_charging := false
var bow_charge := 0.0
var bow_aim_direction := Vector3(0, 0, -1)
var bow_shot_count := 0
var bow_element := "NORMAL"
var item_index := 0
var paused := false
var stop_monster := false
var debug_boxes_visible := true
var player_health := MAX_HEALTH
var player_fatigue := MAX_FATIGUE
var boss_health := 160.0
var attack_timer := 0.0
var dodge_direction := Vector3.ZERO
var facing_direction := Vector3(0, 0, -1)
var dodge_timer := 0.0
var invulnerable_timer := 0.0
var boss_attack_timer := 2.2
var boss_telegraph_timer := 0.0
var boss_attacking := false
var boss_phase := 0
var boss_damage_flash_timer := 0.0
var locked := false
var camera_yaw := 0.0
var camera_pitch := -0.22
var camera_touch := false
var camera_touch_id := -1
var camera_last_position := Vector2.ZERO
var save_path := "user://hunting_ground_save.json"
const TEMPO_CONFIG_PATH := "res://resources/config/tempo_config.json"
var fatigue_regen := 13.0

func _ready() -> void:
	world_root = get_node("WorldRoot")
	interface_root = get_node("InterfaceRoot")
	_load_tempo_config()
	load_progress()
	build_hub()

## Loads the global rhythm tuning from resources/config/tempo_config.json.
## Missing file or keys fall back to the TempoChain static defaults.
func _load_tempo_config() -> void:
	if not FileAccess.file_exists(TEMPO_CONFIG_PATH):
		return
	var file := FileAccess.open(TEMPO_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_warning("TEMPO CONFIG: invalid JSON, using defaults")
		return
	TempoChain.early_grace = _config_number(parsed, "early_grace", TempoChain.early_grace)
	TempoChain.late_grace = _config_number(parsed, "late_grace", TempoChain.late_grace)
	TempoChain.input_cooldown = _config_number(parsed, "input_cooldown", TempoChain.input_cooldown)
	TempoChain.stagger_time = _config_number(parsed, "stagger_time", TempoChain.stagger_time)
	TempoChain.lapse_time = _config_number(parsed, "lapse_time", TempoChain.lapse_time)
	TempoChain.yellow_fraction = _config_number(parsed, "yellow_fraction", TempoChain.yellow_fraction)
	TempoChain.weak_before = _config_number(parsed, "weak_before", TempoChain.weak_before)
	TempoChain.quick_scale = _config_number(parsed, "quick_scale", TempoChain.quick_scale)
	fatigue_regen = _config_number(parsed, "fatigue_regen", fatigue_regen)
	print("TEMPO CONFIG: loaded from tempo_config.json")

func _config_number(config: Dictionary, key: String, fallback: float) -> float:
	var value = config.get(key)
	return float(value) if value is float or value is int else fallback

func build_hub() -> void:
	screen = "hub"
	clear_world()
	clear_ui()
	var root := Node3D.new()
	root.name = "Hub"
	world_root.add_child(root)
	make_environment(root, Color("#273b39"))
	add_prop(root, Vector3(-3.0, 0.0, -2.0), "res://assets/kenney/weapon-sword.glb", Vector3(1.2, 1.2, 1.2))
	add_prop(root, Vector3(3.0, 0.0, -1.0), "res://assets/kenney/weapon-sword.glb", Vector3(0.8, 0.8, 0.8))
	var title := make_label("HUNTING GROUND", 42, Color("#e8d6ad"))
	title.position = Vector2(34, 42)
	title.size = Vector2(650, 60)
	menu.add_child(title)
	var subtitle := make_label("A small town. Ten hunts. No easy victories.", 18, Color("#b8c8bf"))
	subtitle.position = Vector2(38, 105)
	subtitle.size = Vector2(640, 40)
	menu.add_child(subtitle)
	var hunt := make_button("PREPARE HUNT", Vector2(38, 1030), Vector2(644, 90))
	hunt.pressed.connect(build_loadout)
	menu.add_child(hunt)
	status_label.text = "HUB  •  BOSS 01 AVAILABLE"

func build_loadout() -> void:
	screen = "loadout"
	clear_world()
	clear_ui()
	var root := Node3D.new()
	world_root.add_child(root)
	make_environment(root, Color("#182a30"))
	var sword := add_prop(root, Vector3(0, 0.8, -2.2), "res://assets/kenney/weapon-sword.glb", Vector3(1.6, 1.6, 1.6))
	if sword:
		sword.rotate_y(0.6)
	var title := make_label("LOADOUT", 38, Color("#e8d6ad"))
	title.position = Vector2(38, 50)
	title.size = Vector2(640, 55)
	menu.add_child(title)
	var info := make_label("WEAPON 01  •  HUNTER'S SWORD\nTempo chain: catch the yellow beat, 3rd input is always a finisher.\nWEAPON 02  •  HUNTER'S BOW\nHold DOWN to charge; LEFT/RIGHT quick dodge shots; UP bow bash.", 19, Color("#d1ddd6"))
	info.position = Vector2(42, 690)
	info.size = Vector2(620, 190)
	menu.add_child(info)
	var sword_choice := make_button("SWORD", Vector2(42, 890), Vector2(190, 60))
	sword_choice.pressed.connect(select_sword)
	menu.add_child(sword_choice)
	var bow_choice := make_button("BOW", Vector2(250, 890), Vector2(190, 60))
	bow_choice.pressed.connect(select_bow)
	menu.add_child(bow_choice)
	var start := make_button("ENTER THE HUNT", Vector2(38, 1030), Vector2(644, 90))
	start.pressed.connect(start_fight)
	menu.add_child(start)
	var back := make_button("BACK", Vector2(38, 925), Vector2(180, 65))
	back.pressed.connect(build_hub)
	menu.add_child(back)
	status_label.text = "LOADOUT  •  SWORD EQUIPPED"

func select_sword() -> void:
	selected_weapon = "sword"
	status_label.text = "LOADOUT  •  SWORD SELECTED"

func select_bow() -> void:
	selected_weapon = "bow"
	status_label.text = "LOADOUT  •  BOW SELECTED"

func start_fight() -> void:
	screen = "fight"
	paused = false
	stop_monster = false
	locked = false
	player_health = MAX_HEALTH
	player_fatigue = MAX_FATIGUE
	boss_health = 160.0
	boss_phase = 0
	bow_charging = false
	bow_charge = 0.0
	bow_shot_count = 0
	nocked_arrow = null
	boss_damage_flash_timer = 0.0
	if sword_controller:
		sword_controller.queue_free()
		sword_controller = null
	clear_world()
	clear_ui()
	build_fight_world()

func build_fight_world() -> void:
	var arena_scene: PackedScene = load("res://scenes/world/arena.tscn")
	var root: Node3D = arena_scene.instantiate()
	root.name = "BossArena"
	world_root.add_child(root)
	make_environment(root, Color("#171c25"))
	player = make_actor("Hunter", Vector3(0, 0.9, 5.0), Color("#799c91"), 1.0)
	root.add_child(player)
	var weapon_path := "res://scenes/weapons/bow.tscn" if selected_weapon == "bow" else "res://scenes/weapons/sword.tscn"
	player_weapon = add_prop(player, Vector3(0.55, 0.1, -0.1), weapon_path, Vector3(0.55, 0.55, 0.55))
	if player_weapon:
		player_weapon.rotation_degrees = Vector3(0, 0, -45)
	boss = make_actor("Grave Brute", Vector3(0, 1.1, -4.0), Color("#8d514d"), 1.55)
	root.add_child(boss)
	var boss_sword := add_prop(boss, Vector3(0.85, 0.2, -0.2), "res://scenes/weapons/sword.tscn", Vector3(0.9, 0.9, 0.9))
	if boss_sword:
		boss_sword.rotation_degrees = Vector3(0, 0, -45)
	camera_pivot = Node3D.new()
	camera_pivot.name = "ThirdPersonCameraAnchor"
	root.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.position = player.global_position + Vector3(0, 4.0, 8.0)
	root.add_child(camera)
	camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	camera.current = true
	make_fight_ui()
	if selected_weapon == "sword":
		sword_controller = SwordController.new()
		sword_controller.setup(self, HunterSword, player, boss)
		sword_controller.status_message.connect(set_status)
		add_child(sword_controller)

func make_environment(root: Node3D, color: Color) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a7b6ad")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(22, 22)
	mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#39463f")
	material.roughness = 0.95
	mesh.material_override = material
	floor_body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(22, 0.2, 22)
	collider.shape = shape
	collider.position.y = -0.1
	floor_body.add_child(collider)
	root.add_child(floor_body)

func make_actor(actor_name: String, actor_position: Vector3, color: Color, scale_value: float) -> CharacterBody3D:
	var scene_path := "res://scenes/actors/player.tscn" if actor_name == "Hunter" else "res://scenes/actors/boss.tscn"
	var actor_scene: PackedScene = load(scene_path)
	var actor: CharacterBody3D = actor_scene.instantiate()
	actor.name = actor_name
	actor.position = actor_position
	actor.scale = Vector3.ONE * scale_value
	var body := actor.get_node("Body") as MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	body.material_override = material
	var debug_hurtbox := actor.get_node("DebugHurtbox") as MeshInstance3D
	var debug_material := StandardMaterial3D.new()
	var debug_color := color
	debug_color.a = 0.22
	debug_material.albedo_color = debug_color
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_hurtbox.material_override = debug_material
	return actor

func add_prop(parent: Node3D, prop_position: Vector3, path: String, scale_value: Vector3) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	var prop: Node3D = scene.instantiate()
	prop.position = prop_position
	prop.scale = scale_value
	parent.add_child(prop)
	return prop

func make_fight_ui() -> void:
	var title := make_label("GRAVE BRUTE", 28, Color("#e8d6ad"))
	title.position = Vector2(30, 25)
	title.size = Vector2(400, 42)
	hud.add_child(title)
	bow_state_label = make_label("BOW  •  DOWN TO CHARGE", 16, Color("#d1ddd6"))
	bow_state_label.position = Vector2(30, 160)
	bow_state_label.size = Vector2(650, 28)
	bow_state_label.visible = selected_weapon == "bow"
	hud.add_child(bow_state_label)
	item_label = make_label("ITEM  •  HERB", 14, Color("#b8c8bf"))
	item_label.position = Vector2(30, 190)
	item_label.size = Vector2(300, 25)
	item_label.visible = selected_weapon == "bow"
	hud.add_child(item_label)
	element_label = make_label("ARROW  •  NORMAL", 14, Color("#b8c8bf"))
	element_label.position = Vector2(360, 190)
	element_label.size = Vector2(300, 25)
	element_label.visible = selected_weapon == "bow"
	hud.add_child(element_label)
	var camera_hint := make_label("DRAG UPPER SCREEN TO ORBIT CAMERA", 14, Color("#b8c8bf"))
	camera_hint.position = Vector2(30, 48)
	camera_hint.size = Vector2(410, 22)
	hud.add_child(camera_hint)
	debug_label = make_label("DEBUG  •  GREEN = HURTBOX  •  YELLOW = SWORD HITBOX", 12, Color("#93a89e"))
	debug_label.position = Vector2(30, 102)
	debug_label.size = Vector2(650, 22)
	hud.add_child(debug_label)
	camera_touch_area = CameraTouchArea.new()
	camera_touch_area.name = "CameraTouchArea"
	camera_touch_area.position = Vector2(0, 155)
	camera_touch_area.size = Vector2(720, 650)
	camera_touch_area.dragged.connect(_on_camera_dragged)
	hud.add_child(camera_touch_area)
	multi_touch_router = MultiTouchGestureRouter.new()
	multi_touch_router.name = "MultiTouchGestureRouter"
	multi_touch_router.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	multi_touch_router.two_finger_swipe.connect(_on_two_finger_swipe)
	hud.add_child(multi_touch_router)
	boss_state_label = make_label("GRAVE BRUTE  •  FRESH", 18, Color("#d1ddd6"))
	boss_state_label.position = Vector2(30, 130)
	boss_state_label.size = Vector2(500, 30)
	hud.add_child(boss_state_label)
	health_bar = make_bar(Color("#5faa6e"), Vector2(30, 1150), Vector2(340, 25))
	health_bar.max_value = MAX_HEALTH
	health_bar.value = player_health
	hud.add_child(health_bar)
	fatigue_bar = make_bar(Color("#d3ad55"), Vector2(30, 1185), Vector2(340, 18))
	fatigue_bar.max_value = MAX_FATIGUE
	fatigue_bar.value = player_fatigue
	hud.add_child(fatigue_bar)
	var health_text := make_label("HEALTH", 15, Color("#d1ddd6"))
	health_text.position = Vector2(380, 1146)
	health_text.size = Vector2(120, 30)
	hud.add_child(health_text)
	var fatigue_text := make_label("FATIGUE", 15, Color("#d1ddd6"))
	fatigue_text.position = Vector2(380, 1180)
	fatigue_text.size = Vector2(120, 30)
	hud.add_child(fatigue_text)
	left_stick = Joystick.new()
	left_stick.position = Vector2(24, 970)
	left_stick.size = Vector2(210, 210)
	left_stick.changed.connect(_on_left_stick)
	hud.add_child(left_stick)
	right_stick = Joystick.new()
	right_stick.position = Vector2(486, 970)
	right_stick.size = Vector2(210, 210)
	right_stick.changed.connect(_on_right_stick)
	right_stick.gesture_released.connect(_on_right_gesture_released)
	hud.add_child(right_stick)
	chain_pips.clear()
	var chain_title := make_label("CHAIN", 12, Color("#93a89e"))
	chain_title.position = Vector2(486, 912)
	chain_title.size = Vector2(210, 16)
	chain_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chain_title.visible = selected_weapon == "sword"
	hud.add_child(chain_title)
	for pip_index in 3:
		var pip := ColorRect.new()
		pip.position = Vector2(499 + pip_index * 64, 930)
		pip.size = Vector2(56, 12)
		pip.color = Color("#39463f")
		pip.visible = selected_weapon == "sword"
		hud.add_child(pip)
		chain_pips.append(pip)
	chain_label = make_label("", 13, Color("#d1ddd6"))
	chain_label.position = Vector2(486, 946)
	chain_label.size = Vector2(210, 20)
	chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chain_label.visible = selected_weapon == "sword"
	hud.add_child(chain_label)
	var dodge := make_button("DODGE", Vector2(535, 835), Vector2(150, 70))
	dodge.pressed.connect(dodge_player)
	hud.add_child(dodge)
	lock_button = make_button("LOCK", Vector2(35, 835), Vector2(150, 70))
	lock_button.pressed.connect(toggle_lock)
	hud.add_child(lock_button)
	pause_button = make_button("PAUSE", Vector2(535, 25), Vector2(150, 55))
	pause_button.pressed.connect(toggle_pause)
	hud.add_child(pause_button)
	make_pause_menu()
	if selected_weapon == "sword":
		set_status("SWORD READY • START THE TEMPO CHAIN")
	else:
		set_status("BOW READY • HOLD DOWN TO CHARGE")

func make_pause_menu() -> void:
	pause_overlay = Control.new()
	pause_overlay.name = "PauseMenu"
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(pause_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.05, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(shade)
	var panel := ColorRect.new()
	panel.color = Color("#1b2b30")
	panel.position = Vector2(24, 150)
	panel.size = Vector2(672, 900)
	pause_overlay.add_child(panel)
	var title := make_label("PAUSED", 42, Color("#e8d6ad"))
	title.position = Vector2(50, 190)
	title.size = Vector2(620, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_overlay.add_child(title)
	var combo_text := "SWORD TEMPO CHAIN\\n\\nEvery combo is ALWAYS 3 hits:\\nINPUT 1 (always normal) + INPUT 2 + FINISHER.\\nExample: LEFT + RIGHT + UP = full combo.\\n\\nCatch the tight YELLOW beat for CRITICAL hits.\\nA narrow band just before it chains a WEAK hit.\\nAnything further off = spam = STAGGER.\\nA 4th input during the finisher does nothing.\\n\\nYou cannot move while swinging or staggered.\\nFinishers unlock movement during their recovery.\\n\\nL / R  •  SLASH      U  •  THRUST      D  •  BACK CUT\\nCIRCLE  •  WHIRLWIND (any slot)\\n\\nFINISHER (3rd input):\\nUP  •  FLURRY      L / R  •  HEAVY SLASH\\nDOWN  •  BACK STEP (invulnerable)      CIRCLE  •  HEAVY WHIRLWIND\\n\\nKeyboard: J K SPACE ; attack • SHIFT dodge • L lock"
	if selected_weapon == "bow":
		combo_text = "BOW COMBO LIST\\n\\nHOLD DOWN  •  CHARGE + RELEASE\\nTHIRD CHARGED SHOT  •  FINISHER\\nLEFT / RIGHT  •  QUICK SHOT + DODGE\\nUP  •  BOW BASH\\n\\nTwo-finger vertical swipe  •  ITEMS\\nTwo-finger horizontal swipe  •  ELEMENTS"
	var combos := make_label(combo_text, 18, Color("#d1ddd6"))
	combos.position = Vector2(65, 285)
	combos.size = Vector2(590, 290)
	pause_overlay.add_child(combos)
	var debug_title := make_label("DEBUG CONTROLS", 20, Color("#e8d6ad"))
	debug_title.position = Vector2(65, 600)
	debug_title.size = Vector2(590, 35)
	pause_overlay.add_child(debug_title)
	var show_boxes := make_button("HIDE BOXES", Vector2(55, 655), Vector2(285, 65))
	show_boxes.pressed.connect(toggle_debug_boxes)
	pause_overlay.add_child(show_boxes)
	var stop_boss := make_button("STOP MONSTER", Vector2(380, 655), Vector2(285, 65))
	stop_boss.pressed.connect(toggle_stop_monster)
	pause_overlay.add_child(stop_boss)
	var refill := make_button("FILL HP + FATIGUE", Vector2(55, 735), Vector2(285, 65))
	refill.pressed.connect(fill_resources)
	pause_overlay.add_child(refill)
	var reset_boss := make_button("RESET BOSS HP", Vector2(380, 735), Vector2(285, 65))
	reset_boss.pressed.connect(reset_boss_health)
	pause_overlay.add_child(reset_boss)
	var resume := make_button("RESUME", Vector2(55, 850), Vector2(610, 75))
	resume.pressed.connect(toggle_pause)
	pause_overlay.add_child(resume)

func toggle_pause() -> void:
	if screen != "fight":
		return
	paused = not paused
	pause_overlay.visible = paused
	pause_button.text = "CLOSE" if paused else "PAUSE"
	if paused:
		set_status("PAUSED • COMBO LIST AND DEBUG CONTROLS OPEN")
	elif selected_weapon == "sword":
		set_status("SWORD READY • START THE TEMPO CHAIN")
	else:
		set_status("BOW READY • HOLD DOWN TO CHARGE")

func toggle_debug_boxes() -> void:
	debug_boxes_visible = not debug_boxes_visible
	if player and player.get_parent():
		for node in player.get_parent().find_children("DebugHurtbox", "MeshInstance3D", true, false):
			node.visible = debug_boxes_visible
		for node in player.get_parent().find_children("DebugSwordHitbox", "MeshInstance3D", true, false):
			node.visible = debug_boxes_visible
	if debug_label:
		debug_label.text = "DEBUG  •  BOXES %s  •  GREEN HURTBOX / YELLOW HITBOX" % ("ON" if debug_boxes_visible else "OFF")

func toggle_stop_monster() -> void:
	stop_monster = not stop_monster
	status_label.text = "DEBUG  •  MONSTER STOPPED" if stop_monster else "DEBUG  •  MONSTER MOVING"

func fill_resources() -> void:
	player_health = MAX_HEALTH
	player_fatigue = MAX_FATIGUE
	status_label.text = "DEBUG  •  HEALTH AND FATIGUE FILLED"
	update_bars()

func reset_boss_health() -> void:
	boss_health = 160.0
	status_label.text = "DEBUG  •  BOSS HEALTH RESET"
	update_bars()

func make_bar(color: Color, bar_position: Vector2, bar_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = bar_position
	bar.size = bar_size
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.07, 0.08, 0.85)
	background.corner_radius_top_left = 8
	background.corner_radius_top_right = 8
	background.corner_radius_bottom_left = 8
	background.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	return bar

func make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func make_button(text_value: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 22)
	return button

func clear_world() -> void:
	if world_root:
		for child in world_root.get_children():
			child.queue_free()
	player = null
	boss = null
	camera = null
	camera_pivot = null
	player_weapon = null

func clear_ui() -> void:
	if not interface_root:
		return
	for child in interface_root.get_children():
		child.queue_free()
	hud = interface_root
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(menu)
	status_label = make_label("", 15, Color("#b8c8bf"))
	status_label.position = Vector2(34, 1228)
	status_label.size = Vector2(650, 30)
	hud.add_child(status_label)
	chain_label = null

func _process(delta: float) -> void:
	if screen != "fight" or not is_instance_valid(player) or not is_instance_valid(boss) or paused:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	boss_telegraph_timer = maxf(0.0, boss_telegraph_timer - delta)
	player_fatigue = minf(MAX_FATIGUE, player_fatigue + delta * fatigue_regen)
	if selected_weapon == "sword" and sword_controller:
		sword_controller.process_weapon(delta)
		var ring_ratio: float = sword_controller.tempo.window_remaining_ratio()
		var ring_zone: String = sword_controller.tempo.current_zone() if ring_ratio >= 0.0 else ""
		_refresh_chain_pips(sword_controller.tempo, ring_zone)
		_refresh_chain_label(sword_controller.tempo)
		if right_stick:
			right_stick.set_link_window(ring_ratio >= 0.0, ring_ratio, ring_zone)
	if selected_weapon == "bow" and bow_charging:
		bow_charge = minf(1.0, bow_charge + delta / 1.4)
		update_bow_aim(delta)
		if bow_state_label:
			bow_state_label.text = "BOW  •  CHARGING %d%%  •  RELEASE DOWN TO FIRE" % roundi(bow_charge * 100.0)
	move_player(delta)
	if not stop_monster:
		update_boss(delta)
	update_camera(delta)
	update_bars()
	if health_bar:
		health_bar.value = player_health
	if fatigue_bar:
		fatigue_bar.value = player_fatigue
	if player_health <= 0.0:
		finish_fight(false)
	elif boss_health <= 0.0:
		finish_fight(true)

func update_bars() -> void:
	if health_bar:
		health_bar.value = player_health
	if fatigue_bar:
		fatigue_bar.value = player_fatigue

func move_player(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if left_stick and left_stick.value.length() > 0.1:
		input = left_stick.value
	var direction := Vector3.ZERO
	if camera:
		var camera_right := camera.global_transform.basis.x
		camera_right.y = 0.0
		camera_right = camera_right.normalized()
		var camera_forward := -camera.global_transform.basis.z
		camera_forward.y = 0.0
		camera_forward = camera_forward.normalized()
		direction = camera_right * input.x + camera_forward * -input.y
	else:
		direction = Vector3(input.x, 0, input.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	if selected_weapon == "bow" and bow_charging:
		player.velocity = Vector3.ZERO
		player.move_and_slide()
		return
	if dodge_timer > 0.0:
		var dodge_vector := dodge_direction if dodge_direction.length() > 0.1 else -player.global_transform.basis.z
		player.velocity = dodge_vector.normalized() * DODGE_SPEED
	else:
		var attack_move_multiplier := 1.0
		if selected_weapon == "sword" and sword_controller and sword_controller.movement_locked():
			attack_move_multiplier = 0.0
		elif attack_timer > 0.0:
			attack_move_multiplier = 0.35
		player.velocity = direction * PLAYER_SPEED * attack_move_multiplier
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -8.5, 8.5)
	player.position.z = clampf(player.position.z, -8.5, 8.5)
	var sword_rooted: bool = selected_weapon == "sword" and sword_controller != null and sword_controller.movement_locked()
	if direction.length() > 0.1 and dodge_timer <= 0.0 and attack_timer <= 0.0 and not sword_rooted:
		var desired_yaw := atan2(-direction.x, -direction.z)
		player.rotation.y = rotate_toward(player.rotation.y, desired_yaw, PLAYER_TURN_SPEED * delta)
		facing_direction = -player.global_transform.basis.z

func update_boss(delta: float) -> void:
	var distance := boss.global_position.distance_to(player.global_position)
	if not boss_attacking and distance > 2.4:
		var direction := boss.global_position.direction_to(player.global_position)
		var boss_speed := 1.3 if boss_phase == 0 else (1.0 if boss_phase == 1 else 0.7)
		boss.velocity = direction * boss_speed
		boss.move_and_slide()
		boss.look_at(Vector3(player.global_position.x, boss.global_position.y, player.global_position.z), Vector3.UP)
	else:
		boss.velocity = Vector3.ZERO
	boss_attack_timer -= delta
	if boss_attack_timer <= 0.0 and not boss_attacking:
		boss_attacking = true
		boss_telegraph_timer = 0.75 if boss_phase == 0 else (0.62 if boss_phase == 1 else 0.5)
		boss_attack_timer = 2.8 if boss_phase == 0 else (2.35 if boss_phase == 1 else 1.95)
		status_label.text = "DANGER  •  GRAVE BRUTE IS COMMITTING TO A STRIKE"
	if boss_attacking and boss_telegraph_timer <= 0.0:
		boss_attacking = false
		if distance < 3.0 and invulnerable_timer <= 0.0:
			player_health -= 18.0
			set_status("HIT • DODGE THROUGH THE ATTACK")

func update_camera(delta: float) -> void:
	if not camera or not player:
		return
	var player_focus := player.global_position + Vector3(0, 1.0, 0)
	var look_target := player_focus
	if locked and boss:
		var to_boss := player.global_position.direction_to(boss.global_position)
		to_boss.y = 0.0
		if to_boss.length() > 0.1:
			to_boss = to_boss.normalized()
			var behind_yaw := atan2(-to_boss.x, -to_boss.z)
			camera_yaw = lerp_angle(camera_yaw, behind_yaw, delta * 8.0)
		look_target = boss.global_position + Vector3(0, 1.0, 0)
	var horizontal_offset := Vector3(sin(camera_yaw), 0, cos(camera_yaw)) * 8.0
	var desired_position := player.global_position + horizontal_offset + Vector3(0, 3.5 - camera_pitch * 4.0, 0)
	camera.global_position = camera.global_position.lerp(desired_position, delta * 6.0)
	camera.look_at(look_target, Vector3.UP)

func _on_camera_dragged(delta: Vector2) -> void:
	camera_yaw -= delta.x * 0.008
	camera_pitch = clampf(camera_pitch - delta.y * 0.004, -0.65, 0.1)

func _on_left_stick(_value: Vector2) -> void:
	pass

func begin_bow_charge() -> void:
	if attack_timer > 0.0 or player_fatigue < 12.0:
		return
	bow_charging = true
	bow_charge = 0.0
	bow_aim_direction = facing_direction
	if nocked_arrow:
		nocked_arrow.queue_free()
	nocked_arrow = MeshInstance3D.new()
	nocked_arrow.name = "NockedArrow"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.035
	shaft.bottom_radius = 0.035
	shaft.height = 1.1
	nocked_arrow.mesh = shaft
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#c58a4a")
	nocked_arrow.material_override = material
	nocked_arrow.position = Vector3(0.65, 0.15, -0.45)
	nocked_arrow.rotation_degrees = Vector3(90, 0, 0)
	player.add_child(nocked_arrow)
	bow_state_label.text = "BOW  •  NOCKED  •  HOLD DOWN TO CHARGE"

func _on_right_stick(value: Vector2) -> void:
	if selected_weapon != "bow":
		return
	if value.y > 0.35 and not bow_charging:
		begin_bow_charge()
	if bow_charging and value.length() > 0.12:
		var aim_direction := Vector3(-value.x, 0, value.y)
		if camera:
			var camera_right := camera.global_transform.basis.x
			camera_right.y = 0.0
			camera_right = camera_right.normalized()
			var camera_forward := -camera.global_transform.basis.z
			camera_forward.y = 0.0
			camera_forward = camera_forward.normalized()
			aim_direction = camera_right * -value.x + camera_forward * value.y
		if aim_direction.length() > 0.12:
			bow_aim_direction = aim_direction.normalized()
		if bow_state_label:
			bow_state_label.text = "BOW  •  CHARGING %d%%  •  AIMING" % roundi(bow_charge * 100.0)

func update_bow_aim(delta: float) -> void:
	if bow_aim_direction.length() <= 0.12:
		return
	var desired_yaw := atan2(-bow_aim_direction.x, -bow_aim_direction.z)
	player.rotation.y = rotate_toward(player.rotation.y, desired_yaw, BOW_TURN_SPEED * delta)
	facing_direction = -player.global_transform.basis.z

func _on_right_gesture_released(value: Vector2, gesture: String, clockwise: bool) -> void:
	if selected_weapon == "bow":
		handle_bow_release(value, gesture)
	elif sword_controller:
		sword_controller.on_gesture(value, gesture, clockwise)

func handle_bow_release(value: Vector2, gesture: String) -> void:
	if gesture == "circle":
		return
	if value.length() <= 0.32:
		return
	if bow_charging:
		fire_charged_bow()
	elif value.x < -0.35 or value.x > 0.35:
		fire_quick_bow(value.x > 0.0)
	elif value.y < -0.35:
		perform_bow_bash()
	bow_charging = false
	bow_charge = 0.0

func arrow_damage_modifier() -> float:
	if bow_element == "FIRE":
		return 1.12
	if bow_element == "ICE":
		return 0.92
	if bow_element == "SHOCK":
		return 1.05
	return 1.0

func fire_charged_bow() -> void:
	if attack_timer > 0.0 or player_fatigue < 12.0:
		status_label.text = "BOW  •  RECOVER BEFORE FIRING"
		return
	if nocked_arrow:
		nocked_arrow.queue_free()
		nocked_arrow = null
	bow_shot_count += 1
	attack_timer = 0.46 + bow_charge * 0.3
	var damage := (16.0 + bow_charge * 44.0) * arrow_damage_modifier()
	var finisher := bow_shot_count >= 3
	if finisher:
		damage *= 1.35
		bow_shot_count = 0
	player_fatigue -= 12.0 + bow_charge * 14.0
	status_label.text = "BOW  •  %s CHARGED SHOT  •  %d%%" % ["FINISHER" if finisher else "", roundi(bow_charge * 100.0)]
	fire_arrow(facing_direction, damage)
	bow_charging = false
	bow_charge = 0.0

func fire_arrow(direction: Vector3, damage: float) -> void:
	if not player or not player.get_parent():
		return
	var arrow: Area3D = ArrowScene.instantiate()
	player.get_parent().add_child(arrow)
	arrow.global_position = player.global_position + direction * 0.9 + Vector3(0, 1.1, 0)
	arrow.setup(direction, damage)
	arrow.struck.connect(_on_arrow_struck)

func _on_arrow_struck(body: Node, damage: float) -> void:
	if body == boss:
		boss_health -= damage
		status_label.text = "ARROW HIT  •  %d DAMAGE" % roundi(damage)
		update_boss_phase()

func fire_quick_bow(to_right: bool) -> void:
	if attack_timer > 0.0 or player_fatigue < 16.0:
		return
	attack_timer = 0.34
	player_fatigue -= 16.0
	var side := Vector3(-facing_direction.z, 0, facing_direction.x) if to_right else Vector3(facing_direction.z, 0, -facing_direction.x)
	dodge_direction = side
	dodge_timer = 0.2
	invulnerable_timer = 0.3
	status_label.text = "BOW  •  QUICK %s SHOT + DODGE" % ("RIGHT" if to_right else "LEFT")
	fire_arrow(facing_direction, 16.0 * arrow_damage_modifier())

func perform_bow_bash() -> void:
	if attack_timer > 0.0 or player_fatigue < 10.0:
		return
	attack_timer = 0.42
	player_fatigue -= 10.0
	status_label.text = "BOW  •  CLOSE-RANGE BASH"
	show_attack_hitbox(facing_direction, 1)
	if player.global_position.distance_to(boss.global_position) < 2.4:
		boss_health -= 14.0
		update_boss_phase()

func _on_two_finger_swipe(axis: String, direction: int) -> void:
	if axis == "vertical":
		item_index = posmod(item_index + direction, 3)
		var items := ["HERB", "TONIC", "SMOKE BOMB"]
		item_label.text = "ITEM  •  %s" % items[item_index]
		status_label.text = "ITEM ROULETTE  •  %s" % items[item_index]
	else:
		var elements := ["NORMAL", "FIRE", "ICE", "SHOCK"]
		var current_index := elements.find(bow_element)
		bow_element = elements[posmod(current_index + direction, elements.size())]
		element_label.text = "ARROW  •  %s" % bow_element
		status_label.text = "ELEMENTAL ARROW  •  %s" % bow_element

## Combat helpers used by the weapon controllers.

func set_status(text_value: String) -> void:
	if status_label:
		status_label.text = text_value

func can_pay(cost: float) -> bool:
	return player_fatigue >= cost

func pay_fatigue(cost: float) -> void:
	player_fatigue = maxf(0.0, player_fatigue - cost)

func boss_distance() -> float:
	if not is_instance_valid(player) or not is_instance_valid(boss):
		return 999.0
	return player.global_position.distance_to(boss.global_position)

func boss_in_front() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(boss):
		return false
	return facing_direction.dot(player.global_position.direction_to(boss.global_position)) > -0.35

func deal_boss_damage(amount: float, push := 0.25) -> void:
	if not is_instance_valid(player) or not is_instance_valid(boss):
		return
	boss_health -= amount
	boss.position += player.global_position.direction_to(boss.global_position) * push
	update_boss_phase()

## Trip finisher: staggers the boss and interrupts a committed strike.
func apply_trip() -> void:
	if not is_instance_valid(boss):
		return
	boss_attacking = false
	boss_telegraph_timer = 0.0
	boss_attack_timer = maxf(boss_attack_timer, 2.2)
	set_status("TRIPPED • GRAVE BRUTE STAGGERS")

func defensive_step(step: String) -> void:
	dodge_direction = -facing_direction if step == "back" else (Vector3(-facing_direction.z, 0, facing_direction.x) if step == "right" else Vector3(facing_direction.z, 0, -facing_direction.x))
	dodge_timer = 0.24
	invulnerable_timer = 0.42

func _refresh_chain_label(chain: TempoChain) -> void:
	if chain_label == null:
		return
	if chain.staggered():
		chain_label.text = "STAGGERED"
		chain_label.add_theme_color_override("font_color", Color("#c0503f"))
		return
	if not chain.is_busy():
		chain_label.text = ""
		return
	var text := "CHAIN %d/3" % chain.slot()
	var color := Color("#d1ddd6")
	if chain.tier == TempoChain.TIER_JUST:
		text += " • CRITICAL"
		color = Color("#ffd24a")
	elif chain.tier == TempoChain.TIER_QUICK:
		text += " • WEAK"
		color = Color("#8a9a92")
	chain_label.text = text
	chain_label.add_theme_color_override("font_color", color)

## Floating hit-quality feedback above the boss ("CRITICAL" / "WEAK").
func spawn_hit_popup(quality: String) -> void:
	if quality == "" or not is_instance_valid(boss) or not boss.get_parent():
		return
	var popup := Label3D.new()
	popup.text = quality
	popup.font_size = 128
	popup.outline_size = 30
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	popup.modulate = Color("#ffd24a") if quality == "CRITICAL" else Color(0.62, 0.72, 0.68)
	boss.get_parent().add_child(popup)
	popup.global_position = boss.global_position + Vector3(randf_range(-0.35, 0.35), 2.9, 0)
	var tween := create_tween()
	tween.tween_property(popup, "global_position", popup.global_position + Vector3(0, 0.65, 0), 0.55)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.55)
	tween.tween_callback(popup.queue_free)

func _refresh_chain_pips(chain: TempoChain, zone: String) -> void:
	if chain_pips.is_empty():
		return
	var ticks := int(Time.get_ticks_msec() / 140)
	var hot: bool = zone != "" and zone != "stagger" and ticks % 2 == 0
	var blink_red: bool = int(Time.get_ticks_msec() / 120) % 2 == 0
	# The 3 pips map to the combo's 3 swings. Pip 1 lights as soon as input 1
	# starts the combo; the pip after the last landed swing pulses while the
	# player can chain (gray = weak band, gold = critical beat).
	var lit := chain.slot() if chain.is_busy() else 0
	for index in chain_pips.size():
		var color := Color("#39463f")
		if chain.staggered():
			color = Color("#c0503f") if blink_red else Color("#7a2f26")
		elif index < lit:
			color = Color("#d3ad55")
		elif index == lit and hot:
			color = Color("#ffe08a") if zone == "critical" else Color("#8a9a92")
		chain_pips[index].color = color

func show_whirlwind_hitbox(clockwise: bool) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree() or not player.get_parent():
		return
	var hitbox := MeshInstance3D.new()
	hitbox.name = "DebugSwordHitbox"
	var hit_mesh := CylinderMesh.new()
	hit_mesh.top_radius = 2.5
	hit_mesh.bottom_radius = 2.5
	hit_mesh.height = 1.5
	hitbox.mesh = hit_mesh
	var hit_material := StandardMaterial3D.new()
	hit_material.albedo_color = Color(1.0, 0.55, 0.1, 0.32)
	hit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hitbox.material_override = hit_material
	player.get_parent().add_child(hitbox)
	hitbox.global_position = player.global_position + Vector3(0, 0.75, 0)
	var rotation_tween := create_tween()
	rotation_tween.tween_property(hitbox, "rotation:y", TAU if clockwise else -TAU, 0.65)
	get_tree().create_timer(0.72).timeout.connect(hitbox.queue_free)
func update_boss_phase() -> void:
	var next_phase := 0
	if boss_health <= 105.0:
		next_phase = 1
	if boss_health <= 52.0:
		next_phase = 2
	if next_phase == boss_phase or not boss:
		return
	boss_phase = next_phase
	var body := boss.get_node("Body") as MeshInstance3D
	var material := StandardMaterial3D.new()
	material.roughness = 0.88
	if boss_phase == 1:
		material.albedo_color = Color("#b36d46")
		boss.rotation_degrees.z = -5.0
		boss_state_label.text = "GRAVE BRUTE  •  WOUNDED  •  ATTACKS ACCELERATE"
	elif boss_phase == 2:
		material.albedo_color = Color("#613f4b")
		boss.rotation_degrees.z = -12.0
		boss_state_label.text = "GRAVE BRUTE  •  IMPAIRED  •  MOVEMENT DAMAGED"
	body.material_override = material

func animate_sword_attack(direction: Vector2) -> void:
	if not is_instance_valid(player_weapon) or not player_weapon.is_inside_tree():
		return
	player_weapon.rotation_degrees = Vector3(0, 0, -45)
	var target_rotation := Vector3(0, 0, -45)
	if absf(direction.x) > absf(direction.y):
		target_rotation.z += 105.0 if direction.x > 0.0 else -105.0
	else:
		target_rotation.x = -75.0 if direction.y < 0.0 else 75.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player_weapon, "rotation_degrees", target_rotation, 0.12)
	tween.tween_property(player_weapon, "rotation_degrees", Vector3(0, 0, -45), 0.24)

func show_attack_hitbox(direction: Vector3, combo_index: int) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree() or not player.get_parent():
		return
	var hitbox := MeshInstance3D.new()
	hitbox.name = "DebugSwordHitbox"
	var hit_mesh := BoxMesh.new()
	hit_mesh.size = Vector3(1.8 + combo_index * 0.18, 1.4, 2.4 + combo_index * 0.3)
	hitbox.mesh = hit_mesh
	var hit_material := StandardMaterial3D.new()
	hit_material.albedo_color = Color(1.0, 0.82, 0.12, 0.32)
	hit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hitbox.material_override = hit_material
	player.get_parent().add_child(hitbox)
	hitbox.global_position = player.global_position + direction * 1.25 + Vector3(0, 1.0, 0)
	hitbox.rotation.y = atan2(-direction.x, -direction.z)
	get_tree().create_timer(0.2).timeout.connect(hitbox.queue_free)
	if debug_label:
		debug_label.text = "DEBUG  •  YELLOW HITBOX  •  %s  •  COMBO %d" % [direction, combo_index]

func dodge_player() -> void:
	if dodge_timer > 0.0 or player_fatigue < 20.0:
		return
	if sword_controller and sword_controller.is_staggered():
		set_status("STAGGERED • NO DODGING")
		return
	if sword_controller:
		if sword_controller.is_committed():
			set_status("LOCKED • FINISH THE SWING FIRST")
			return
		if sword_controller.is_recovering():
			sword_controller.cancel_for_dodge()
	dodge_direction = facing_direction
	dodge_timer = 0.24
	invulnerable_timer = 0.4
	player_fatigue -= 20.0
	set_status("DODGE • INVULNERABLE")

func toggle_lock() -> void:
	locked = not locked
	lock_button.text = "UNLOCK" if locked else "LOCK"
	status_label.text = "LOCK-ON  •  CAMERA FOCUSED" if locked else "LOCK-ON RELEASED"

func finish_fight(victory: bool) -> void:
	screen = "result"
	if sword_controller:
		sword_controller.queue_free()
		sword_controller = null
	if victory:
		mark_boss_defeated()
	clear_ui()
	var panel := ColorRect.new()
	panel.color = Color("#111a1e")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(panel)
	var title := make_label("VICTORY" if victory else "HUNT FAILED", 46, Color("#e8d6ad"))
	title.position = Vector2(38, 280)
	title.size = Vector2(644, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var detail := make_label("The first hunt is complete." if victory else "Study the telegraph. Recover your fatigue. Try again.", 20, Color("#c6d2ca"))
	detail.position = Vector2(45, 380)
	detail.size = Vector2(630, 80)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(detail)
	var retry := make_button("RETURN TO HUB", Vector2(38, 1030), Vector2(644, 90))
	retry.pressed.connect(build_hub)
	menu.add_child(retry)
	status_label.text = "RESULT"

func mark_boss_defeated() -> void:
	var data := load_progress()
	data["boss_01_defeated"] = true
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func load_progress() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _input(event: InputEvent) -> void:
	if screen != "fight":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if selected_weapon == "sword" and sword_controller:
			if event.keycode == KEY_SPACE:
				sword_controller.request_technique("U")
			elif event.keycode == KEY_J:
				sword_controller.request_technique("L")
			elif event.keycode == KEY_K:
				sword_controller.request_technique("R")
			elif event.keycode == KEY_SEMICOLON:
				sword_controller.request_technique("D")
		if event.keycode == KEY_SHIFT:
			dodge_player()
		elif event.keycode == KEY_L:
			toggle_lock()
		elif event.keycode == KEY_P:
			toggle_pause()
