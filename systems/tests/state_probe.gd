extends Node
## Debug/test probe. Enabled only with the command-line argument
##   -- --state-file=<path>
## Periodically writes a JSON snapshot of the game (player state, open
## windows, visible buttons and on-screen positions of NPCs/enemies) so an
## external driver can play the real game window with real OS mouse/keyboard
## events (tools/real_input_test.py) and verify what happened.

var path := ""
var _t := 0.0
var dodges := 0
var attacks := 0
var heavies := 0
var skills_cast := 0
var interacts := 0
var main


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	Events.skill_used.connect(func(_s): skills_cast += 1)
	Events.object_interacted.connect(func(_o): interacts += 1)


func _process(delta: float) -> void:
	var p: Player = Game.player if Game.player and is_instance_valid(Game.player) else null
	if p:
		dodges = p.dodge_count
		heavies = p.heavy_count
	_t += delta
	if _t < 0.2:
		return
	_t = 0.0
	_write(p)


func _screen(pos: Vector3) -> Array:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(pos):
		return []
	var sp := get_viewport().get_final_transform() * cam.unproject_position(pos)
	return [sp.x, sp.y]


func _buttons() -> Array:
	var out: Array = []
	for b in main.ui.find_children("*", "Button", true, false):
		if b.is_visible_in_tree():
			var c: Vector2 = get_viewport().get_final_transform() * b.get_global_rect().get_center()
			out.append({"text": b.text, "name": String(b.name), "x": c.x, "y": c.y})
	return out


func _write(p: Player) -> void:
	var d := {
		"time": Time.get_ticks_msec(),
		"screen": String(main.screen.name) if main.screen and is_instance_valid(main.screen) else "",
		"playing": main.playing, "paused": get_tree().paused,
		"windows": {
			"inventory": main.inventory_ui.visible, "character": main.character_ui.visible, "skills": main.skills_ui.visible,
			"quests": main.quest_ui.visible, "dialogue": main.dialogue_ui.visible, "merchant": main.merchant_ui.visible,
			"map": main.map_overlay.visible,
		},
		"dialogue_node": main.dialogue_ui.current if main.dialogue_ui.visible else "",
		"buttons": _buttons(),
		"counters": {"dodges": dodges, "heavies": heavies, "skills": skills_cast, "interacts": interacts},
	}
	if p:
		var enemies: Array = []
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive():
				enemies.append({"id": e.enemy_id, "dist": p.flat_distance_to(e.global_position), "screen": _screen(e.global_position + Vector3(0, 0.8, 0)), "hp": e.health, "aggro": e.aggro})
		enemies.sort_custom(func(a, b): return a.dist < b.dist)
		var npcs: Array = []
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is NPC:
				npcs.append({"id": n.npc_id, "dist": p.flat_distance_to(n.global_position), "screen": _screen(n.global_position + Vector3(0, 0.8, 0))})
		d["player"] = {
			"pos": [p.global_position.x, p.global_position.y, p.global_position.z], "screen": _screen(p.global_position + Vector3(0, 0.8, 0)),
			"health": p.health, "max_health": p.max_health, "mana": p.mana, "stamina": p.stamina,
			"cooldowns": p.skill_cooldowns, "click_mode": p.click_mode, "level": Game.character.level, "xp": Game.character.xp,
			"kills": Game.character.kills, "inventory": Game.character.inventory.items.size(), "status": p.status.names(),
		}
		d["enemies"] = enemies.slice(0, 6)
		d["npcs"] = npcs
		d["quests"] = Game.quests.states
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()
		DirAccess.rename_absolute(path + ".tmp", path)
