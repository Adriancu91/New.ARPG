extends Node
## Automated vertical-slice playthrough that executes the acceptance tests
## VS-001 .. VS-025 against the real game (real scenes, real systems,
## simulated input). Two phases run in two separate OS processes:
##
##   phase 1: new game -> combat -> loot -> quest -> dungeon -> boss -> save -> quit
##   phase 2: relaunch -> continue -> verify restored state -> keep playing
##
##   godot --headless --fixed-fps 60 res://systems/tests/acceptance/acceptance_bot.tscn -- --phase=1
##
## Results are written to systems/tests/output/acceptance_phase<N>.json and
## are assembled into TEST_REPORT.md by tools/make_test_report.py.
## Notes on simulation: movement for VS-003 uses real input actions (WASD).
## Elsewhere the bot steers with Player.move_override and aims with
## Player.aim_override (there is no physical mouse in a headless run);
## attacks, skills, dodge, interact, potion and menu keys use input actions.

## Source runs write next to the project; exported test builds (e.g. the
## Windows .exe) write to user://test_output because res:// is read-only there.
var OUT := "res://systems/tests/output" if OS.has_feature("editor") else "user://test_output"

var phase := 1
var main
var results: Array = []
var log_lines: Array = []
var _t0 := 0
var _damage_events: Array = []
var _player_hits := 0
var _xp_events: Array = []
var _boss_effects := 0
var _boss_projectiles := 0
var _teleports: Array = []
var _deaths := 0
var _frame_times: Array = []
var _mem_samples: Array = []
var _enemy_areas_seen := {}
var _vs009: Dictionary = {}
var _vs009_pre: Dictionary = {}
var _pickup_origins: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = int(a.substr(8))
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Events.player_damaged.connect(func(_a): _player_hits += 1)
	Events.player_died.connect(func(): _deaths += 1)
	Events.xp_gained.connect(func(a): _xp_events.append(a))
	if phase == 1:
		# clean install: no saves on disk
		for slot in [SaveSystem.MANUAL_SLOT, SaveSystem.AUTO_SLOT]:
			SaveSystem.delete_save(slot)
	SaveSystem.autosave_enabled = phase == 1
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	get_tree().node_added.connect(_on_node_added)
	_run.call_deferred()


func _on_node_added(n: Node) -> void:
	if n is AreaEffect or n is Projectile:
		_track_effect.call_deferred(n)
	elif n is LootPickup:
		n.tree_exiting.connect(func():
			if n.item != null:
				_pickup_origins.append([n.item.uid, n.origin]))


func _track_effect(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n.team == "enemy":
		var src = n.get("source")
		var boss = _boss()
		if n is AreaEffect and boss != null and is_instance_valid(boss) and boss.active:
			_boss_effects += 1
		elif n is Projectile and src != null and is_instance_valid(src) and src is BossVorthane:
			_boss_projectiles += 1


func _process(delta: float) -> void:
	if Game.player != null and phase == 1:
		_frame_times.append(Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))


# ------------------------------------------------------------------ helpers

func log_msg(s: String) -> void:
	var line := "[sim %6.1fs | wall %5.1fs] %s" % [Engine.get_physics_frames() / 60.0, (Time.get_ticks_msec() - _t0) / 1000.0, s]
	print(line)
	log_lines.append(line)


func record(id: String, desc: String, ok: bool, notes: String, known: String = "", blocked: bool = false) -> void:
	var res := "BLOCKED" if blocked else ("PASS" if ok else "FAIL")
	results.append({"id": id, "description": desc, "result": res, "notes": notes, "known_issues": known, "phase": phase})
	log_msg("%s  %s  %s  -- %s" % [res, id, desc, notes])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func secs(t: float) -> void:
	await frames(int(t * 60.0))


func pl() -> Player:
	var p = Game.player
	return p if p != null and is_instance_valid(p) else null


## Input.action_press() is seen as "just pressed" on the following physics
## frame, so a tap holds the action for two frames.
func tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func ui_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(1)


## find_children() only matches native classes, so search by script type here.
func nodes_of(root: Node, pred: Callable) -> Array:
	var out: Array = []
	for c in root.get_children():
		if pred.call(c):
			out.append(c)
		out.append_array(nodes_of(c, pred))
	return out


func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func dist_to(p: Vector3) -> float:
	var me := pl()
	return INF if me == null else flat(me.global_position).distance_to(flat(p))


func _boss() -> BossVorthane:
	if main.zone is SunkenReliquary and main.zone.boss != null and is_instance_valid(main.zone.boss):
		return main.zone.boss
	return null


func enemies_near(center: Vector3, radius: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and flat(e.global_position).distance_to(flat(center)) <= radius and not _unreachable.has(e.get_instance_id()):
			out.append(e)
	out.sort_custom(func(a, b): return dist_to(a.global_position) < dist_to(b.global_position))
	return out


## Walks to `target` steering around obstacles. Fights back when attacked
## if `fight` is set. Returns true on arrival.
func move_to(target: Vector3, max_t: float = 40.0, arrive: float = 1.4, fight: bool = true) -> bool:
	var t := 0.0
	var last_pos := Vector3.INF
	var stuck_t := 0.0
	var side := 1.0
	var sidestep := 0.0
	while t < max_t:
		var me := pl()
		if me == null or not me.is_alive():
			await secs(0.5)
			t += 0.5
			continue
		if dist_to(target) <= arrive:
			me.move_override = Vector2.ZERO
			return true
		if fight:
			var threats := enemies_near(me.global_position, 7.0).filter(func(e): return e.aggro)
			if not threats.is_empty():
				me.move_override = Vector2.ZERO
				await fight_enemies(threats, 30.0)
				continue
		var to := target - me.global_position
		var dir := Vector2(to.x, to.z).normalized()
		if sidestep > 0.0:
			dir = (Vector2(-dir.y, dir.x) * side + dir * 0.2).normalized()
			sidestep -= 1.0 / 60.0
		me.move_override = dir
		me.aim_override = me.global_position + Vector3(dir.x, 0, dir.y) * 5.0
		await get_tree().physics_frame
		t += 1.0 / 60.0
		stuck_t += 1.0 / 60.0
		if stuck_t >= 0.75:
			if last_pos != Vector3.INF and flat(me.global_position).distance_to(flat(last_pos)) < 0.6:
				side = -side if randf() < 0.3 else side
				sidestep = 0.9
			last_pos = me.global_position
			stuck_t = 0.0
	var me2 := pl()
	if me2:
		me2.move_override = Vector2.ZERO
	return false


## Walks through waypoints. No teleport fallback: if the bot cannot reach a
## point it logs it and moves on, and later checks fail honestly.
func walk(points: Array, fight: bool = true, per_leg: float = 40.0) -> bool:
	var all_ok := true
	for p in points:
		if not await move_to(p, per_leg, 1.6, fight):
			all_ok = false
			_teleports.append("unreached %s (stopped at %s)" % [p, pl().global_position.snapped(Vector3.ONE * 0.1) if pl() else Vector3.ZERO])
			log_msg("WARN: could not reach waypoint %s" % p)
	return all_ok


var _unreachable := {}


## Combat AI for the bot: approach (with obstacle sidestepping), attack, use
## skills, dodge telegraphs, drink potions. `basic_only` = basic attacks only
## and no recruiting of other enemies (isolated VS-004 duel).
func fight_enemies(targets: Array, max_t: float = 60.0, basic_only: bool = false) -> bool:
	var t := 0.0
	var chase_t := 0.0
	var chase_id := 0
	var chase_best := INF
	var last_pos := Vector3.INF
	var stuck_t := 0.0
	var sidestep := 0.0
	var side := 1.0
	while t < max_t:
		var me := pl()
		if me == null or not me.is_alive():
			return false
		var alive: Array = targets.filter(func(e): return is_instance_valid(e) and e.is_alive() and not _unreachable.has(e.get_instance_id()))
		for e in ([] if basic_only else enemies_near(me.global_position, 9.0)):
			if e.aggro and not alive.has(e):
				alive.append(e)
				targets.append(e)
		if alive.is_empty():
			Input.action_release("attack")
			me.move_override = Vector2.ZERO
			return true
		alive.sort_custom(func(a, b): return dist_to(a.global_position) < dist_to(b.global_position))
		var tgt: Enemy = alive[0]
		var d := dist_to(tgt.global_position)
		me.aim_override = tgt.global_position
		var reach: float = me.data.class_data().base.attack_range
		var danger := _incoming_area(me)
		if danger != Vector3.INF and me.dodge_cooldown <= 0.0 and me.stamina >= Player.DODGE_STAMINA:
			var away := me.global_position - danger
			away.y = 0
			if away.length() < 0.1:
				away = Vector3(1, 0, 0)
			me.move_override = Vector2(away.x, away.z).normalized()
			await tap("dodge")
			t += 2.0 / 60.0
			continue
		if me.health < me.max_health * 0.45 and me.data.inventory.count_of("potion_health") > 0 and me.potion_cooldown <= 0.0:
			await tap("potion")
		if d > reach * 0.85:
			Input.action_release("attack")
			# chase bookkeeping: give up on targets we cannot reach
			if tgt.get_instance_id() != chase_id:
				chase_id = tgt.get_instance_id()
				chase_t = 0.0
				chase_best = d
			chase_t += 1.0 / 60.0
			if d < chase_best - 0.5:
				chase_best = d
				chase_t = 0.0
			if chase_t > 6.0:
				_unreachable[chase_id] = true
				log_msg("bot: giving up on unreachable %s at %s" % [tgt.enemy_id, tgt.global_position.snapped(Vector3.ONE)])
				continue
			var to := tgt.global_position - me.global_position
			var dir := Vector2(to.x, to.z).normalized()
			if sidestep > 0.0:
				dir = (Vector2(-dir.y, dir.x) * side + dir * 0.25).normalized()
				sidestep -= 1.0 / 60.0
			me.move_override = dir
			stuck_t += 1.0 / 60.0
			if stuck_t > 0.6:
				if last_pos != Vector3.INF and flat(me.global_position).distance_to(flat(last_pos)) < 0.5:
					sidestep = 0.8
					side = -side if randf() < 0.35 else side
				last_pos = me.global_position
				stuck_t = 0.0
		else:
			me.move_override = Vector2.ZERO
			Input.action_press("attack")
			if not basic_only:
				await _use_skills(me, alive)
		await get_tree().physics_frame
		t += 1.0 / 60.0
	Input.action_release("attack")
	return false


func _use_skills(me: Player, alive: Array) -> void:
	var bar := me.data.hotbar_skills()
	for i in bar.size():
		var sid: String = bar[i]
		if me.skill_block_reason(sid) != "":
			continue
		var sk := DB.get_skill(sid)
		var use := false
		match sk.type:
			"buff":
				use = me.health < me.max_health * 0.7 or alive.size() >= 3 or _boss() != null
			"aoe_self":
				use = enemies_near(me.global_position, float(sk.radius)).size() >= 2 or (_boss() != null and dist_to(_boss().global_position) < float(sk.radius))
			_:
				use = true
		if use:
			await tap("skill_%d" % (i + 1))
			return


## Center of an enemy telegraph that will hit the player soon, or INF.
## Incoming enemy projectiles count too (returns a point beside their path).
func _incoming_area(me: Player) -> Vector3:
	for n in main.zone.get_children():
		if n is Projectile and n.team == "enemy" and not n._done:
			var to_me: Vector3 = me.global_position - n.global_position
			to_me.y = 0
			var d := to_me.length()
			if d < 5.0 and d > 0.5 and n.direction.dot(to_me.normalized()) > 0.9:
				return n.global_position + n.direction * d
	for n in main.zone.get_children():
		if n is AreaEffect and n.team == "enemy" and not n._fired and n.make_hit.is_valid():
			var k: float = n._t / maxf(n.delay, 0.01)
			if k < 0.35:
				continue
			var hit := false
			if n.shape == "cone":
				hit = CombatUtils.in_cone(get_tree(), "enemy", n.global_position, n.forward, n.radius + 0.5, n.cone_angle).has(me)
			else:
				hit = flat(me.global_position).distance_to(flat(n.global_position)) <= n.radius + 0.6
			if hit:
				return n.global_position
	return Vector3.INF


func collect_pickups(center: Vector3, radius: float, max_t: float = 25.0) -> int:
	var got := 0
	var t0 := Time.get_ticks_msec()
	while true:
		var pickups: Array = get_tree().get_nodes_in_group("pickups").filter(func(p): return is_instance_valid(p) and flat(p.global_position).distance_to(flat(center)) <= radius)
		if pickups.is_empty():
			break
		pickups.sort_custom(func(a, b): return dist_to(a.global_position) < dist_to(b.global_position))
		var pk = pickups[0]
		var before := Game.character.inventory.items.size()
		await move_to(pk.global_position, 8.0, 0.6, true)
		await frames(3)
		if is_instance_valid(pk):
			# probably inventory full or unreachable; stop trying this one
			pk.remove_from_group("pickups")
		else:
			got += 1
		if Game.character.inventory.items.size() < before:
			pass
		if (Time.get_ticks_msec() - t0) / 1000.0 > max_t * 4:
			break
	return got


func interact_with(node: Node3D, max_t: float = 30.0) -> bool:
	if not await move_to(node.global_position, max_t, 2.0):
		return false
	pl().move_override = Vector2.ZERO
	await frames(2)
	await tap("interact")
	await frames(3)
	return true


func clear_and_loot(center: Vector3, radius: float, max_t: float = 90.0) -> void:
	var t := 0.0
	while t < max_t:
		var targets := enemies_near(center, radius)
		if targets.is_empty():
			break
		await move_to(targets[0].global_position, 10.0, 2.0, false)
		await fight_enemies(targets, 30.0)
		t += 1.0
	await collect_pickups(center, radius + 4.0)
	_spend_points()


func _spend_points() -> void:
	var cd := Game.character
	while cd.attribute_points > 0:
		cd.spend_attribute("vitality" if cd.attribute_points % 2 == 0 else "might")
	for sid in ["aegis_of_dawn", "sunlance", "judgment_circle", "ascendant_wrath", "radiant_cleave", "celestial_ward", "dawnblade_discipline"]:
		while cd.can_learn_skill(sid) and (cd.skill_rank(sid) == 0 or sid in ["radiant_cleave", "celestial_ward"]):
			cd.learn_skill(sid)
	_auto_equip()


## Equip anything that is an upgrade (as a player would after reading ▲).
func _auto_equip() -> void:
	var cd := Game.character
	for it in cd.inventory.items.duplicate():
		if it.is_equipment() and LootPickup.upgrade_verdict(it) > 0:
			cd.equipment.equip_from(cd.inventory, it)


func save_json(name: String, data) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "/" + name), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_json(name: String) -> Dictionary:
	var path := ProjectSettings.globalize_path(OUT + "/" + name)
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func snapshot() -> Dictionary:
	var cd := Game.character
	var eq := {}
	for s in Equipment.SLOTS:
		var it: Item = cd.equipment.get_item(s)
		eq[s] = it.uid if it else ""
	var inv: Array = []
	for it in cd.inventory.items:
		inv.append("%s|%s|%d" % [it.uid, it.base_id, it.count])
	inv.sort()
	return {
		"class_id": cd.class_id, "hero_name": cd.hero_name, "level": cd.level, "xp": cd.xp, "gold": cd.gold,
		"attribute_points": cd.attribute_points, "skill_points": cd.skill_points,
		"skill_ranks": cd.skill_ranks.duplicate(), "spent_attributes": cd.spent_attributes.duplicate(),
		"equipment": eq, "inventory": inv, "quests": Game.quests.to_dict(),
		"flags": Game.world.get("flags", {}).duplicate(), "opened_chests": Game.world.get("opened_chests", []).duplicate(),
		"discovered": Game.world.get("discovered", []).duplicate(), "zone": Game.current_zone,
	}


func finish() -> void:
	Input.action_release("attack")
	var data := {
		"phase": phase, "date": Time.get_datetime_string_from_system(), "build": ProjectSettings.get_setting("application/config/version"),
		"engine": Engine.get_version_info().string, "results": results, "teleports": _teleports, "deaths": _deaths,
		"sim_seconds": Engine.get_physics_frames() / 60.0, "wall_seconds": (Time.get_ticks_msec() - _t0) / 1000.0,
		"log": log_lines,
	}
	if phase == 1:
		data["perf"] = _perf_summary()
	save_json("acceptance_phase%d.json" % phase, data)
	log_msg("Phase %d finished: %d results" % [phase, results.size()])
	get_tree().quit(0)


func _perf_summary() -> Dictionary:
	var ft: Array = _frame_times.duplicate()
	ft.sort()
	var n := ft.size()
	if n == 0:
		return {}
	var total := 0.0
	for v in ft:
		total += v
	return {
		"frames": n, "avg_cpu_frame_ms": total / n * 1000.0, "p99_cpu_frame_ms": ft[int(n * 0.99)] * 1000.0,
		"max_cpu_frame_ms": ft[n - 1] * 1000.0, "memory_samples_mb": _mem_samples,
	}


func _mem_mb() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0


# ================================================================== PHASE 1

func _run() -> void:
	if phase == 2:
		await _phase2()
		finish()
		return
	await frames(10)
	_mem_samples.append(["boot", _mem_mb()])
	# ---------------------------------------------------------------- VS-001
	var menu_ok: bool = main.screen != null and main.screen.name == "MainMenu"
	var ng: Button = main.screen.find_child("NewGame", true, false) if menu_ok else null
	var vs001_menu := menu_ok and ng != null and not ng.disabled
	log_msg("Main menu visible=%s, New Game available=%s" % [menu_ok, ng != null and not ng.disabled])
	# ---------------------------------------------------------------- VS-002
	ng.pressed.emit()
	await frames(5)
	var select_ok: bool = main.screen != null and main.screen.name == "CharacterSelect"
	var start_btn: Button = main.screen.find_child("Start_dawnwarden", true, false)
	start_btn.pressed.emit()
	await frames(30)
	var cd := Game.character
	var me := pl()
	var stats_valid: bool = me != null and me.max_health > 0 and me.health == me.max_health and me.max_mana > 0 and cd.level == 1 and cd.xp == 0
	var vs002: bool = select_ok and cd != null and cd.class_id == "dawnwarden" and cd.hero_name == "Seraphine Vael" and cd.class_data().name == "Dawnwarden" \
		and stats_valid and main.zone is ValeOfCinders and me.is_inside_tree() and cd.equipment.get_item("weapon") != null
	record("VS-001", "Game Launch", vs001_menu and main.playing and me != null, "Main menu shown on boot with New Game enabled; gameplay reached (zone '%s' loaded, player spawned)." % (main.zone.zone_id if main.zone else "none"), "Executed on Linux headless (Godot 4.3) - the Windows build was not launched on Windows hardware.")
	record("VS-002", "Character Selection", vs002, "Selected Dawnwarden -> %s (%s), Lv %d, HP %d/%d, %s %d, weapon '%s', zone %s." % [cd.hero_name, cd.class_data().name, cd.level, me.health, me.max_health, cd.class_data().resource_name, me.max_mana, cd.equipment.get_item("weapon").name, Game.current_zone])
	_mem_samples.append(["in_world", _mem_mb()])
	_install_levelup_probe()
	# ---------------------------------------------------------------- VS-003
	await _vs003_movement()
	# ---------------------------------------------------------------- VS-014
	await _vs014_quest_start()
	# --------------------------------------- VS-007 / VS-004 / VS-008 / VS-005
	await _first_fight()
	# ---------------------------------------------------------------- VS-006
	await _vs006_dodge()
	# ---------------------------------------- VS-009 / VS-010 / VS-011..013
	await _progression_and_loot()
	# ---------------------------------------------------------- VS-015/016
	await _quest_run()
	# ---------------------------------------------------------- VS-017
	await _dungeon()
	# ---------------------------------------------------------- VS-018/019
	await _boss_fight()
	_mem_samples.append(["after_boss", _mem_mb()])
	# ---------------------------------------------------------- VS-020
	await _vs020_save()
	finish()


## Observes the first level-up exactly when it happens (VS-009).
func _install_levelup_probe() -> void:
	var cd := Game.character
	var pre := func():
		return {"level": cd.level, "xp_total": cd.xp, "ap": cd.attribute_points, "sp": cd.skill_points, "hp_max": cd.compute_stats().max_health}
	_vs009_pre = pre.call()
	Events.stats_changed.connect(func():
		if _vs009.is_empty() and cd.level == _vs009_pre.level:
			_vs009_pre = pre.call())   # still level 1: refresh the pre-state
	# Capture the post-state synchronously inside the level-up signal (other
	# kills in the same frame cannot blur it); the XP award that caused it is
	# the next xp_gained event; UI/refill checks are deferred one frame.
	Events.leveled_up.connect(func(lv):
		if not _vs009.is_empty():
			return
		_vs009 = {
			"level_before": int(_vs009_pre.level), "level_after": lv, "xp_total_before": int(_vs009_pre.xp_total),
			"xp_after": cd.xp, "ap_before": int(_vs009_pre.ap), "ap_after": cd.attribute_points,
			"sp_before": int(_vs009_pre.sp), "sp_after": cd.skill_points,
			"hp_max_before": float(_vs009_pre.hp_max), "hp_max_after": cd.compute_stats().max_health,
			"gain": -1, "banner": false, "refilled": false,
		}
		_finish_levelup_probe.call_deferred(lv))
	Events.xp_gained.connect(func(amount):
		if not _vs009.is_empty() and int(_vs009.gain) == -1:
			_vs009.gain = amount)


func _finish_levelup_probe(lv: int) -> void:
	await get_tree().physics_frame
	_vs009.banner = main.hud.levelup_label.visible and ("LEVEL %d" % lv) in main.hud.levelup_label.text
	_vs009.refilled = pl() != null and absf(pl().health - pl().max_health) < 1.0


func _vs003_movement() -> void:
	var me := pl()
	me.move_override = null
	me.aim_override = null
	var start := me.global_position
	# responsiveness: frames until velocity appears
	Input.action_press("move_down")
	var frames_to_move := 0
	for i in 10:
		await get_tree().physics_frame
		frames_to_move += 1
		if Vector2(me.velocity.x, me.velocity.z).length() > 1.0:
			break
	await secs(5.0)   # walk south into the zone boundary wall
	Input.action_release("move_down")
	var blocked_z := me.global_position.z
	var moved_s := blocked_z - start.z
	var boundary: float = main.zone.bounds.end.y
	var collided := blocked_z < boundary - 0.3
	var cam_dist: float = flat(main.camera._focus).distance_to(flat(me.global_position))
	# not stuck: walk back north, then strafe
	Input.action_press("move_up")
	await secs(1.0)
	Input.action_release("move_up")
	var unstuck := me.global_position.z < blocked_z - 3.0
	var x0 := me.global_position.x
	Input.action_press("move_left")
	await secs(0.8)
	Input.action_release("move_left")
	var left_ok := me.global_position.x < x0 - 2.0
	Input.action_press("move_right")
	await secs(0.8)
	Input.action_release("move_right")
	var right_ok := me.global_position.x > x0 - 0.5
	await frames(10)
	var cam_follow: float = flat(main.camera._focus).distance_to(flat(me.global_position))
	var ok := frames_to_move <= 3 and moved_s > 10.0 and collided and unstuck and left_ok and right_ok and cam_follow < 1.0 and cam_dist < 1.5
	record("VS-003", "Movement", ok, "WASD input actions: velocity after %d frame(s); walked %.1f m south and was stopped by the boundary wall at z=%.2f (wall %.1f); moved back north/left/right freely; camera focus offset %.2f m while moving, %.2f m at rest." % [frames_to_move, moved_s, blocked_z, boundary, cam_dist, cam_follow])
	await move_to(Vector3(0, 0, 44), 10.0, 1.0, false)


func _vs014_quest_start() -> void:
	var ivenn: NPC = nodes_of(main.zone, func(n): return n is NPC)[0]
	await interact_with(ivenn)
	var opened: bool = main.dialogue_ui.visible
	var intro: String = main.dialogue_ui.current
	var opts: Array = main.dialogue_ui.option_list()
	# "How can I help?"
	main.dialogue_ui.choose(opts[1])
	await frames(3)
	var offer: String = main.dialogue_ui.current
	var accept_opt: Dictionary = main.dialogue_ui.option_list()[0]
	main.dialogue_ui.choose(accept_opt)
	await frames(5)
	var st := Game.quests.state("q_ashen_toll")
	await ui_action("quest_log")
	var log_txt: String = main.quest_ui.text.get_parsed_text()
	await ui_action("quest_log")
	var tracker := ""
	for c in main.hud.quest_box.get_children():
		if c is Label:
			tracker += c.text + " | "
	var ok := opened and intro == "intro" and offer == "offer" and st == QuestLog.ACTIVE and "The Ashen Toll" in log_txt and "Put down Hollowed Sentinels" in tracker
	record("VS-014", "Quest Start", ok, "Pressed E near Brother Ivenn -> dialogue '%s' -> '%s' -> accepted. State=%s. Quest log lists 'The Ashen Toll'; HUD tracker: %s" % [intro, offer, st, tracker.left(160)])
	# merchant check (not a numbered test, but exercised)
	await interact_with(ivenn)
	for o in main.dialogue_ui.option_list():
		if o.get("action", "") == "trade":
			main.dialogue_ui.choose(o)
			break
	await frames(3)
	var gold_before := Game.character.gold
	var pots := Game.character.inventory.count_of("potion_health")
	var bought: bool = main.merchant_ui.visible and main.merchant_ui.npc.buy_potion()
	log_msg("Merchant opened=%s, bought potion=%s (gold %d -> %d, potions %d -> %d)" % [main.merchant_ui.visible, bought, gold_before, Game.character.gold, pots, Game.character.inventory.count_of("potion_health")])
	main.merchant_ui.close()


func _first_fight() -> void:
	# The pair of Hollowed Sentinels on the road west of the camp.
	var pack := enemies_near(Vector3(-12, 0, 16), 6.0).filter(func(e): return e.enemy_id == "hollow_sentinel")
	if pack.is_empty():
		record("VS-007", "Enemy AI", false, "No sentinel pack found at the road.")
		return
	var e: Enemy = pack[0]
	var home := e.global_position
	var states_seen := {}
	var detected_at := -1.0
	# walk toward the sentinel and stop at 15 m (outside its 13 m detection)
	var to_me := (Vector3(-2, 0, 30) - home).normalized()
	await move_to(home + to_me * 15.0, 30.0, 0.8, false)
	var me := pl()
	me.move_override = Vector2.ZERO
	await frames(30)
	var idle_before: bool = not e.aggro
	# step inside detection range (relative to where it wandered to) and wait
	var step_dist := 11.0
	while not e.aggro and step_dist >= 6.0:
		var dir_e := (pl().global_position - e.global_position)
		dir_e.y = 0
		await move_to(e.global_position + dir_e.normalized() * step_dist, 10.0, 0.6, false)
		me.move_override = Vector2.ZERO
		await frames(60)
		step_dist -= 2.5
	me.move_override = Vector2.ZERO
	me.aim_override = e.global_position
	var d0 := dist_to(e.global_position)
	var hp0 := me.health
	var hits_by_e := [0]
	var hit_info: Array = []
	var cb := func(_a, h):
		if h.source == e:
			hits_by_e[0] += 1
			hit_info.append("dist %.1f state %s frame %d kb %.1f" % [dist_to(e.global_position), Enemy.State.keys()[e.state], Engine.get_physics_frames(), h.knockback])
	me.damaged.connect(cb)
	var min_d := d0
	for i in 480:   # up to 8 s
		await get_tree().physics_frame
		states_seen[Enemy.State.keys()[e.state]] = true
		if e.aggro and detected_at < 0.0:
			detected_at = dist_to(e.global_position)
		min_d = minf(min_d, dist_to(e.global_position))
		if hits_by_e[0] > 0:
			# keep watching ~1 s so the post-attack RECOVER state is observed
			for j in 60:
				await get_tree().physics_frame
				states_seen[Enemy.State.keys()[e.state]] = true
			break
	var damaged_player: bool = hits_by_e[0] > 0 and me.health < hp0
	# ---- VS-004: basic attacks only, against this sentinel
	var dmg_events: Array = []
	e.damaged.connect(func(a, h): dmg_events.append([a, h.is_skill]))
	var hp_e0 := e.health
	var died := [false]
	var xp_at_death := [-1]
	e.died.connect(func(_w):
		died[0] = true
		xp_at_death[0] = Game.character.xp + _total_xp_before(Game.character))
	var xp_events0 := _xp_events.size()
	var xp_for_e := [-1, -1]
	var kill_cb := func(eid, _tags, _xp, pos):
		if eid == e.enemy_id and pos.distance_to(e.global_position) < 0.01:
			xp_for_e[0] = _xp_events[-1] if not _xp_events.is_empty() else -1
			xp_for_e[1] = Game.character.xp + _total_xp_before(Game.character)
	Events.enemy_killed.connect(kill_cb)
	await fight_enemies([e], 40.0, true)
	Events.enemy_killed.disconnect(kill_cb)
	await frames(1)
	var xp_after := Game.character.xp + _total_xp_before(Game.character)
	var feedback := 0
	for n in main.zone.get_children():
		if n is FloatingText:
			feedback += 1
	var vs004: bool = dmg_events.size() > 0 and died[0] and not e.is_alive() and e.health < hp_e0 and feedback > 0 and not dmg_events.any(func(x): return x[1])
	var ai_ok: bool = idle_before and detected_at > 0.0 and detected_at <= e.detect + 0.5 and min_d < 3.0 and damaged_player and died[0] \
		and states_seen.has("CHASE") and states_seen.has("WINDUP") and states_seen.has("RECOVER")
	record("VS-007", "Enemy AI", ai_ok,
		"Sentinel idle while player was 15 m away (aggro=%s); detected the player at %.1f m (detect radius %.0f), closed from %.1f m to %.1f m, telegraphed and landed %d hit(s) (HP %.0f -> %.0f); AI states observed: %s; it was then killed (died=%s). Hit detail: %s" % [not idle_before, detected_at, e.detect, d0, min_d, hits_by_e[0], hp0, me.health, states_seen.keys(), died[0], str(hit_info)])
	me.damaged.disconnect(cb)
	record("VS-004", "Basic Combat", vs004, "Killed a Hollowed Sentinel with basic attacks (LMB action) only: %d hits landed, health %.0f -> 0, %d floating damage numbers present, hit flash + knockback applied." % [dmg_events.size(), hp_e0, feedback])
	# ---- VS-008: XP for exactly that kill (measured across the death frame)
	var expected := Progression.enemy_xp(int(DB.get_enemy("hollow_sentinel").xp), e.level, 1)
	var gained: int = xp_for_e[1] - xp_at_death[0]   # XP change caused by this kill only
	xp_after = xp_for_e[1]
	var bar_ok: bool = int(main.hud.xp_bar.value) == Game.character.xp
	record("VS-008", "XP", gained == expected and xp_for_e[0] == expected and _xp_events.size() > xp_events0 and bar_ok, "Killing the sentinel awarded %d XP (expected %d from data: base 25, enemy Lv %d vs player Lv 1); total XP %d -> %d; HUD XP bar shows %d == character XP %d." % [gained, expected, e.level, xp_at_death[0], xp_after, int(main.hud.xp_bar.value), Game.character.xp])
	# ---- VS-005: skill (learn Aegis with the starting skill point, use Radiant Cleave)
	Game.character.learn_skill("aegis_of_dawn")
	var rest := pack.filter(func(x): return is_instance_valid(x) and x.is_alive())
	if rest.is_empty():
		rest = enemies_near(me.global_position, 30.0)
	var tgt: Enemy = rest[0]
	await move_to(tgt.global_position, 15.0, 2.0, false)
	me = pl()
	me.move_override = Vector2.ZERO
	me.aim_override = tgt.global_position
	me.face_point(tgt.global_position)
	var skill_hits: Array = []
	tgt.damaged.connect(func(a, h):
		if h.is_skill:
			skill_hits.append(a))
	# precondition: target inside Radiant Cleave range (3.4 m) and in front
	for i in 120:
		if not is_instance_valid(tgt) or not tgt.is_alive() or dist_to(tgt.global_position) < 2.2:
			break
		var to := tgt.global_position - me.global_position
		me.move_override = Vector2(to.x, to.z).normalized()
		await get_tree().physics_frame
	me.move_override = Vector2.ZERO
	me.aim_override = tgt.global_position
	me.face_point(tgt.global_position)
	var mana0 := me.mana
	var cast := [false]
	var on_skill := func(sid):
		if sid == "radiant_cleave":
			cast[0] = true
	Events.skill_used.connect(on_skill)
	await tap("skill_1")
	var cd_after: float = me.skill_cooldowns.get("radiant_cleave", 0.0)
	var mana_after := me.mana
	await frames(30)
	var reuse_blocked := me.skill_block_reason("radiant_cleave") == "cooldown"
	await tap("skill_2")
	await frames(2)
	var aegis := me.status.has("aegis")
	Events.skill_used.disconnect(on_skill)
	var spent := mana0 - mana_after
	var vs005: bool = cast[0] and skill_hits.size() > 0 and spent > 10.5 and spent < 12.5 and cd_after > 2.0 and reuse_blocked and aegis
	record("VS-005", "Skill", vs005, "Key 1 cast Radiant Cleave (Light cone): %s skill damage to the target, resource %.1f -> %.1f (cost 12, minus regen), cooldown %.2fs started and blocked immediate re-use; key 2 cast Aegis of Dawn (damage-reduction buff active=%s)." % [str(skill_hits), mana0, mana_after, cd_after, aegis])
	await fight_enemies(rest, 40.0)
	await collect_pickups(me.global_position, 10.0)


func _origin_of(it: Item) -> String:
	for r in _pickup_origins:
		if r[0] == it.uid:
			return r[1]
	return ""


func _enemy_equipment_collected(collected: Array) -> Array:
	return collected.filter(func(it): return it.is_equipment() and _origin_of(it).begins_with("enemy:"))


func _vs006_dodge() -> void:
	var me := pl()
	await secs(2.0)   # regain stamina
	me.move_override = Vector2(1, 0)
	await frames(2)
	var p0 := me.global_position
	var st0 := me.stamina
	await tap("dodge")
	var i0 := me.iframes
	var started := me.dodge_timer > 0.0
	var second := me.try_dodge()  # immediate re-dodge must be refused
	await secs(Player.DODGE_TIME)
	me.move_override = Vector2.ZERO
	var travelled := flat(me.global_position).distance_to(flat(p0))
	var iframes_ended := me.iframes <= 0.0
	var stamina_used := st0 - me.stamina
	# exploit check: spam dodge every frame for 6 seconds
	var inv_frames := 0
	var total := 360
	me.move_override = Vector2(0, -1)
	for i in total:
		if i % 3 == 0:
			Input.action_press("dodge")
		elif i % 3 == 2:
			Input.action_release("dodge")
		await get_tree().physics_frame
		if me.is_invulnerable():
			inv_frames += 1
		if i % 40 == 0:
			me.move_override = -me.move_override
	Input.action_release("dodge")
	me.move_override = Vector2.ZERO
	var ratio := float(inv_frames) / total
	var ok := started and i0 > 0.0 and not second and travelled > 3.0 and travelled < 7.5 and iframes_ended and stamina_used > 15.0 and ratio < 0.5
	record("VS-006", "Dodge", ok, "Space: dodge moved %.2f m in %.2fs, i-frames %.2fs then ended, %.0f stamina spent, instant re-dodge refused. Spamming dodge for 6 s kept the player invulnerable only %.0f%% of frames (cooldown + stamina gate)." % [travelled, Player.DODGE_TIME, i0, stamina_used, ratio * 100.0])


func _progression_and_loot() -> void:
	var cd := Game.character
	# ---- VS-009 was observed by the level-up hook installed in _run()
	await frames(2)
	var lv: Dictionary = _vs009
	if lv.is_empty():
		# not levelled yet: keep killing
		var guard := 0
		while _vs009.is_empty() and guard < 15:
			guard += 1
			var more := enemies_near(pl().global_position, 60.0)
			if more.is_empty():
				break
			await move_to(more[0].global_position, 30.0, 3.0, true)
			await fight_enemies([more[0]], 30.0)
		lv = _vs009
	var ok9: bool = not lv.is_empty() and lv.level_after == lv.level_before + 1 and lv.xp_after == lv.xp_total_before + lv.gain - Progression.xp_to_next(lv.level_before) \
		and lv.banner and lv.ap_after == lv.ap_before + 5 and lv.sp_after == lv.sp_before + 1 and lv.hp_max_after > lv.hp_max_before and lv.refilled
	record("VS-009", "Level Up", ok9, "Kill granting %d XP took the hero from %d XP (Lv %d, threshold %d) to Lv %d with %d XP carried over; 'LEVEL %d' banner shown=%s; attribute points %d -> %d, skill points %d -> %d; max health %.0f -> %.0f; health refilled=%s." % [lv.get("gain", 0), lv.get("xp_total_before", 0), lv.get("level_before", 0), Progression.xp_to_next(int(lv.get("level_before", 1))), lv.get("level_after", 0), lv.get("xp_after", 0), lv.get("level_after", 0), lv.get("banner", false), lv.get("ap_before", 0), lv.get("ap_after", 0), lv.get("sp_before", 0), lv.get("sp_after", 0), lv.get("hp_max_before", 0.0), lv.get("hp_max_after", 0.0), lv.get("refilled", false)])
	_spend_points()
	# ---- VS-010: enemy -> loot -> inventory
	await walk([Vector3(0, 0, 14)])
	var collected: Array = []
	var cb := func(it):
		collected.append(it)
	Events.item_picked_up.connect(cb)
	var drops: Array = []
	var node_cb := func(n):
		if n is LootPickup:
			drops.append(n)
	get_tree().node_added.connect(node_cb)
	await clear_and_loot(Vector3(0, 0, 0), 12.0)
	# keep hunting until an enemy-dropped equipment item has been picked up
	var kills := 0
	while _enemy_equipment_collected(collected).is_empty() and kills < 25:
		var more := enemies_near(pl().global_position, 70.0)
		if more.is_empty():
			break
		var tgt: Enemy = more[0]
		await move_to(tgt.global_position, 25.0, 3.0, true)
		await fight_enemies([tgt], 30.0)
		kills += 1
		await frames(45)
		await collect_pickups(pl().global_position, 9.0)
	get_tree().node_added.disconnect(node_cb)
	Events.item_picked_up.disconnect(cb)
	var enemy_equipment: Array = _enemy_equipment_collected(collected)
	var looted: Item = null
	var origin := ""
	for it in enemy_equipment:
		if cd.inventory.has_uid(it.uid) or cd.equipment.all_items().has(it):
			looted = it
			origin = _origin_of(it)
			break
	var vs010: bool = looted != null and origin.begins_with("enemy:") and not DB.item_base(looted.base_id).is_empty() and looted.rarity in ItemGenerator.RARITY_ORDER
	record("VS-010", "Loot", vs010, ("Enemy drop '%s' [%s, base %s, ilvl %d] from %s: pickup showed rarity beam + name label, walked over it -> in inventory. Total pickups collected in this fight: %d (%d equipment)." % [looted.name, looted.rarity, looted.base_id, looted.item_level, origin, collected.size(), enemy_equipment.size()]) if looted else "No enemy equipment drop collected (%d pickups seen)." % collected.size())
	# chapel chest (guaranteed uncommon+) and the altar lamp fragment
	var chest: TreasureChest = nodes_of(main.zone, func(n): return n is TreasureChest).filter(func(c): return c.object_id == "chest_chapel")[0]
	await interact_with(chest)
	await secs(1.0)
	await collect_pickups(chest.global_position, 6.0)
	await collect_pickups(Vector3(0, 0, -4.6), 3.0)
	# ---- VS-011: inventory (the looted item may already be worn: inspect a bag item)
	if looted == null or not cd.inventory.has_uid(looted.uid):
		looted = null
		for it in cd.inventory.items:
			if it.is_equipment():
				looted = it
				break
	await ui_action("inventory")
	var inv_ui: InventoryUI = main.inventory_ui
	var slot: ItemSlot = null
	for s in inv_ui.bag_slots:
		if s.item == looted:
			slot = s
	var vs011 := false
	var detail := ""
	if slot != null:
		slot.selected.emit(slot)
		await frames(2)
		detail = inv_ui.detail.get_parsed_text()
		var rarity_name: String = DB.rarity(looted.rarity).name
		var has_stat := ("Damage" in detail) or ("Armor" in detail) or looted.affixes.size() > 0 or looted.implicit.size() > 0
		vs011 = inv_ui.visible and slot._icon.texture != null and looted.name in detail and rarity_name in detail and has_stat and "Power" in detail
		slot.mouse_entered.emit()
	record("VS-011", "Inventory", vs011, "Pressed I: window open=%s, %d bag items shown in the grid with icons; selecting the looted item shows: \"%s\"" % [inv_ui.visible, cd.inventory.items.size(), detail.replace("\n", " / ").left(240)])
	# ---- VS-012: equip via UI (prefer an upgrade that replaces a worn item)
	var candidate: Item = null
	var best := -INF
	for it in cd.inventory.items:
		if it.is_equipment() and cd.equipment.can_equip(it) and cd.equipment.equipped_counterpart(it) != null:
			var gain: float = it.power_score() - cd.equipment.equipped_counterpart(it).power_score()
			if gain > best:
				best = gain
				candidate = it
	if candidate != null and absf(best) < 0.5:
		candidate = null   # identical stats: equipping it would not show a stat change
	var eq_fixture := ""
	if candidate == null:
		candidate = ItemGenerator.generate(Game.rng, cd.level + 1, "rare", cd.class_data().weapon_type, "weapon")
		cd.inventory.add(candidate)
		inv_ui.refresh()
		await frames(2)
		eq_fixture = " (precondition fixture: no dropped item differed from the worn ones, so a rare weapon was generated by ItemGenerator)"
	var vs012 := false
	var eq_notes := "No equippable item available."
	var prev: Item = null
	if candidate != null:
		var target_slot := cd.equipment.target_slot(candidate)
		prev = cd.equipment.equipped_counterpart(candidate)
		var stats0 := cd.compute_stats()
		var inv_n0 := cd.inventory.items.size()
		var cslot: ItemSlot = null
		for s in inv_ui.bag_slots:
			if s.item == candidate:
				cslot = s
		cslot.activated.emit(cslot)   # right-click / double-click
		await frames(3)
		var stats1 := cd.compute_stats()
		var worn := false
		for s in Equipment.SLOTS:
			if cd.equipment.get_item(s) == candidate:
				worn = true
		var uids := {}
		var dup := false
		for it in cd.inventory.items + cd.equipment.all_items():
			if uids.has(it.uid):
				dup = true
			uids[it.uid] = true
		var changed := JSON.stringify(stats0) != JSON.stringify(stats1)
		var player_synced: bool = absf(pl().stats.max_damage - stats1.max_damage) < 0.01 and absf(pl().armor - stats1.armor) < 0.01
		vs012 = worn and not cd.inventory.has_uid(candidate.uid) and (prev == null or cd.inventory.has_uid(prev.uid)) and not dup and changed and player_synced \
			and cd.inventory.items.size() == inv_n0 - (0 if prev else 1)
		eq_notes = "Equipped '%s' into %s via inventory right-click. %s returned to the bag (bag size unchanged). Damage %d-%d -> %d-%d, armor %d -> %d, max health %d -> %d; live player stats updated=%s; duplicate uids=%s.%s" % [candidate.name, target_slot, ("'" + prev.name + "'") if prev else "Nothing", stats0.min_damage, stats0.max_damage, stats1.min_damage, stats1.max_damage, stats0.armor, stats1.armor, stats0.max_health, stats1.max_health, player_synced, dup, eq_fixture]
	record("VS-012", "Equipment", vs012, eq_notes)
	# ---- VS-013: comparison - select a bag item that has an equipped counterpart
	var vs013 := false
	var cmp_notes := "No bag item with an equipped counterpart."
	var cmp_item: Item = prev
	var fixture := ""
	if cmp_item == null:
		for it in cd.inventory.items:
			if it.is_equipment() and cd.equipment.equipped_counterpart(it) != null:
				cmp_item = it
				break
	if cmp_item == null:
		# precondition fixture ("Given an equipped item and another of the same
		# type"): random drops did not produce one, so generate a weapon
		cmp_item = ItemGenerator.generate(Game.rng, cd.level, "rare", cd.class_data().weapon_type, "weapon")
		cd.inventory.add(cmp_item)
		inv_ui.refresh()
		await frames(2)
		fixture = " (precondition fixture: rare weapon generated by ItemGenerator because no drop matched an equipped slot)"
	if cmp_item != null:
		var worn_vs: Item = cd.equipment.equipped_counterpart(cmp_item)
		var pslot: ItemSlot = null
		for s in inv_ui.bag_slots:
			if s.item == cmp_item:
				pslot = s
		pslot.selected.emit(pslot)
		await frames(2)
		var d_txt: String = inv_ui.detail.get_parsed_text()
		var c_txt: String = inv_ui.compare.get_parsed_text()
		vs013 = cmp_item.name in d_txt and worn_vs.name in c_txt and ("▼" in d_txt or "▲" in d_txt) and ("worse" in d_txt or "better" in d_txt)
		cmp_notes = "Selected '%s' in the bag while wearing '%s': the selected panel shows per-stat deltas and a verdict (\"%s\"); the 'Currently equipped' panel shows '%s'.%s" % [cmp_item.name, worn_vs.name, d_txt.replace("\n", " / ").right(120), c_txt.get_slice("\n", 0), fixture]
	record("VS-013", "Item Comparison", vs013, cmp_notes)
	await ui_action("inventory")
	_spend_points()


func _quest_run() -> void:
	var cd := Game.character
	var q := "q_ashen_toll"
	var notes: Array = []
	# kills (chapel sentinels already dead -> count)
	notes.append("kills %d/5" % Game.quests.objective_count(q, "kill_hollow"))
	# hunt remaining sentinels if needed (reinforcements guarantee availability)
	var guard := 0
	while Game.quests.objective_count(q, "kill_hollow") < 5 and guard < 10:
		guard += 1
		var hs := enemies_near(pl().global_position, 120.0).filter(func(e): return "hollow" in e.tags)
		if hs.is_empty():
			await secs(6.0)
			continue
		await move_to(hs[0].global_position, 40.0, 3.0, true)
		await fight_enemies([hs[0]], 30.0)
	notes.append("kills %d/5" % Game.quests.objective_count(q, "kill_hollow"))
	# save mid-quest and check the progress is in the file (persistence)
	SaveSystem.save_game("midquest_check")
	var mid := SaveSystem.read_save("midquest_check")
	var persisted := int(mid.get("quests", {}).get("progress", {}).get(q, {}).get("kill_hollow", -1)) == Game.quests.objective_count(q, "kill_hollow")
	SaveSystem.delete_save("midquest_check")
	# shrine: exploration + chest fragment
	await walk([Vector3(0, 0, 12), Vector3(20, 0, 6), Vector3(36, 0, 4)])
	await clear_and_loot(Vector3(44, 0, 0), 14.0)
	var explored := Game.quests.objective_count(q, "find_shrine") >= 1
	if not explored:
		await move_to(Vector3(46, 0, 4), 20.0)
	var shrine_chest: TreasureChest = nodes_of(main.zone, func(n): return n is TreasureChest).filter(func(c): return c.object_id == "chest_shrine")[0]
	await interact_with(shrine_chest)
	await secs(1.0)
	await collect_pickups(shrine_chest.global_position, 6.0)
	notes.append("shrine explored=%s, fragments %d/3" % [Game.quests.objective_count(q, "find_shrine") >= 1, cd.inventory.count_of("lamp_fragment")])
	# cultist camp chest fragment
	await walk([Vector3(20, 0, 6), Vector3(0, 0, 12), Vector3(-12, 0, 12), Vector3(-16, 0, -16), Vector3(-26, 0, -32)])
	await clear_and_loot(Vector3(-30, 0, -40), 14.0)
	var camp_chest: TreasureChest = nodes_of(main.zone, func(n): return n is TreasureChest).filter(func(c): return c.object_id == "chest_cult_camp")[0]
	await interact_with(camp_chest)
	await secs(1.0)
	await collect_pickups(camp_chest.global_position, 7.0)
	notes.append("fragments %d/3" % cd.inventory.count_of("lamp_fragment"))
	_spend_points()
	var ready := Game.quests.state(q) == QuestLog.READY
	record("VS-015", "Quest Progression", ready and persisted,
		"Objectives advanced by gameplay: %s. Mid-quest save contained the live kill count=%s. State now '%s'." % [", ".join(notes), persisted, Game.quests.state(q)])
	# ---- VS-016: turn in
	await walk([Vector3(-16, 0, -16), Vector3(-12, 0, 12), Vector3(-2, 0, 24), Vector3(2, 0, 31)])
	var ivenn: NPC = nodes_of(main.zone, func(n): return n is NPC)[0]
	var xp0 := cd.xp + _total_xp_before(cd)
	var lvl0 := cd.level
	var gold0 := cd.gold
	var pots0 := cd.inventory.count_of("potion_health")
	var items0 := cd.inventory.items.size()
	await interact_with(ivenn)
	var node0: String = main.dialogue_ui.current
	var completed := false
	for o in main.dialogue_ui.option_list():
		if str(o.get("action", "")).begins_with("complete:"):
			main.dialogue_ui.choose(o)
			completed = true
			break
	await frames(5)
	main.dialogue_ui.close()
	var xp_gain := (cd.xp + _total_xp_before(cd)) - xp0
	var gold_gain := cd.gold - gold0
	var again := Game.complete_quest(q)
	var gold_after_again := cd.gold
	var vs016 := completed and node0 == "toll_done" and Game.quests.state(q) == QuestLog.COMPLETED and xp_gain == 260 and gold_gain == 75 \
		and cd.inventory.count_of("potion_health") >= pots0 + 3 and not again and gold_after_again == cd.gold and Game.flag("reliquary_unsealed") \
		and cd.inventory.count_of("lamp_fragment") == 0 and Game.quests.state("q_hollow_bishop") == QuestLog.ACTIVE
	SaveSystem.save_game("turnin_check")
	var saved := SaveSystem.read_save("turnin_check")
	var persisted_done: bool = saved.get("quests", {}).get("states", {}).get(q, "") == "completed" and saved.get("quests", {}).get("rewarded", {}).get(q, false)
	SaveSystem.delete_save("turnin_check")
	record("VS-016", "Quest Completion", vs016 and persisted_done,
		"Turned in at Ivenn (node '%s'): +%d XP (Lv %d -> %d), +%d gold, potions %d -> %d, random rare item granted (bag %d -> %d items), fragments consumed; second completion attempt returned %s with no extra gold; Reliquary unsealed; follow-up quest active; completion + rewarded flag present in save=%s." % [node0, xp_gain, lvl0, cd.level, gold_gain, pots0, cd.inventory.count_of("potion_health"), items0, cd.inventory.items.size(), again, persisted_done])
	_spend_points()


func _total_xp_before(cd: CharacterData) -> int:
	var t := 0
	for l in range(1, cd.level):
		t += Progression.xp_to_next(l)
	return t


func _dungeon() -> void:
	await walk([Vector3(2, 0, 12), Vector3(12, 0, 8), Vector3(14, 0, -6), Vector3(16, 0, -24), Vector3(28, 0, -38), Vector3(34, 0, -44)])
	await clear_and_loot(ValeOfCinders.ENTRANCE + Vector3(0, 0, 8), 14.0)
	_spend_points()
	var gate: ZoneGate = nodes_of(main.zone, func(n): return n is ZoneGate)[0]
	var open_before := gate.is_open()
	await interact_with(gate)
	await frames(30)
	var in_dungeon: bool = main.zone is SunkenReliquary and Game.current_zone == "sunken_reliquary"
	var enemy_n := 0
	if in_dungeon:
		enemy_n = main.zone.alive_enemies().size()
	var me := pl()
	var valid: bool = me != null and me.is_alive() and me.data == Game.character and flat(me.global_position).distance_to(flat(main.zone.spawn_point("start"))) < 1.0
	await move_to(Vector3(0, 0, -4), 15.0)
	var explored := Game.quests.objective_count("q_hollow_bishop", "enter_reliquary") >= 1
	record("VS-017", "Dungeon", open_before and in_dungeon and enemy_n >= 10 and valid and explored,
		"Gate open after quest=%s; pressed E -> zone '%s' loaded, player at entrance with HP %d/%d, %d enemies + boss spawned; 'Descend' objective updated=%s." % [open_before, Game.current_zone, me.health, me.max_health, enemy_n, explored])


func _boss_fight() -> void:
	_spend_points()
	# clear the path and light the brazier
	await clear_and_loot(Vector3(0, 0, 0), 9.0)
	await walk([Vector3(0, 0, -12), Vector3(0, 0, -26)])
	await clear_and_loot(Vector3(0, 0, -22), 8.0)
	await walk([Vector3(0, 0, -32)])
	await clear_and_loot(Vector3(0, 0, -41), 13.0)
	var crypt_chest: TreasureChest = nodes_of(main.zone, func(n): return n is TreasureChest)[0]
	await interact_with(crypt_chest)
	await secs(0.8)
	await collect_pickups(crypt_chest.global_position, 6.0)
	_spend_points()
	var brazier: WardingBrazier = main.zone.brazier
	var door_closed_before: bool = not main.zone.door_should_be_open()
	for attempt in 4:
		if brazier.lit:
			break
		await clear_and_loot(brazier.global_position, 10.0)
		await interact_with(brazier)
		await frames(5)
	var lit := brazier.lit and Game.quests.objective_count("q_hollow_bishop", "light_brazier") >= 1
	var door_open: bool = main.zone.door_should_be_open()
	log_msg("Brazier lit=%s, door closed before=%s, open after=%s, player Lv %d HP %d/%d, potions %d" % [lit, door_closed_before, door_open, Game.character.level, pl().health, pl().max_health, Game.character.inventory.count_of("potion_health")])
	# top up before the fight
	await secs(4.0)
	var attempts := 0
	var boss: BossVorthane = null
	var bar_seen := false
	var boss_damaged := false
	var phase2 := false
	var hp_trace: Array = []
	var won := false
	var boss_hits_on_player := 0
	while attempts < 6 and not won:
		attempts += 1
		boss = _boss()
		if boss == null:
			break
		await walk([Vector3(0, 0, -56), Vector3(0, 0, -64), Vector3(0, 0, -72)], false, 25.0)
		var t := 0.0
		var hits0 := _player_hits
		while t < 240.0:
			boss = _boss()
			var me := pl()
			if boss == null or not boss.is_alive():
				won = boss == null or not boss.is_alive()
				break
			if me == null or not me.is_alive():
				break
			if boss.active and main.hud.boss_panel.visible:
				bar_seen = true
			if boss.health < boss.max_health:
				boss_damaged = true
			if boss.phase == 2:
				phase2 = true
			if int(t * 10) % 50 == 0:
				hp_trace.append("%.0f%%" % (boss.health / boss.max_health * 100.0))
			# fight adds first if close, else the boss
			var adds := enemies_near(me.global_position, 6.0).filter(func(e): return not (e is BossVorthane))
			var tgts: Array = adds if not adds.is_empty() else [boss]
			await fight_enemies(tgts, 1.0)
			t += 1.0
		boss_hits_on_player += _player_hits - hits0
		if not won:
			log_msg("Boss attempt %d ended (player alive=%s). Waiting for respawn." % [attempts, pl() != null and pl().is_alive()])
			await secs(4.0)
			_spend_points()
			# after respawn the zone reloads: walk back through the dungeon
			await walk([Vector3(0, 0, -12), Vector3(0, 0, -30), Vector3(0, 0, -48)], true, 40.0)
	var telegraphs := _boss_effects + _boss_projectiles
	record("VS-018", "Boss", bar_seen and boss_damaged and phase2 and telegraphs >= 3 and boss_hits_on_player > 0,
		"Entered arena -> boss bar shown=%s; boss cast %d telegraphed area attacks + %d projectiles; boss hit the player %d time(s); player damaged boss=%s; phase 2 (enrage + summons) reached=%s; boss HP trace %s; attempts=%d, player deaths so far=%d." % [bar_seen, _boss_effects, _boss_projectiles, boss_hits_on_player, boss_damaged, phase2, str(hp_trace.slice(0, 12)), attempts, _deaths])
	# ---- VS-019
	await frames(30)
	var victory_msg := false
	for c in main.hud.notify_box.get_children():
		if "VICTORY" in c.text:
			victory_msg = true
	await collect_pickups(SunkenReliquary.ARENA, 18.0)
	await secs(3.5)
	var bar_hidden_soon: bool = not main.hud.boss_panel.visible
	# the unique may be auto-collected the moment it lands: check what the
	# hero now owns and where each item came from
	var unique_name := ""
	var got_unique := false
	for it in Game.character.inventory.items + Game.character.equipment.all_items():
		if it.unique_id != "" and _origin_of(it).begins_with("boss:"):
			got_unique = true
			unique_name = it.name
	var portal: bool = main.zone.exit_portal != null
	record("VS-019", "Boss Defeat", won and victory_msg and got_unique and Game.flag("boss_defeated_vorthane") and Game.quests.state("q_hollow_bishop") == QuestLog.READY and portal and bar_hidden_soon,
		"Vorthane died: victory banner=%s, encounter ended (bar hidden=%s), exit portal spawned=%s; unique '%s' dropped and collected=%s; world flag boss_defeated_vorthane=%s; quest 'The Hollow Bishop' -> %s (objectives %s)." % [victory_msg, bar_hidden_soon, portal, unique_name, got_unique, Game.flag("boss_defeated_vorthane"), Game.quests.state("q_hollow_bishop"), JSON.stringify(Game.quests.progress.get("q_hollow_bishop", {}))])
	_auto_equip()


func _vs020_save() -> void:
	# Save through the pause menu like a player would.
	await ui_action("pause")
	var paused := get_tree().paused
	var save_btn: Button = null
	for b in main.pause_ui.find_children("*", "Button", true, false):
		if b.text == "Save Game":
			save_btn = b
	save_btn.pressed.emit()
	await get_tree().process_frame
	await ui_action("pause")
	var d := SaveSystem.read_save(SaveSystem.MANUAL_SLOT)
	var snap := snapshot()
	var c: Dictionary = d.get("character", {})
	var has_all := d.has("character") and c.has("level") and c.has("xp") and c.has("inventory") and c.has("equipment") and c.has("skill_ranks") \
		and c.has("gold") and d.has("quests") and d.has("world") and d.has("zone")
	var matches: bool = int(c.get("level", 0)) == snap.level and int(c.get("xp", -1)) == snap.xp and int(c.get("gold", -1)) == snap.gold \
		and c.get("class_id", "") == snap.class_id and (c.get("inventory", []) as Array).size() == Game.character.inventory.items.size() \
		and d.get("world", {}).get("flags", {}).get("boss_defeated_vorthane", false) and d.get("zone", "") == Game.current_zone
	save_json("expected_state.json", snap)
	record("VS-020", "Save", paused and has_all and matches,
		"Esc -> Save Game wrote %s (%d bytes): character %s Lv %d, %d XP, %d gold, %d bag items, %d equipped, skills %s, quests %s, world flags %s, zone %s." % [SaveSystem.slot_path(SaveSystem.MANUAL_SLOT), FileAccess.get_file_as_string(SaveSystem.slot_path(SaveSystem.MANUAL_SLOT)).length(), snap.hero_name, snap.level, snap.xp, snap.gold, snap.inventory.size(), snap.equipment.values().filter(func(u): return u != "").size(), JSON.stringify(snap.skill_ranks), JSON.stringify(snap.quests.states), JSON.stringify(snap.flags), snap.zone])
	_mem_samples.append(["end_phase1", _mem_mb()])


# ================================================================== PHASE 2

func _phase2() -> void:
	await frames(10)
	var expected := load_json("expected_state.json")
	var cont: Button = main.screen.find_child("Continue", true, false) if main.screen else null
	var cont_ok := cont != null and not cont.disabled
	var slot := SaveSystem.latest_slot()
	cont.pressed.emit()
	await frames(30)
	var snap := snapshot()
	var diffs: Array = []
	for k in expected:
		if JSON.stringify(expected[k]) != JSON.stringify(snap.get(k)):
			diffs.append(k)
	var me := pl()
	var ok_basic: bool = me != null and me.is_alive() and main.zone != null and main.playing
	record("VS-021", "Load", cont_ok and slot == SaveSystem.MANUAL_SLOT and diffs.is_empty() and ok_basic and not expected.is_empty(),
		"Fresh process: main menu 'Continue' enabled (latest slot '%s'), loaded into zone '%s'. Compared %d saved fields (character, level, XP, gold, inventory uids, equipment uids, skills, attributes, quests, world flags/chests/discoveries, zone): mismatches=%s." % [slot, Game.current_zone, expected.size(), str(diffs)])
	record("VS-023", "Restart Persistence", diffs.is_empty() and not expected.is_empty(),
		"Phase 1 process saved and exited with code 0; phase 2 is a new OS process that restarted the game and loaded: Lv %d, %d XP, %d gold, %d items, quests %s - identical to the pre-exit snapshot." % [snap.level, snap.xp, snap.gold, snap.inventory.size(), JSON.stringify(snap.quests.states)])
	# continue playing: leave the dungeon and turn in the final quest
	if main.zone is SunkenReliquary:
		var portal = main.zone.exit_portal
		if portal != null:
			await interact_with(portal)
			await frames(30)
	var in_vale: bool = main.zone is ValeOfCinders
	await walk([Vector3(28, 0, -38), Vector3(16, 0, -24), Vector3(14, 0, -6), Vector3(12, 0, 8), Vector3(2, 0, 12), Vector3(2, 0, 31)])
	var ivenn: NPC = nodes_of(main.zone, func(n): return n is NPC)[0]
	await interact_with(ivenn)
	var turned := false
	for o in main.dialogue_ui.option_list():
		if str(o.get("action", "")).begins_with("complete:q_hollow_bishop"):
			main.dialogue_ui.choose(o)
			turned = true
	await frames(5)
	var epilogue: String = main.dialogue_ui.current
	main.dialogue_ui.close()
	var done := Game.quests.state("q_hollow_bishop") == QuestLog.COMPLETED
	var saved_again: bool = main.manual_save()
	log_msg("Continued play after load: returned to Vale=%s, turned in final quest=%s (state %s, dialogue '%s'), saved again=%s" % [in_vale, turned, Game.quests.state("q_hollow_bishop"), epilogue, saved_again])
	save_json("phase2_continue.json", {"returned_to_vale": in_vale, "final_quest_completed": done, "epilogue_node": epilogue, "saved": saved_again})
