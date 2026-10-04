class_name CharacterData
extends RefCounted
## All persistent state of the player character. Pure data + rules, no nodes,
## so it can be unit-tested headless and serialized directly into saves.

signal stats_changed
signal leveled_up(new_level: int)

const ATTRIBUTES := ["might", "agility", "spirit", "vitality"]

var character_id: String = ""
var class_id: String = ""
var hero_name: String = ""
var level: int = 1
var xp: int = 0
var base_attributes: Dictionary = {}     # from class data
var spent_attributes: Dictionary = {}    # points the player assigned
var attribute_points: int = 0
var skill_points: int = 0
var skill_ranks: Dictionary = {}         # skill_id -> rank (0 = locked)
var gold: int = 0
var health: float = -1.0
var mana: float = -1.0
var inventory := Inventory.new()
var equipment := Equipment.new()
var kills: int = 0


static func create(class_id_: String) -> CharacterData:
	var cd := CharacterData.new()
	var cls := DB.get_class_data(class_id_)
	assert(not cls.is_empty(), "Unknown class " + class_id_)
	cd.character_id = "hero_%d" % Time.get_unix_time_from_system()
	cd.class_id = class_id_
	cd.hero_name = cls.hero_name
	for a in ATTRIBUTES:
		cd.base_attributes[a] = int(cls.attributes[a])
		cd.spent_attributes[a] = 0
	cd.equipment.allowed_weapon_type = cls.weapon_type
	for sid in cls.skills:
		cd.skill_ranks[sid] = 0
	cd.skill_ranks[cls.starting_skill] = 1
	cd.skill_points = 1
	for base_id in cls.starting_items:
		var it := ItemGenerator.make_starter(base_id)
		cd.equipment.set_slot(cd.equipment.target_slot(it), it)
	cd.inventory.add(Item.make_stack("potion_health", 3))
	cd.gold = 10
	cd.refill()
	return cd


func class_data() -> Dictionary:
	return DB.get_class_data(class_id)


func attribute(a: String) -> int:
	return int(base_attributes.get(a, 0)) + int(spent_attributes.get(a, 0))


func refill() -> void:
	var s := compute_stats()
	health = s.max_health
	mana = s.max_mana


# ------------------------------------------------------------------ stats

## Derived stats. `buffs` is a Dictionary of extra modifiers (from status
## effects such as Aegis or Demonform) using the same keys as item affixes.
func compute_stats(buffs: Dictionary = {}) -> Dictionary:
	var cls := class_data()
	var base: Dictionary = cls.base
	var gear := equipment.total_stats()
	var passive := passive_stats()
	var mods: Dictionary = {}
	for src in [gear, passive, buffs]:
		for k in src:
			mods[k] = mods.get(k, 0.0) + float(src[k])

	var attrs: Dictionary = {}
	for a in ATTRIBUTES:
		attrs[a] = attribute(a) + mods.get(a, 0.0)

	var s: Dictionary = {}
	s.might = attrs.might
	s.agility = attrs.agility
	s.spirit = attrs.spirit
	s.vitality = attrs.vitality
	s.max_health = (float(base.health) + attrs.vitality * 6.0 + attrs.might * 1.0 + (level - 1) * 9.0 + mods.get("max_health", 0.0)) * (1.0 + mods.get("max_health_pct", 0.0))
	s.max_mana = float(base.mana) + attrs.spirit * 3.0 + (level - 1) * 3.0 + mods.get("max_mana", 0.0)
	s.max_stamina = float(base.stamina)
	s.armor = mods.get("armor", 0.0) * (1.0 + mods.get("armor_pct", 0.0))

	var weapon: Item = equipment.get_item("weapon")
	var wmin := 2.0
	var wmax := 4.0
	if weapon != null:
		wmin = weapon.min_dmg
		wmax = weapon.max_dmg
	var primary: String = cls.primary_attribute
	var attr_mult: float = 1.0 + float(attrs[primary]) * 0.025
	var dmg_mult: float = attr_mult * (1.0 + float(mods.get("damage_pct", 0.0)))
	s.min_damage = wmin * dmg_mult
	s.max_damage = wmax * dmg_mult
	s.skill_power = 1.0 + attrs.spirit * 0.015
	s.fire_damage = mods.get("fire_damage", 0.0)
	s.crit_chance = clampf(0.05 + attrs.agility * 0.002 + mods.get("crit_chance", 0.0), 0.0, 0.75)
	s.crit_multiplier = 1.5
	s.attack_speed = 1.0 + attrs.agility * 0.003 + mods.get("attack_speed", 0.0)
	s.move_speed = float(base.move_speed) * (1.0 + mods.get("move_speed", 0.0) + mods.get("move_speed_pct", 0.0))
	s.life_on_hit = mods.get("life_on_hit", 0.0)
	s.life_steal = mods.get("life_steal", 0.0)
	s.damage_reduction = clampf(mods.get("damage_reduction", 0.0), 0.0, 0.8)
	s.mana_regen = 2.0 + attrs.spirit * 0.12
	s.stamina_regen = 28.0
	s.health_regen = 0.4 + attrs.vitality * 0.05
	s.level = level
	return s


func passive_stats() -> Dictionary:
	var out: Dictionary = {}
	for sid in skill_ranks:
		var rank: int = skill_ranks[sid]
		if rank <= 0:
			continue
		var sk := DB.get_skill(sid)
		if sk.get("kind", "") != "passive":
			continue
		for k in sk.stats:
			out[k] = out.get(k, 0.0) + float(sk.stats[k]) * rank
	return out


## Average expected damage per basic hit, used for UI "power" display.
func damage_rating() -> float:
	var s := compute_stats()
	var avg: float = (s.min_damage + s.max_damage) * 0.5 + s.fire_damage
	return avg * (1.0 + s.crit_chance * (s.crit_multiplier - 1.0)) * s.attack_speed


# ------------------------------------------------------------- progression

func add_xp(amount: int) -> int:
	var r := Progression.apply_xp(level, xp, amount)
	var gained: int = r.levels_gained
	level = r.level
	xp = r.xp
	if gained > 0:
		attribute_points += gained * Progression.ATTRIBUTE_POINTS_PER_LEVEL
		skill_points += gained * Progression.SKILL_POINTS_PER_LEVEL
		refill()
		leveled_up.emit(level)
	stats_changed.emit()
	return gained


func spend_attribute(a: String, amount: int = 1) -> bool:
	if not a in ATTRIBUTES or attribute_points < amount or amount <= 0:
		return false
	var before := compute_stats()
	spent_attributes[a] = int(spent_attributes.get(a, 0)) + amount
	attribute_points -= amount
	var after := compute_stats()
	health += after.max_health - before.max_health
	mana += after.max_mana - before.max_mana
	stats_changed.emit()
	return true


func skill_rank(sid: String) -> int:
	return int(skill_ranks.get(sid, 0))


func can_learn_skill(sid: String) -> bool:
	var sk := DB.get_skill(sid)
	if sk.is_empty() or not skill_ranks.has(sid):
		return false
	return skill_points > 0 and level >= int(sk.unlock_level) and skill_rank(sid) < int(sk.max_rank)


func learn_skill(sid: String) -> bool:
	if not can_learn_skill(sid):
		return false
	skill_ranks[sid] = skill_rank(sid) + 1
	skill_points -= 1
	stats_changed.emit()
	return true


## Active / ultimate skills in class order (these map to hotkeys 1-5).
func hotbar_skills() -> Array:
	var out: Array = []
	for sid in class_data().skills:
		var kind: String = DB.get_skill(sid).get("kind", "")
		if kind == "active" or kind == "ultimate":
			out.append(sid)
	return out


# ------------------------------------------------------------ persistence

func to_dict() -> Dictionary:
	return {
		"character_id": character_id, "class_id": class_id, "hero_name": hero_name,
		"level": level, "xp": xp, "spent_attributes": spent_attributes.duplicate(),
		"attribute_points": attribute_points, "skill_points": skill_points,
		"skill_ranks": skill_ranks.duplicate(), "gold": gold, "health": health, "mana": mana,
		"kills": kills, "inventory": inventory.to_array(), "equipment": equipment.to_dict(),
	}


static func from_dict(d: Dictionary) -> CharacterData:
	var cd := CharacterData.new()
	cd.class_id = d.get("class_id", "dawnwarden")
	var cls := DB.get_class_data(cd.class_id)
	cd.character_id = d.get("character_id", "")
	cd.hero_name = d.get("hero_name", cls.get("hero_name", "Hero"))
	cd.level = int(d.get("level", 1))
	cd.xp = int(d.get("xp", 0))
	for a in ATTRIBUTES:
		cd.base_attributes[a] = int(cls.attributes[a])
		cd.spent_attributes[a] = int(d.get("spent_attributes", {}).get(a, 0))
	cd.attribute_points = int(d.get("attribute_points", 0))
	cd.skill_points = int(d.get("skill_points", 0))
	for sid in cls.skills:
		cd.skill_ranks[sid] = int(d.get("skill_ranks", {}).get(sid, 0))
	cd.gold = int(d.get("gold", 0))
	cd.kills = int(d.get("kills", 0))
	cd.equipment.allowed_weapon_type = cls.weapon_type
	cd.inventory.from_array(d.get("inventory", []))
	cd.equipment.from_dict(d.get("equipment", {}))
	var s := cd.compute_stats()
	cd.health = clampf(float(d.get("health", s.max_health)), 1.0, s.max_health)
	cd.mana = clampf(float(d.get("mana", s.max_mana)), 0.0, s.max_mana)
	return cd
