extends Node
## Smoke test for all three heroines: every hotbar skill and the basic and
## heavy attacks must execute and damage a target. Writes class_smoke.json.

var main
var report := {}


func _ready() -> void:
	SaveSystem.autosave_enabled = false
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _dummy(pos: Vector3) -> Enemy:
	var e: Enemy = main.zone.add_enemy("cinder_colossus", 1, pos)
	e.max_health = 100000.0
	e.health = e.max_health
	e.detect = 0.0
	e.speed = 0.0
	return e


func _run() -> void:
	await _frames(5)
	for cid in ["dawnwarden", "hellbrand", "starweaver"]:
		main.start_new_game(cid)
		await _frames(10)
		for e in main.zone.alive_enemies():
			e.queue_free()
		await _frames(2)
		var cd := Game.character
		cd.add_xp(3000)
		for sid in cd.class_data().skills:
			if cd.skill_rank(sid) == 0 and cd.can_learn_skill(sid):
				cd.learn_skill(sid)
		var p: Player = Game.player
		p.global_position = Vector3(0, 0.1, 30)
		p.iframes = 99999.0
		var target := _dummy(Vector3(0, 0, 27.5))
		await _frames(5)
		var res := {}
		for sid in cd.hotbar_skills():
			p.mana = p.max_mana
			p.attack_timer = 0.0
			var hp0 := target.health
			p.aim_override = target.global_position
			var ok := p.try_skill(sid)
			await _frames(70)
			var sk := DB.get_skill(sid)
			var dealt := hp0 - target.health
			var needs_damage: bool = float(sk.get("dmg_mult", 0.0)) > 0.0 and sk.type != "trap"
			if sk.type == "trap":
				# step the dummy onto the trap
				target.global_position = p.global_position + (target.global_position - p.global_position).normalized() * 3.0
				await _frames(20)
				dealt = hp0 - target.health
				needs_damage = true
			res[sid] = {"executed": ok, "damage": dealt, "pass": ok and (dealt > 0.0 or not needs_damage)}
			# reset positions after dashes
			p.global_position = Vector3(0, 0.1, 30)
			target.global_position = Vector3(0, 0, 27.5)
			await _frames(5)
		var hp0b := target.health
		p.attack_timer = 0.0
		p.aim_override = target.global_position
		var a_ok := p.try_attack()
		await _frames(40)
		res["basic_attack"] = {"executed": a_ok, "damage": hp0b - target.health, "pass": a_ok and hp0b - target.health > 0.0}
		var hp0c := target.health
		p.attack_timer = 0.0
		p.stamina = p.max_stamina
		var h_ok := p.try_heavy()
		await _frames(60)
		res["heavy_attack"] = {"executed": h_ok, "damage": hp0c - target.health, "pass": h_ok and hp0c - target.health > 0.0}
		report[cid] = res
		print("CLASS ", cid, " ", JSON.stringify(res))
	var all_ok := true
	for cid in report:
		for k in report[cid]:
			if not report[cid][k].pass:
				all_ok = false
	report["all_pass"] = all_ok
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_output"))
	var f := FileAccess.open(ProjectSettings.globalize_path(("res://systems/tests/output" if OS.has_feature("editor") else "user://test_output") + "/class_smoke.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("CLASS_SMOKE all_pass=", all_ok)
	get_tree().quit(0 if all_ok else 1)
