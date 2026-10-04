extends TestCase
## Save/load through the real SaveSystem into an isolated test directory.


func before_each() -> void:
	SaveSystem.save_dir = "user://test_saves"
	SaveSystem.delete_save("unit_slot")


func test_save_load_roundtrip() -> void:
	Game.new_game("dawnwarden")
	var cd := Game.character
	cd.add_xp(350)
	cd.gold = 321
	cd.spend_attribute("might", 2)
	cd.learn_skill("aegis_of_dawn")
	var rng := RandomNumberGenerator.new()
	var rare := ItemGenerator.generate(rng, 3, "rare", "sword", "weapon")
	cd.inventory.add(rare)
	check(cd.equipment.equip_from(cd.inventory, rare), "equip rare weapon")
	check(Game.character == cd, "Game.character unchanged")
	cd.inventory.add(Item.make_stack("lamp_fragment", 2))
	Game.accept_quest("q_ashen_toll")
	Game.quests.notify("kill", ["hollow"])
	Game.set_flag("reliquary_unsealed")
	Game.world_list_add("opened_chests", "chest_chapel")
	Game.current_zone = "sunken_reliquary"
	var snapshot := JSON.stringify(cd.to_dict())
	check(SaveSystem.save_game("unit_slot"), "save ok")
	check(SaveSystem.has_save("unit_slot"), "file exists")
	# wipe state
	Game.new_game("hellbrand")
	check(Game.character.class_id == "hellbrand", "state replaced")
	check(SaveSystem.load_game("unit_slot"), "load ok")
	var l := Game.character
	eq(l.class_id, "dawnwarden")
	eq(l.level, cd.level)
	eq(l.xp, cd.xp)
	eq(l.gold, 321)
	eq(l.attribute(  "might"), cd.attribute("might"))
	eq(l.skill_rank("aegis_of_dawn"), 1)
	eq(l.equipment.get_item("weapon").uid, rare.uid, "equipped weapon restored")
	eq(l.inventory.count_of("lamp_fragment"), 2)
	eq(Game.quests.state("q_ashen_toll"), QuestLog.ACTIVE)
	eq(Game.quests.objective_count("q_ashen_toll", "kill_hollow"), 1)
	check(Game.flag("reliquary_unsealed"), "world flag restored")
	check(Game.world_list_has("opened_chests", "chest_chapel"), "chest state restored")
	eq(Game.current_zone, "sunken_reliquary")
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(l.to_dict()))
	var original: Dictionary = JSON.parse_string(snapshot)
	for k in ["level", "xp", "gold", "skill_ranks", "spent_attributes"]:
		eq(JSON.stringify(reloaded[k]), JSON.stringify(original[k]), "field %s identical" % k)
	SaveSystem.delete_save("unit_slot")


func test_missing_or_corrupt_save() -> void:
	check(not SaveSystem.load_game("does_not_exist"), "missing save fails gracefully")
	var f := FileAccess.open(SaveSystem.slot_path("unit_slot"), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	check(SaveSystem.read_save("unit_slot").is_empty(), "corrupt save rejected")
	SaveSystem.delete_save("unit_slot")
