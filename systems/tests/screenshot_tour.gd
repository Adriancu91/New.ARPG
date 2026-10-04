extends Node
## Visual verification tour (needs a display; run under Xvfb on CI):
##   godot --rendering-driver opengl3 res://systems/tests/screenshot_tour.tscn -- --out=<dir>
## Captures the menu, character select, gameplay spots and UI windows.

var out_dir := "res://systems/tests/output/screens"
var main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	SaveSystem.autosave_enabled = false
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	_tour.call_deferred()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir + "/" + name + ".png")
	img.save_png(path)
	print("SHOT ", path)


func _tour() -> void:
	await _wait(30)
	await _shot("01_main_menu")
	main.show_character_select()
	await _wait(10)
	await _shot("02_select_dawnwarden")
	main.preview_class("hellbrand")
	await _wait(10)
	await _shot("03_select_hellbrand")
	main.preview_class("starweaver")
	await _wait(10)
	await _shot("04_select_starweaver")
	main.start_new_game("dawnwarden")
	await _wait(60)
	await _shot("05_camp_start")
	var p: Player = Game.player
	p.iframes = 9999.0
	p.global_position = Vector3(0, 0.1, 8)
	p.face_direction(Vector3(0, 0, -1))
	main.camera.snap()
	await _wait(40)
	await _shot("06_chapel")
	# combat moment
	p.aim_override = p.global_position + Vector3(0, 0, -5)
	p.try_skill("radiant_cleave")
	await _wait(8)
	await _shot("07_combat")
	p = Game.player
	p.global_position = Vector3(44, 0.1, 6)
	main.camera.snap()
	await _wait(40)
	await _shot("08_shrine")
	p.global_position = Vector3(-38, 0.1, 6)
	main.camera.snap()
	await _wait(40)
	await _shot("09_forest")
	p.global_position = Vector3(34, 0.1, -44)
	main.camera.snap()
	await _wait(40)
	await _shot("10_reliquary_gate")
	# UI windows
	Game.character.inventory.add(ItemGenerator.generate(Game.rng, 4, "epic", "sword", "weapon"))
	main.inventory_ui.open()
	main.inventory_ui.selected = Game.character.inventory.items[-1]
	main.inventory_ui.refresh()
	await _wait(5)
	await _shot("11_inventory_compare")
	main.inventory_ui.close()
	main.character_ui.open()
	await _wait(5)
	await _shot("12_character")
	main.character_ui.close()
	main.skills_ui.open()
	await _wait(5)
	await _shot("13_skills")
	main.skills_ui.close()
	# dungeon + boss
	Game.set_flag("reliquary_unsealed")
	main.change_zone("sunken_reliquary", "start")
	await _wait(60)
	await _shot("14_reliquary_entry")
	Game.world_list_add("interacted", "obj_warding_brazier")
	main.zone.brazier._set_lit(true)
	Game.player.iframes = 9999.0
	Game.player.global_position = Vector3(0, 0.1, -50)
	main.camera.snap()
	await _wait(30)
	await _shot("15_brazier")
	Game.player.global_position = Vector3(0, 0.1, -72)
	main.camera.snap()
	await _wait(60)
	await _shot("16_boss")
	await _wait(80)
	await _shot("17_boss_attack")
	get_tree().quit()
