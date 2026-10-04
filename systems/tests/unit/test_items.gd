extends TestCase
## Procedural item generation.


func test_generation_is_valid_for_all_rarities() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for rarity in ItemGenerator.RARITY_ORDER:
		for i in 40:
			var it := ItemGenerator.generate(rng, rng.randi_range(1, 6), rarity)
			check(it != null, "item generated")
			if it == null:
				continue
			check(it.uid != "", "has uid")
			check(it.name != "", "has name")
			check(it.slot in DB.items.slots, "valid slot %s" % it.slot)
			eq(it.rarity, rarity)
			eq(it.affixes.size(), int(DB.rarity(rarity).affixes), "affix count for %s" % rarity)
			if it.slot == "weapon":
				check(it.max_dmg >= it.min_dmg and it.min_dmg > 0, "weapon damage valid")


func test_rarity_roll_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {}
	for i in 5000:
		var r := ItemGenerator.roll_rarity(rng)
		counts[r] = counts.get(r, 0) + 1
	check(counts.get("common", 0) > counts.get("rare", 0), "common more frequent than rare")
	check(counts.get("rare", 0) > counts.get("legendary", 0), "rare more frequent than legendary")
	for r in counts:
		check(r in ItemGenerator.RARITY_ORDER, "valid rarity")
	var min_rare := ItemGenerator.roll_rarity(rng, "rare")
	check(ItemGenerator.RARITY_ORDER.find(min_rare) >= 2, "min rarity respected")


func test_higher_rarity_has_more_power_on_average() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var avg := {}
	for rarity in ["common", "epic"]:
		var total := 0.0
		for i in 60:
			total += ItemGenerator.generate(rng, 3, rarity, "", "weapon").power_score()
		avg[rarity] = total / 60.0
	check(avg.epic > avg.common, "epic weapons stronger than common (%s vs %s)" % [avg.epic, avg.common])


func test_unique_items() -> void:
	for uid in DB.items.uniques:
		var it := ItemGenerator.make_unique(uid, 5)
		check(it != null, "unique %s created" % uid)
		eq(it.rarity, "legendary")
		eq(it.unique_id, uid)
		check(it.lore != "", "unique has lore")


func test_item_serialization_roundtrip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var it := ItemGenerator.generate(rng, 4, "epic")
	var copy := Item.from_dict(JSON.parse_string(JSON.stringify(it.to_dict())))
	eq(copy.uid, it.uid)
	eq(copy.name, it.name)
	eq(copy.power_score(), it.power_score(), "same power after roundtrip")
	eq(copy.affixes.size(), it.affixes.size())
