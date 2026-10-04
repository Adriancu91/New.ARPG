extends TestCase
## Quest state machine and reward-once guarantee.


func test_quest_lifecycle() -> void:
	var ql := QuestLog.new()
	eq(ql.state("q_ashen_toll"), QuestLog.AVAILABLE)
	check(ql.accept("q_ashen_toll"), "accept")
	eq(ql.state("q_ashen_toll"), QuestLog.ACTIVE)
	check(not ql.accept("q_ashen_toll"), "cannot accept twice")
	for i in 7:
		ql.notify("kill", ["hollow", "corrupted"])
	eq(ql.objective_count("q_ashen_toll", "kill_hollow"), 5, "kill count capped at goal")
	ql.notify("kill", ["beast"])
	eq(ql.objective_count("q_ashen_toll", "kill_hollow"), 5, "wrong target ignored")
	var inv := Inventory.new()
	inv.add(Item.make_stack("lamp_fragment", 3))
	ql.sync_collect("q_ashen_toll", inv)
	eq(ql.objective_count("q_ashen_toll", "collect_fragments"), 3)
	check(ql.state("q_ashen_toll") == QuestLog.ACTIVE, "not ready until exploration done")
	ql.notify("explore", ["area_broken_saint"])
	eq(ql.state("q_ashen_toll"), QuestLog.READY)


func test_rewards_granted_once() -> void:
	var ql := QuestLog.new()
	ql.accept("q_ashen_toll")
	check(ql.complete("q_ashen_toll").is_empty(), "cannot complete while objectives pending")
	for i in 5: ql.notify("kill", ["hollow"])
	ql.notify("explore", ["area_broken_saint"])
	var inv := Inventory.new()
	inv.add(Item.make_stack("lamp_fragment", 3))
	ql.sync_collect("q_ashen_toll", inv)
	var r := ql.complete("q_ashen_toll")
	check(not r.is_empty() and int(r.xp) > 0, "rewards returned")
	eq(ql.state("q_ashen_toll"), QuestLog.COMPLETED)
	check(ql.complete("q_ashen_toll").is_empty(), "second completion yields nothing")


func test_quest_serialization() -> void:
	var ql := QuestLog.new()
	ql.accept("q_hollow_bishop")
	ql.notify("explore", ["area_reliquary_depths"])
	var copy := QuestLog.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(ql.to_dict())))
	eq(copy.state("q_hollow_bishop"), QuestLog.ACTIVE)
	eq(copy.objective_count("q_hollow_bishop", "enter_reliquary"), 1)


func test_boss_and_interact_objectives() -> void:
	var ql := QuestLog.new()
	ql.accept("q_hollow_bishop")
	ql.notify("explore", ["area_reliquary_depths"])
	ql.notify("interact", ["obj_warding_brazier"])
	ql.notify("boss", ["vorthane"])
	eq(ql.state("q_hollow_bishop"), QuestLog.READY)
