extends TestCase
## XP, levels, attributes, skill points.


func test_xp_curve_monotonic() -> void:
	eq(Progression.xp_to_next(1), 100)
	for lv in range(1, 30):
		check(Progression.xp_to_next(lv + 1) > Progression.xp_to_next(lv), "curve increases at %d" % lv)


func test_level_up_with_overflow() -> void:
	var r := Progression.apply_xp(1, 90, 30)
	eq(r.level, 2, "level 1 -> 2")
	eq(r.xp, 20, "excess XP carried over")
	eq(r.levels_gained, 1)
	var big := Progression.apply_xp(1, 0, 100000)
	check(big.levels_gained > 3, "multi-level gain")


func test_character_level_up_grants_points_and_stats() -> void:
	var cd := CharacterData.create("dawnwarden")
	var hp1: float = cd.compute_stats().max_health
	var ap := cd.attribute_points
	var sp := cd.skill_points
	var lv_signal := [0]
	cd.leveled_up.connect(func(l): lv_signal[0] = l)
	var gained := cd.add_xp(Progression.xp_to_next(1) + 5)
	eq(gained, 1)
	eq(cd.level, 2)
	eq(cd.xp, 5, "overflow kept")
	eq(cd.attribute_points, ap + 5)
	eq(cd.skill_points, sp + 1)
	eq(lv_signal[0], 2, "leveled_up emitted")
	check(cd.compute_stats().max_health > hp1, "max health grows with level")
	eq(cd.health, cd.compute_stats().max_health, "level up refills health")


func test_spend_attributes() -> void:
	var cd := CharacterData.create("dawnwarden")
	cd.add_xp(Progression.xp_to_next(1))
	var before: float = cd.compute_stats().max_health
	check(cd.spend_attribute("vitality", 2), "spend ok")
	eq(cd.compute_stats().max_health, before + 12.0, "+6 health per vitality")
	eq(cd.attribute_points, 3)
	check(not cd.spend_attribute("vitality", 10), "cannot overspend")
	check(not cd.spend_attribute("luck", 1), "unknown attribute rejected")


func test_enemy_xp_scaling() -> void:
	check(Progression.enemy_xp(25, 3, 1) > Progression.enemy_xp(25, 1, 1), "higher level enemies give more xp")
	check(Progression.enemy_xp(25, 1, 10) < 25, "trivial enemies give less xp")
