extends TestCase
## Damage, armor, health and death rules.


func test_armor_reduction_curve() -> void:
	eq(Damage.armor_reduction(0.0, 1), 0.0, "no armor -> no reduction")
	var r := Damage.armor_reduction(60.0, 1)
	check(r > 0.45 and r < 0.55, "60 armor vs lvl1 ~ 50%% (got %s)" % r)
	check(Damage.armor_reduction(100000.0, 1) <= 0.75, "reduction capped at 75%")
	check(Damage.armor_reduction(30.0, 10) < Damage.armor_reduction(30.0, 1), "higher attacker level pierces armor")


func test_mitigate_physical_and_light_bonus() -> void:
	var h := Damage.Hit.new()
	h.amount = 100.0
	h.element = "physical"
	h.attacker_level = 1
	eq(Damage.mitigate(h, 0.0), 100.0, "no armor = full damage")
	var light := Damage.Hit.new()
	light.amount = 100.0
	light.element = "light"
	eq(Damage.mitigate(light, 0.0, ["corrupted"]), 125.0, "light +25% vs corrupted")
	eq(Damage.mitigate(h, 0.0, [], 0.45), 55.0, "extra reduction (Aegis) applies")
	check(Damage.mitigate(h, 1000.0) >= 1.0, "minimum 1 damage")


func test_roll_player_crit_and_range() -> void:
	var stats := {"min_damage": 10.0, "max_damage": 20.0, "fire_damage": 0.0, "crit_chance": 0.0, "crit_multiplier": 1.5, "skill_power": 1.0, "level": 1}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200:
		var h := Damage.roll_player(stats, 1.0, "physical", rng)
		check(h.amount >= 10.0 and h.amount <= 20.0, "roll within weapon range")
		check(not h.crit, "0% crit never crits")
	stats.crit_chance = 1.0
	var c := Damage.roll_player(stats, 1.0, "physical", rng)
	check(c.crit and c.amount >= 15.0, "100% crit applies multiplier")


func test_combatant_health_and_death() -> void:
	var e := Enemy.create("hollow_sentinel", 1)
	e.drops_loot = false
	(Engine.get_main_loop() as SceneTree).root.add_child(e)
	var died := [false]
	e.died.connect(func(_w): died[0] = true)
	var start := e.health
	eq(start, e.max_health, "spawns at full health")
	var h := Damage.Hit.new()
	h.amount = 10.0
	h.element = "light"   # half armor effect, deterministic enough
	var dealt := e.take_hit(h)
	check(dealt > 0.0, "damage dealt")
	eq(e.health, start - dealt, "health reduced by dealt damage")
	check(e.is_alive(), "still alive")
	h.amount = 99999.0
	e.take_hit(h)
	check(not e.is_alive(), "dies at zero health")
	eq(e.health, 0.0, "health clamped at 0")
	check(died[0], "died signal emitted")
	eq(e.take_hit(h), 0.0, "dead targets take no damage")
	e.free()


func test_burn_status_deals_damage_over_time() -> void:
	var se := StatusEffects.new()
	se.apply("burn", 2.0, 10.0)
	var total := 0.0
	for i in 120:
		total += se.tick(1.0 / 60.0)
	check(total >= 15.0 and total <= 25.0, "burn ~10 dps for 2s (got %s)" % total)
	check(not se.has("burn"), "burn expires")


func test_stun_and_chill_speed() -> void:
	var se := StatusEffects.new()
	se.apply("chill", 1.0)
	check(se.speed_multiplier() < 1.0, "chill slows")
	se.apply("stun", 1.0)
	eq(se.speed_multiplier(), 0.0, "stun stops movement")
	check(se.is_stunned(), "stunned")
