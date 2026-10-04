class_name Item
extends RefCounted
## A single item instance. Equipment is procedurally rolled (base + rarity +
## affixes); stackables (potions, materials, quest items) only carry a count.

const PERCENT_STATS := ["crit_chance", "attack_speed", "move_speed", "damage_pct"]

static var _uid_counter: int = 0

var uid: String = ""
var base_id: String = ""          # equipment base id or stackable id
var name: String = ""
var kind: String = "equipment"    # equipment | consumables | materials | quest_items
var slot: String = ""             # weapon, helmet, armor, gloves, boots, ring, amulet
var weapon_type: String = ""
var rarity: String = "common"
var item_level: int = 1
var min_dmg: float = 0.0
var max_dmg: float = 0.0
var armor: float = 0.0
var affixes: Dictionary = {}      # stat_id -> value
var unique_id: String = ""
var lore: String = ""
var count: int = 1
var max_stack: int = 1


static func new_uid() -> String:
	_uid_counter += 1
	return "%d_%d_%d" % [Time.get_ticks_usec(), _uid_counter, randi() % 100000]


static func make_stack(item_id: String, amount: int = 1) -> Item:
	var def := DB.stackable_def(item_id)
	if def.is_empty():
		return null
	var it := Item.new()
	it.uid = new_uid()
	it.base_id = item_id
	it.name = def.name
	it.kind = def.category
	it.max_stack = int(def.get("stack", 99))
	it.count = clampi(amount, 1, it.max_stack)
	it.rarity = "common"
	return it


func is_equipment() -> bool:
	return kind == "equipment"


func is_stackable() -> bool:
	return kind != "equipment"


func description() -> String:
	if is_stackable():
		return DB.stackable_def(base_id).get("desc", "")
	return lore


func display_color() -> Color:
	if kind == "quest_items":
		return Color("#ffd77a")
	if kind != "equipment":
		return Color(DB.stackable_def(base_id).get("color", "#c8c4bc"))
	return DB.rarity_color(rarity)


## Flat dictionary of every stat this item contributes.
func stat_block() -> Dictionary:
	var s: Dictionary = {}
	if min_dmg > 0.0 or max_dmg > 0.0:
		s["min_dmg"] = min_dmg
		s["max_dmg"] = max_dmg
	if armor > 0.0:
		s["armor"] = armor
	for k in affixes:
		s[k] = s.get(k, 0.0) + affixes[k]
	return s


## A single comparable number used for "is this better?" hints.
func power_score() -> float:
	if not is_equipment():
		return 0.0
	var p := 0.0
	p += (min_dmg + max_dmg) * 0.5 * 2.0
	p += armor * 1.0
	for k in affixes:
		var v: float = affixes[k]
		match k:
			"might", "agility", "spirit", "vitality": p += v * 1.6
			"max_health": p += v * 0.35
			"max_mana": p += v * 0.3
			"armor": p += v
			"crit_chance": p += v * 120.0
			"attack_speed": p += v * 110.0
			"move_speed": p += v * 70.0
			"damage_pct": p += v * 120.0
			"fire_damage": p += v * 1.6
			"life_on_hit": p += v * 2.0
	return snappedf(p, 0.1)


static func format_stat(stat: String, value: float) -> String:
	var label: String = DB.affix(stat).get("label", stat.capitalize())
	match stat:
		"min_dmg": return "Min Damage %d" % roundi(value)
		"max_dmg": return "Max Damage %d" % roundi(value)
	if stat in PERCENT_STATS:
		return "%+.0f%% %s" % [value * 100.0, label]
	return "%+d %s" % [roundi(value), label]


func to_dict() -> Dictionary:
	return {
		"uid": uid, "base_id": base_id, "name": name, "kind": kind, "slot": slot,
		"weapon_type": weapon_type, "rarity": rarity, "item_level": item_level,
		"min_dmg": min_dmg, "max_dmg": max_dmg, "armor": armor, "affixes": affixes.duplicate(),
		"unique_id": unique_id, "lore": lore, "count": count, "max_stack": max_stack,
	}


static func from_dict(d: Dictionary) -> Item:
	var it := Item.new()
	it.uid = str(d.get("uid", new_uid()))
	it.base_id = d.get("base_id", "")
	it.name = d.get("name", "")
	it.kind = d.get("kind", "equipment")
	it.slot = d.get("slot", "")
	it.weapon_type = d.get("weapon_type", "")
	it.rarity = d.get("rarity", "common")
	it.item_level = int(d.get("item_level", 1))
	it.min_dmg = float(d.get("min_dmg", 0.0))
	it.max_dmg = float(d.get("max_dmg", 0.0))
	it.armor = float(d.get("armor", 0.0))
	var aff: Dictionary = d.get("affixes", {})
	for k in aff:
		it.affixes[k] = float(aff[k])
	it.unique_id = d.get("unique_id", "")
	it.lore = d.get("lore", "")
	it.count = int(d.get("count", 1))
	it.max_stack = int(d.get("max_stack", 1))
	return it
