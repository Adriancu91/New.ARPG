extends TestCase
## Equip/unequip moves the same instance; stats change; no duplication.


func _weapon(rarity: String, wtype: String = "sword") -> Item:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return ItemGenerator.generate(rng, 4, rarity, wtype, "weapon")


func test_equip_swaps_without_duplication() -> void:
	var cd := CharacterData.create("dawnwarden")
	var old: Item = cd.equipment.get_item("weapon")
	var new_w := _weapon("epic")
	cd.inventory.add(new_w)
	var before_count := cd.inventory.items.size()
	var dmg_before: float = cd.compute_stats().max_damage
	check(cd.equipment.equip_from(cd.inventory, new_w), "equip")
	check(cd.equipment.get_item("weapon") == new_w, "slot updated")
	check(not cd.inventory.has_uid(new_w.uid), "removed from bag")
	check(cd.inventory.has_uid(old.uid), "old weapon returned to bag")
	eq(cd.inventory.items.size(), before_count, "bag count unchanged (swap)")
	check(cd.compute_stats().max_damage != dmg_before, "stats changed")
	# uniqueness of uids across bag + equipment
	var seen := {}
	for it in cd.inventory.items + cd.equipment.all_items():
		check(not seen.has(it.uid), "no duplicate uid %s" % it.uid)
		seen[it.uid] = true


func test_unequip() -> void:
	var cd := CharacterData.create("dawnwarden")
	var w: Item = cd.equipment.get_item("weapon")
	check(cd.equipment.unequip_to(cd.inventory, "weapon"), "unequip")
	check(cd.equipment.get_item("weapon") == null, "slot empty")
	check(cd.inventory.has_uid(w.uid), "in bag")


func test_class_weapon_restriction() -> void:
	var cd := CharacterData.create("dawnwarden")
	var bow := _weapon("rare", "bow")
	cd.inventory.add(bow)
	check(not cd.equipment.can_equip(bow), "dawnwarden cannot use bows")
	check(not cd.equipment.equip_from(cd.inventory, bow), "equip refused")
	check(cd.inventory.has_uid(bow.uid), "bow stays in bag")


func test_rings_fill_both_slots() -> void:
	var cd := CharacterData.create("dawnwarden")
	var rng := RandomNumberGenerator.new()
	var r1 := ItemGenerator.generate(rng, 3, "rare", "", "ring")
	var r2 := ItemGenerator.generate(rng, 3, "rare", "", "ring")
	cd.inventory.add(r1)
	cd.inventory.add(r2)
	cd.equipment.equip_from(cd.inventory, r1)
	cd.equipment.equip_from(cd.inventory, r2)
	check(cd.equipment.get_item("ring1") != null and cd.equipment.get_item("ring2") != null, "both ring slots used")


func test_armor_item_increases_armor() -> void:
	var cd := CharacterData.create("dawnwarden")
	var rng := RandomNumberGenerator.new()
	var helm := ItemGenerator.generate(rng, 4, "common", "", "helmet")
	var a0: float = cd.compute_stats().armor
	cd.inventory.add(helm)
	cd.equipment.equip_from(cd.inventory, helm)
	check(cd.compute_stats().armor > a0, "armor increased")


func test_comparison_counterpart() -> void:
	var cd := CharacterData.create("dawnwarden")
	var w := _weapon("legendary")
	check(cd.equipment.equipped_counterpart(w) == cd.equipment.get_item("weapon"), "compares against equipped weapon")
	cd.inventory.add(w)
	eq(LootPickup.upgrade_verdict(w), 0 if Game.character == null else LootPickup.upgrade_verdict(w), "verdict callable")
