extends Node
## Root controller: menus, zone loading, player spawning, pause, death/respawn,
## save/load entry points. Everything runs offline.

const ZONES := {
	"vale_of_cinders": preload("res://game/maps/vale_of_cinders.gd"),
	"sunken_reliquary": preload("res://game/maps/sunken_reliquary.gd"),
}

var world: Node3D
var zone: Zone = null
var player: Player = null
var camera: CameraRig
var ui: CanvasLayer
var hud: HUD
var screen: Control = null          # current full-screen menu
var inventory_ui: InventoryUI
var character_ui: CharacterUI
var skills_ui: SkillsUI
var quest_ui: QuestUI
var dialogue_ui: DialogueUI
var merchant_ui: MerchantUI
var pause_ui: Control
var settings_ui: Control = null
var lore_ui: Control = null
var death_ui: Control = null
var map_overlay: PanelContainer
var map_full: Minimap
var fade: ColorRect
var menu_stage: Node3D = null
var camera_shake_enabled := true:
	set(v):
		camera_shake_enabled = v
		if camera: camera.shake_enabled = v
var playing := false
var _respawning := false
var _loading := false
var _preview_class := "dawnwarden"


func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	camera = CameraRig.new()
	world.add_child(camera)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = HUD.new()
	hud.visible = false
	ui.add_child(hud)
	inventory_ui = InventoryUI.new()
	character_ui = CharacterUI.new()
	skills_ui = SkillsUI.new()
	quest_ui = QuestUI.new()
	dialogue_ui = DialogueUI.new()
	merchant_ui = MerchantUI.new()
	for w in [inventory_ui, character_ui, skills_ui, quest_ui, dialogue_ui, merchant_ui]:
		ui.add_child(w)
	dialogue_ui.trade_requested.connect(func(n): merchant_ui.start(n))
	_build_map_overlay()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	fade_layer.add_child(fade)
	Events.dialogue_requested.connect(func(n): dialogue_ui.start(n))
	Events.player_died.connect(_on_player_died)
	Game.zone_change_requested.connect(func(z, s): change_zone(z, s))
	Events.game_saved.connect(_on_game_saved)
	show_main_menu()


func _build_map_overlay() -> void:
	map_overlay = PanelContainer.new()
	map_overlay.theme = UITheme.theme()
	map_overlay.set_anchors_preset(Control.PRESET_CENTER)
	map_overlay.anchor_left = 0.5
	map_overlay.anchor_right = 0.5
	map_overlay.anchor_top = 0.5
	map_overlay.anchor_bottom = 0.5
	map_overlay.offset_left = -360
	map_overlay.offset_right = 360
	map_overlay.offset_top = -360
	map_overlay.offset_bottom = 360
	map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_full = Minimap.new()
	map_full.full = true
	map_full.custom_minimum_size = Vector2(700, 700)
	map_overlay.add_child(map_full)
	map_overlay.visible = false
	ui.add_child(map_overlay)


# ---------------------------------------------------------------- screens

func _set_screen(c: Control) -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = c
	if c != null:
		ui.add_child(c)


func show_main_menu() -> void:
	playing = false
	_clear_world()
	hud.visible = false
	_close_windows()
	_ensure_menu_stage()
	_set_screen(Menus.main_menu(self))
	Audio.play_music("music_vale")
	Audio.play_ambience("ambience_wind")


func show_load_menu() -> void:
	_set_screen(Menus.load_menu(self))


func show_character_select() -> void:
	_ensure_menu_stage()
	preview_class("dawnwarden")
	_set_screen(Menus.character_select(self))


func show_settings() -> void:
	if settings_ui and is_instance_valid(settings_ui):
		settings_ui.queue_free()
	settings_ui = Menus.settings_menu(self)
	ui.add_child(settings_ui)


func close_settings() -> void:
	if settings_ui and is_instance_valid(settings_ui):
		settings_ui.queue_free()
	settings_ui = null


func show_lore(title: String, text: String) -> void:
	close_lore()
	lore_ui = Menus.lore_popup(self, title, text)
	ui.add_child(lore_ui)


func close_lore() -> void:
	if lore_ui and is_instance_valid(lore_ui):
		lore_ui.queue_free()
	lore_ui = null


func _ensure_menu_stage() -> void:
	if menu_stage != null and is_instance_valid(menu_stage):
		return
	menu_stage = Node3D.new()
	menu_stage.name = "MenuStage"
	world.add_child(menu_stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.025, 0.02, 0.035)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.3, 0.45)
	e.ambient_light_energy = 0.6
	e.glow_enabled = true
	e.glow_intensity = 1.0
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.08, 0.14)
	e.fog_density = 0.04
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	menu_stage.add_child(env)
	var floor_ := MeshInstance3D.new()
	floor_.mesh = ModelKit.cyl(3.0, 3.4, 0.4, 32)
	floor_.material_override = ModelKit.mat(Color("#2a2630"), 0.0, 0.6, 0.3)
	floor_.position.y = -0.2
	menu_stage.add_child(floor_)
	var ring := MeshInstance3D.new()
	ring.mesh = ModelKit.torus(2.7, 2.9)
	ring.material_override = ModelKit.glow_mat(Color(0.9, 0.7, 0.35), 2.0)
	ring.scale = Vector3(1, 0.1, 1)
	menu_stage.add_child(ring)
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.85, 0.65)
	key.light_energy = 6.0
	key.spot_range = 14.0
	key.spot_angle = 30.0
	key.shadow_enabled = true
	key.position = Vector3(2.5, 6, 4)
	menu_stage.add_child(key)
	key.look_at_from_position(key.position, Vector3(0, 1, 0))
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.5, 0.4, 1.0)
	rim.light_energy = 3.0
	rim.omni_range = 6.0
	rim.position = Vector3(-1.5, 2.5, -2)
	menu_stage.add_child(rim)
	ModelKit.embers(menu_stage, Color(1.0, 0.6, 0.3), 30, Vector3(3, 0.5, 3), Vector3(0, 0.3, 0), 0.6)
	var pivot := Node3D.new()
	pivot.name = "HeroPivot"
	menu_stage.add_child(pivot)
	camera.target = null
	camera.global_position = Vector3(-1.25, 1.45, 3.3)
	camera.look_at(Vector3(-0.85, 0.85, 0), Vector3.UP)
	preview_class(_preview_class)


func preview_class(class_id: String) -> void:
	_preview_class = class_id
	if menu_stage == null or not is_instance_valid(menu_stage):
		return
	var pivot: Node3D = menu_stage.get_node("HeroPivot")
	for c in pivot.get_children():
		c.queue_free()
	var rig := HeroModels.build(class_id)
	pivot.add_child(rig)
	pivot.rotation.y = deg_to_rad(-20)


func _process(delta: float) -> void:
	if menu_stage != null and is_instance_valid(menu_stage):
		var pivot: Node3D = menu_stage.get_node("HeroPivot")
		pivot.rotation.y += delta * 0.25


# ---------------------------------------------------------------- game flow

func start_new_game(class_id: String) -> void:
	Game.new_game(class_id)
	_enter_game()
	hud.notify("Speak with Brother Ivenn at the campfire (E)", Color(1.0, 0.85, 0.4))


func continue_game() -> void:
	var slot := SaveSystem.latest_slot()
	if slot == "":
		return
	load_slot(slot)


func load_slot(slot: String) -> void:
	set_paused(false)
	if not SaveSystem.load_game(slot):
		hud.notify("Could not load save", Color(1, 0.4, 0.4))
		return
	_enter_game()
	hud.notify("Loaded " + ("manual save" if slot == SaveSystem.MANUAL_SLOT else "autosave"), Color(0.7, 1.0, 0.7))


func _enter_game() -> void:
	_set_screen(null)
	if menu_stage and is_instance_valid(menu_stage):
		menu_stage.queue_free()
	menu_stage = null
	playing = true
	hud.visible = true
	_close_windows()
	change_zone(Game.current_zone, Game.current_spawn, Game.player_position)


func change_zone(zone_id: String, spawn_id: String = "start", exact_pos = null) -> void:
	if _loading:
		return
	_loading = true
	if player and is_instance_valid(player):
		player.sync_to_data()
	_clear_world()
	var script = ZONES.get(zone_id, ZONES.vale_of_cinders)
	zone = script.new()
	zone.name = "Zone"
	Game.current_zone = zone.zone_id
	Game.current_spawn = spawn_id
	world.add_child(zone)
	player = Player.new()
	player.setup(Game.character)
	player.camera = camera
	zone.add_child(player)
	var pos: Vector3 = exact_pos if exact_pos is Vector3 else zone.spawn_point(spawn_id)
	player.global_position = pos + Vector3(0, 0.1, 0)
	Game.player = player
	Game.player_position = null
	camera.target = player
	camera.shake_enabled = camera_shake_enabled
	camera.boss_mode = false
	camera.snap()
	hud.bind_player(player)
	Audio.play_music(zone.music)
	if zone.ambience != "":
		Audio.play_ambience(zone.ambience)
	else:
		Audio.ambience_player.stop()
	Events.zone_changed.emit(zone.zone_id)
	hud.notify(zone.display_name, Color(0.85, 0.8, 1.0))
	_loading = false
	_fade_in()
	# autosave on every zone transition (not on the very first frame of a load)
	if exact_pos == null:
		get_tree().create_timer(0.5, false).timeout.connect(_zone_autosave)


func _zone_autosave() -> void:
	if playing and player != null and is_instance_valid(player) and player.is_alive():
		SaveSystem.autosave()


func _on_game_saved(slot: String) -> void:
	if slot == SaveSystem.MANUAL_SLOT:
		hud.notify("Game saved", Color(0.7, 1.0, 0.7))


func _clear_world() -> void:
	Game.player = null
	if zone and is_instance_valid(zone):
		world.remove_child(zone)
		zone.queue_free()
	zone = null
	player = null


func _fade_in() -> void:
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.6)


# ---------------------------------------------------------------- input

func _unhandled_input(ev: InputEvent) -> void:
	if not playing:
		return
	if ev.is_action_pressed("pause"):
		if settings_ui:
			close_settings()
		elif lore_ui:
			close_lore()
		elif _any_window_open():
			_close_windows()
		else:
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return
	if ev.is_action_pressed("inventory"):
		inventory_ui.toggle()
	elif ev.is_action_pressed("character"):
		character_ui.toggle()
	elif ev.is_action_pressed("skills_menu"):
		skills_ui.toggle()
	elif ev.is_action_pressed("quest_log"):
		quest_ui.toggle()
	elif ev.is_action_pressed("map"):
		map_overlay.visible = not map_overlay.visible
	elif ev.is_action_pressed("quick_save"):
		manual_save()


func _any_window_open() -> bool:
	for w in [inventory_ui, character_ui, skills_ui, quest_ui, dialogue_ui, merchant_ui]:
		if w.visible:
			return true
	return map_overlay.visible


func _close_windows() -> void:
	for w in [inventory_ui, character_ui, skills_ui, quest_ui, dialogue_ui, merchant_ui]:
		w.close()
	map_overlay.visible = false
	close_lore()


func set_paused(p: bool) -> void:
	get_tree().paused = p
	if p:
		pause_ui = Menus.pause_menu(self)
		ui.add_child(pause_ui)
	elif pause_ui and is_instance_valid(pause_ui):
		pause_ui.queue_free()
		pause_ui = null


func manual_save() -> bool:
	var ok := SaveSystem.save_game(SaveSystem.MANUAL_SLOT)
	if not ok:
		hud.notify("Save failed", Color(1, 0.4, 0.4))
	return ok


func quit_to_menu() -> void:
	set_paused(false)
	show_main_menu()


func quit_game() -> void:
	get_tree().quit()


func _exit_tree() -> void:
	# release static caches so the engine shuts down without leaked objects
	ModelKit._mesh_cache.clear()
	Props._mats.clear()
	Icons._cache.clear()
	Enemy._tex_cache.clear()
	FloatingText._pool.clear()
	UITheme._theme = null


# ---------------------------------------------------------------- death

func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	death_ui = Menus.death_screen(self)
	ui.add_child(death_ui)
	var lost := int(Game.character.gold * 0.1)
	Game.add_gold(-lost)
	get_tree().create_timer(3.0, false).timeout.connect(_respawn)


func _respawn() -> void:
	if death_ui and is_instance_valid(death_ui):
		death_ui.queue_free()
	death_ui = null
	_respawning = false
	if not playing:
		return
	Game.character.refill()
	# Reload the zone at its entry point: enemies and boss reset, no soft-lock.
	change_zone(Game.current_zone, "start")
	hud.notify("You rise again.", Color(1.0, 0.85, 0.4))
