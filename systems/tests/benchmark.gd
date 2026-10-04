extends Node
## Performance probe for VS-025.
##   rendered: godot --rendering-driver opengl3 res://systems/tests/benchmark.tscn -- --out=perf_rendered.json
##   headless: godot --headless --fixed-fps 60 res://systems/tests/benchmark.tscn -- --out=perf_headless.json
## Measures frame times during a crowded fight and checks that memory and
## node counts do not keep growing across repeated zone loads + combat.

var out_name := "perf.json"
var main
var frame_ms: Array = []
var recording := false
var _last_us := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_name = a.substr(6)
	SaveSystem.autosave_enabled = false
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _process(delta: float) -> void:
	if not recording:
		return
	if DisplayServer.get_name() == "headless":
		# fixed-fps headless never sleeps, so wall time between frames is the
		# real CPU cost of one full frame (physics + scripts + dummy render)
		var now := Time.get_ticks_usec()
		if _last_us > 0:
			frame_ms.append((now - _last_us) / 1000.0)
		_last_us = now
	else:
		frame_ms.append(delta * 1000.0)


func _wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	if DisplayServer.get_name() == "headless":
		for i in int(t * 60.0):
			await get_tree().physics_frame
		return
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _fight_burst(seconds: float) -> void:
	var p: Player = Game.player
	p.iframes = 99999.0
	var elapsed := 0.0
	while elapsed < seconds:
		var es := get_tree().get_nodes_in_group("enemies")
		if not es.is_empty():
			p.aim_override = es[0].global_position
			p.try_attack()
			for sid in p.data.hotbar_skills():
				if p.skill_block_reason(sid) == "":
					p.try_skill(sid)
					break
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0


func _stats(arr: Array) -> Dictionary:
	if arr.is_empty():
		return {}
	var s := arr.duplicate()
	s.sort()
	var total := 0.0
	for v in s:
		total += v
	return {"frames": s.size(), "avg_ms": total / s.size(), "p50_ms": s[s.size() / 2], "p95_ms": s[int(s.size() * 0.95)], "p99_ms": s[int(s.size() * 0.99)], "max_ms": s[-1], "avg_fps": 1000.0 / (total / s.size())}


func _run() -> void:
	await _wait(0.5)
	main.start_new_game("dawnwarden")
	Game.character.add_xp(3000)
	for sid in Game.character.class_data().skills:
		while Game.character.can_learn_skill(sid):
			Game.character.learn_skill(sid)
	await _wait(1.0)
	var load_t0 := Time.get_ticks_msec()
	main.change_zone("vale_of_cinders", "start")
	var zone_load_ms := Time.get_ticks_msec() - load_t0
	# crowded fight in the chapel: existing pack + 12 extra enemies
	Game.player.global_position = Vector3(0, 0.1, 6)
	for i in 12:
		var kinds := ["hollow_sentinel", "gloomfang", "ashen_cultist", "veilstalker"]
		main.zone.add_enemy(kinds[i % 4], 3, Vector3(randf_range(-6, 6), 0, randf_range(-6, 4)))
	await _wait(0.5)
	recording = true
	await _fight_burst(20.0)
	recording = false
	var fight := _stats(frame_ms)
	# exploration frame times (camera moving across the map)
	frame_ms.clear()
	recording = true
	var p: Player = Game.player
	p.move_override = Vector2(1, -0.3)
	await _wait(8.0)
	p.move_override = Vector2.ZERO
	recording = false
	var explore := _stats(frame_ms)
	# memory / node-count stability across repeated zone loads + combat
	var samples: Array = []
	for cycle in 6:
		main.change_zone("sunken_reliquary" if cycle % 2 == 0 else "vale_of_cinders", "start")
		await _wait(1.0)
		await _fight_burst(6.0)
		await _wait(1.0)
		samples.append({
			"cycle": cycle,
			"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		})
	var data := {
		"date": Time.get_datetime_string_from_system(),
		"display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_video_adapter_vendor(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"cpu": OS.get_processor_name(), "cpu_cores": OS.get_processor_count(),
		"zone_load_ms": zone_load_ms, "fight_15plus_enemies": fight, "exploration": explore, "memory_cycles": samples,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_output"))
	var path := ProjectSettings.globalize_path(("res://systems/tests/output/" if OS.has_feature("editor") else "user://test_output/") + out_name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("BENCHMARK ", JSON.stringify(data))
	get_tree().quit()
