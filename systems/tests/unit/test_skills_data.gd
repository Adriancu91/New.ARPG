extends TestCase
## Data integrity: every class, skill, item and quest reference resolves.


func test_classes_reference_valid_data() -> void:
	eq(DB.classes.size(), 3, "three heroines")
	for cid in DB.classes:
		var c: Dictionary = DB.classes[cid]
		var actives := 0
		for sid in c.skills:
			check(DB.skills.has(sid), "%s skill %s exists" % [cid, sid])
			if DB.get_skill(sid).get("kind", "") != "passive":
				actives += 1
		check(actives >= 5, "%s has >= 5 active skills" % cid)
		for b in c.starting_items:
			check(DB.items.bases.has(b), "starting item %s exists" % b)
		check(DB.skills.has(c.starting_skill), "starting skill exists")


func test_skill_types_are_supported() -> void:
	var supported := ["melee_cone", "projectile", "multi_projectile", "aoe_target", "aoe_self", "dash_strike", "buff", "trap"]
	for sid in DB.skills:
		var sk: Dictionary = DB.skills[sid]
		if sk.kind == "passive":
			check(sk.has("stats"), "passive %s has stats" % sid)
		else:
			check(sk.type in supported, "%s type %s supported" % [sid, sk.type])


func test_quest_targets_exist() -> void:
	for qid in DB.quests:
		var q: Dictionary = DB.quests[qid]
		check(DB.npcs.has(q.giver), "giver exists")
		for obj in q.objectives:
			check(obj.type in ["kill", "collect", "explore", "interact", "boss"], "objective type valid")
			if obj.type == "collect":
				check(DB.is_stackable(obj.target), "collect target is an item")
			if obj.type == "boss":
				check(DB.enemies.has(obj.target), "boss exists")


func test_five_enemy_archetypes_and_boss() -> void:
	var archetypes := {}
	for eid in DB.enemies:
		archetypes[DB.enemies[eid].archetype] = true
	for a in ["corrupted_warrior", "beast", "ranged_caster", "assassin", "heavy", "boss"]:
		check(archetypes.has(a), "archetype %s present" % a)
