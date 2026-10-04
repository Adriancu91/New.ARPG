extends TestCase
## Loot tables: enemy, chest, boss.


func test_enemy_loot_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var item_drops := 0
	for i in 300:
		var loot := LootTable.roll_enemy("ashen_cultist", 2, rng, {"weapon_type": "sword"})
		check(loot.gold >= 0, "gold non-negative")
		for it in loot.items:
			check(it != null, "valid item")
			if it.is_equipment():
				item_drops += 1
				check(it.rarity in ItemGenerator.RARITY_ORDER, "valid rarity")
	check(item_drops > 50 and item_drops < 250, "drop rate roughly loot_chance (%d/300)" % item_drops)


func test_quest_fragment_drops_only_when_needed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var with_need := 0
	var without := 0
	for i in 200:
		for it in LootTable.roll_enemy("ashen_cultist", 2, rng, {"needs_fragment": true}).items:
			if it.base_id == "lamp_fragment": with_need += 1
		for it in LootTable.roll_enemy("ashen_cultist", 2, rng, {"needs_fragment": false}).items:
			if it.base_id == "lamp_fragment": without += 1
	check(with_need > 0, "fragments drop while quest needs them")
	eq(without, 0, "no fragments when not needed")


func test_chest_loot_min_uncommon() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 50:
		var loot := LootTable.roll_chest(2, rng)
		check(loot.gold > 0, "chest gold")
		var eq_items: Array = loot.items.filter(func(x): return x.is_equipment())
		check(eq_items.size() >= 1, "chest has equipment")
		for it in eq_items:
			check(ItemGenerator.RARITY_ORDER.find(it.rarity) >= 1, "at least uncommon")


func test_boss_loot_has_unique() -> void:
	var rng := RandomNumberGenerator.new()
	for cls in ["dawnwarden", "hellbrand", "starweaver"]:
		var loot := LootTable.roll_boss("vorthane", 5, cls, rng)
		var uniques: Array = loot.items.filter(func(x): return x.unique_id != "")
		eq(uniques.size(), 1, "exactly one unique for %s" % cls)
		check(uniques[0].unique_id == DB.items.boss_uniques[cls], "class-appropriate unique")
		check(loot.gold >= 150, "boss gold")
