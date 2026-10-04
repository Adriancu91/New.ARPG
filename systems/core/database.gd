extends Node
## Read-only game data loaded from res://data/*.json.
## Everything that defines content (classes, skills, items, enemies, quests,
## NPCs) lives in data so new content does not require code changes.

var classes: Dictionary = {}
var skills: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var quests: Dictionary = {}
var npcs: Dictionary = {}
var loaded := false


func _init() -> void:
	load_all()


func load_all() -> void:
	classes = _load("res://data/classes.json")
	skills = _load("res://data/skills.json")
	items = _load("res://data/items.json")
	enemies = _load("res://data/enemies.json")
	quests = _load("res://data/quests.json")
	npcs = _load("res://data/npcs.json")
	loaded = not (classes.is_empty() or skills.is_empty() or items.is_empty() or enemies.is_empty() or quests.is_empty())


func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DB: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DB: invalid JSON in %s" % path)
		return {}
	return parsed


# ---------------------------------------------------------------- helpers

func get_class_data(class_id: String) -> Dictionary:
	return classes.get(class_id, {})


func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})


func get_enemy(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})


func get_quest(quest_id: String) -> Dictionary:
	return quests.get(quest_id, {})


func get_npc(npc_id: String) -> Dictionary:
	return npcs.get(npc_id, {})


func rarity(rarity_id: String) -> Dictionary:
	return items.rarities.get(rarity_id, items.rarities.common)


func rarity_color(rarity_id: String) -> Color:
	return Color(rarity(rarity_id).color)


func item_base(base_id: String) -> Dictionary:
	return items.bases.get(base_id, {})


func affix(affix_id: String) -> Dictionary:
	return items.affixes.get(affix_id, {})


## Returns the definition for a stackable (consumable, material, quest item).
func stackable_def(item_id: String) -> Dictionary:
	for group in ["consumables", "materials", "quest_items"]:
		if items[group].has(item_id):
			var d: Dictionary = items[group][item_id].duplicate()
			d["category"] = group
			return d
	return {}


func is_stackable(item_id: String) -> bool:
	return not stackable_def(item_id).is_empty()
