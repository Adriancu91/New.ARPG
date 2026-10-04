class_name LootTable
extends RefCounted
## Decides what an enemy, chest or boss drops.


## Returns {"gold": int, "items": Array[Item]}.
## `context` keys: weapon_type, needs_fragment (bool), luck (float).
static func roll_enemy(enemy_id: String, enemy_level: int, rng: RandomNumberGenerator, context: Dictionary = {}) -> Dictionary:
	var e := DB.get_enemy(enemy_id)
	var out := {"gold": 0, "items": []}
	if e.is_empty():
		return out
	var g: Array = e.get("gold", [0, 0])
	if rng.randf() < 0.7:
		out.gold = rng.randi_range(int(g[0]), int(g[1])) + enemy_level
	var luck: float = context.get("luck", 0.0)
	if rng.randf() < float(e.get("loot_chance", 0.2)):
		var it := ItemGenerator.generate(rng, enemy_level, ItemGenerator.roll_rarity(rng, "common", luck), context.get("weapon_type", ""))
		if it != null:
			out.items.append(it)
	# crafting materials
	if rng.randf() < 0.22:
		out.items.append(Item.make_stack("ash_shard", rng.randi_range(1, 2)))
	if rng.randf() < 0.06:
		out.items.append(Item.make_stack("ember_dust", 1))
	if rng.randf() < 0.07:
		out.items.append(Item.make_stack("potion_health", 1))
	# Quest item: cultists (and heavies) carry lamp fragments while needed.
	if context.get("needs_fragment", false) and ("caster" in e.tags or "heavy" in e.tags) and rng.randf() < 0.6:
		out.items.append(Item.make_stack("lamp_fragment", 1))
	return out


static func roll_chest(chest_level: int, rng: RandomNumberGenerator, context: Dictionary = {}) -> Dictionary:
	var out := {"gold": rng.randi_range(15, 35) + chest_level * 4, "items": []}
	var min_r := "uncommon"
	var it := ItemGenerator.generate(rng, chest_level, ItemGenerator.roll_rarity(rng, min_r, 0.5), context.get("weapon_type", ""))
	if it != null:
		out.items.append(it)
	if rng.randf() < 0.5:
		out.items.append(Item.make_stack("potion_health", rng.randi_range(1, 2)))
	if rng.randf() < 0.3:
		out.items.append(Item.make_stack("ember_dust", rng.randi_range(1, 3)))
	return out


## Boss: guaranteed class unique + one epic+ item + gold + rare material.
static func roll_boss(boss_id: String, level: int, class_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var e := DB.get_enemy(boss_id)
	var g: Array = e.get("gold", [100, 150])
	var out := {"gold": rng.randi_range(int(g[0]), int(g[1])), "items": []}
	var uniques: Dictionary = DB.items.boss_uniques
	var uid: String = uniques.get(class_id, uniques.any)
	var unique := ItemGenerator.make_unique(uid, level + 1)
	if unique != null:
		out.items.append(unique)
	var weapon_type: String = DB.get_class_data(class_id).get("weapon_type", "")
	var extra := ItemGenerator.generate(rng, level + 1, ItemGenerator.roll_rarity(rng, "epic"), weapon_type)
	if extra != null:
		out.items.append(extra)
	out.items.append(Item.make_stack("void_pearl", 1))
	out.items.append(Item.make_stack("potion_health", 2))
	return out
