extends Node
## Session state: the active character, quests and world progression,
## plus the gameplay rules that connect them (XP, loot, quests, rewards).

signal new_game_started
signal zone_change_requested(zone_id: String, spawn_id: String)

const SAVE_VERSION := 1

var character: CharacterData = null
var quests := QuestLog.new()
var world: Dictionary = {}          # world progression flags
var current_zone: String = "vale_of_cinders"
var current_spawn: String = "start"
var player_position = null          # Vector3 or null
var playtime: float = 0.0
var rng := RandomNumberGenerator.new()
var in_game := false
var main: Node = null               # root scene controller (set by main.gd)
var player: Node = null             # active Player node, if any


func _ready() -> void:
	rng.randomize()
	quests.quest_changed.connect(func(qid): Events.quest_updated.emit(qid))
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.area_discovered.connect(_on_area_discovered)
	Events.object_interacted.connect(_on_object_interacted)
	Events.boss_defeated.connect(_on_boss_defeated)


func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		playtime += delta


# ------------------------------------------------------------- lifecycle

func new_game(class_id: String) -> void:
	character = CharacterData.create(class_id)
	_wire_character()
	quests = QuestLog.new()
	quests.quest_changed.connect(func(qid): Events.quest_updated.emit(qid))
	world = {"opened_chests": [], "discovered": [], "interacted": [], "flags": {}, "taken_pickups": []}
	current_zone = "vale_of_cinders"
	current_spawn = "start"
	player_position = null
	playtime = 0.0
	in_game = true
	new_game_started.emit()


func _wire_character() -> void:
	character.leveled_up.connect(func(lv):
		Events.leveled_up.emit(lv)
		Audio.play("level_up"))
	character.stats_changed.connect(func(): Events.stats_changed.emit())
	character.inventory.changed.connect(_on_inventory_changed)
	character.equipment.changed.connect(func():
		Events.equipment_changed.emit()
		Events.stats_changed.emit())


func flag(name: String) -> bool:
	return world.get("flags", {}).get(name, false)


func set_flag(name: String, value: bool = true) -> void:
	if not world.has("flags"):
		world["flags"] = {}
	world.flags[name] = value


func world_list_has(list_name: String, id: String) -> bool:
	return id in world.get(list_name, [])


func world_list_add(list_name: String, id: String) -> void:
	if not world.has(list_name):
		world[list_name] = []
	if not id in world[list_name]:
		world[list_name].append(id)


# ------------------------------------------------------------- rewards

func award_xp(amount: int) -> void:
	if character == null or amount <= 0:
		return
	character.add_xp(amount)
	Events.xp_gained.emit(amount)


func add_gold(amount: int) -> void:
	if character == null or amount == 0:
		return
	character.gold = maxi(0, character.gold + amount)
	Events.gold_changed.emit(character.gold)


## Adds an item to the bag. Returns false if the bag is full.
func give_item(item: Item) -> bool:
	if character == null or item == null:
		return false
	var ok := character.inventory.add(item)
	if ok:
		Events.item_picked_up.emit(item)
	return ok


func give_item_spec(spec: String) -> void:
	# "potion_health:3" style item spec used by quest rewards.
	var parts := spec.split(":")
	var amount := int(parts[1]) if parts.size() > 1 else 1
	if DB.is_stackable(parts[0]):
		give_item(Item.make_stack(parts[0], amount))


func _on_inventory_changed() -> void:
	for qid in quests.active_quests():
		quests.sync_collect(qid, character.inventory)
	Events.inventory_changed.emit()


func _on_enemy_killed(enemy_id: String, tags: Array, xp: int, _pos: Vector3) -> void:
	if character == null:
		return
	character.kills += 1
	award_xp(xp)
	var targets: Array = tags.duplicate()
	targets.append(enemy_id)
	quests.notify("kill", targets)


func _on_area_discovered(area_id: String) -> void:
	if character == null:
		return
	var first := not world_list_has("discovered", area_id)
	world_list_add("discovered", area_id)
	quests.notify("explore", [area_id])
	if first:
		award_xp(20)


func _on_object_interacted(object_id: String) -> void:
	world_list_add("interacted", object_id)
	quests.notify("interact", [object_id])


func _on_boss_defeated(boss_id: String) -> void:
	set_flag("boss_defeated_" + boss_id)
	quests.notify("boss", [boss_id])


# ------------------------------------------------------------- quests

func accept_quest(qid: String) -> bool:
	var ok := quests.accept(qid)
	if ok:
		quests.sync_collect(qid, character.inventory)
		# exploration objectives already satisfied earlier still count
		for obj in DB.get_quest(qid).objectives:
			if obj.type == "explore" and world_list_has("discovered", obj.target):
				quests.notify("explore", [obj.target])
			if obj.type == "interact" and world_list_has("interacted", obj.target):
				quests.notify("interact", [obj.target])
		Events.notify.emit("Quest accepted: " + DB.get_quest(qid).title, Color("#e8c66a"))
		Audio.play("quest")
	return ok


## Turns in a quest and grants rewards exactly once.
func complete_quest(qid: String) -> bool:
	var q := DB.get_quest(qid)
	# collect-objective items are handed over on completion
	var rewards := quests.complete(qid)
	if rewards.is_empty():
		return false
	for obj in q.objectives:
		if obj.type == "collect" and DB.stackable_def(obj.target).get("category", "") == "quest_items":
			# hand over every fragment: they have no use once the quest is done
			character.inventory.consume(obj.target, character.inventory.count_of(obj.target))
		elif obj.type == "collect":
			character.inventory.consume(obj.target, int(obj.count))
	award_xp(int(rewards.get("xp", 0)))
	add_gold(int(rewards.get("gold", 0)))
	for spec in rewards.get("items", []):
		give_item_spec(spec)
	if rewards.has("random_item"):
		var it := ItemGenerator.generate(rng, character.level, rewards.random_item, character.class_data().weapon_type)
		give_item(it)
	if rewards.has("unlock"):
		set_flag(rewards.unlock)
	Events.quest_completed.emit(qid)
	Events.notify.emit("Quest complete: " + q.title, Color("#ffd77a"))
	Audio.play("quest")
	var nxt: String = q.get("next", "")
	if nxt != "":
		accept_quest(nxt)
	if SaveSystem:
		SaveSystem.autosave()
	return true


func needs_item_for_quest(item_id: String) -> bool:
	for qid in quests.active_quests():
		for obj in DB.get_quest(qid).objectives:
			if obj.type == "collect" and obj.target == item_id and character.inventory.count_of(item_id) < int(obj.count):
				return true
	return false


func loot_context() -> Dictionary:
	return {
		"weapon_type": character.class_data().weapon_type if character else "",
		"needs_fragment": needs_item_for_quest("lamp_fragment"),
	}


# ------------------------------------------------------------- zones

func request_zone(zone_id: String, spawn_id: String = "start") -> void:
	current_zone = zone_id
	current_spawn = spawn_id
	player_position = null
	zone_change_requested.emit(zone_id, spawn_id)


# ------------------------------------------------------------- persistence

func to_save_dict() -> Dictionary:
	var pos = null
	if player != null and is_instance_valid(player):
		pos = [player.global_position.x, player.global_position.y, player.global_position.z]
		character.health = player.health
		character.mana = player.mana
	return {
		"version": SAVE_VERSION,
		"game_version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"saved_at": Time.get_datetime_string_from_system(),
		"playtime": playtime,
		"character": character.to_dict(),
		"quests": quests.to_dict(),
		"world": world.duplicate(true),
		"zone": current_zone,
		"spawn": current_spawn,
		"position": pos,
	}


func apply_save_dict(d: Dictionary) -> bool:
	if d.is_empty() or not d.has("character"):
		return false
	character = CharacterData.from_dict(d.character)
	_wire_character()
	quests = QuestLog.new()
	quests.quest_changed.connect(func(qid): Events.quest_updated.emit(qid))
	quests.from_dict(d.get("quests", {}))
	world = d.get("world", {}).duplicate(true)
	for k in ["opened_chests", "discovered", "interacted", "taken_pickups"]:
		if not world.has(k):
			world[k] = []
	if not world.has("flags"):
		world["flags"] = {}
	current_zone = d.get("zone", "vale_of_cinders")
	current_spawn = d.get("spawn", "start")
	var p = d.get("position")
	player_position = Vector3(p[0], p[1], p[2]) if p is Array and p.size() == 3 else null
	playtime = float(d.get("playtime", 0.0))
	in_game = true
	return true
