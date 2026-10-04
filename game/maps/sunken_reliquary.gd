class_name SunkenReliquary
extends Zone
## The vertical-slice dungeon: entry hall -> crypt hall -> warding brazier ->
## boss arena of Vorthane, the Hollow Bishop.

const ARENA := Vector3(0, 0, -82)
const ARENA_R := 17.0

var boss: BossVorthane = null
var door_body: StaticBody3D
var door_mesh: MeshInstance3D
var door_glow: MeshInstance3D
var brazier: WardingBrazier
var exit_portal: ZoneGate = null
var _encounter_active := false


func _init() -> void:
	zone_id = "sunken_reliquary"
	display_name = "The Sunken Reliquary"
	music = "music_reliquary"
	ambience = ""
	bounds = Rect2(-20, -102, 40, 118)
	spawns = {
		"start": Vector3(0, 0, 8),
		"arena": ARENA + Vector3(0, 0, 12),
	}


func build() -> void:
	make_environment("dungeon")
	make_ground(Vector2(44, 124), Color("#25222a"), Color("#33303a"), Vector3(0, 0, -44), 0.15)
	_ceiling_dark()
	_entry_hall()
	_crypt_hall()
	_boss_wing()
	_spawn_enemies()


func _ceiling_dark() -> void:
	make_bounds(bounds, 8.0)


func _walls(segments: Array, height: float = 6.0) -> void:
	for s in segments:
		Props.wall(self, s[0], s[1], height, 1.0, false, "stone_dark")


func _entry_hall() -> void:
	_walls([
		[Vector3(-8, 0, -12), Vector3(-8, 0, 14)], [Vector3(8, 0, -12), Vector3(8, 0, 14)],
		[Vector3(-8, 0, 14), Vector3(-2.4, 0, 14)], [Vector3(2.4, 0, 14), Vector3(8, 0, 14)],
		[Vector3(-8, 0, -12), Vector3(-3, 0, -12)], [Vector3(3, 0, -12), Vector3(8, 0, -12)],
		[Vector3(-3, 0, -30), Vector3(-3, 0, -12)], [Vector3(3, 0, -30), Vector3(3, 0, -12)],
	])
	var gate := ZoneGate.create("gate_reliquary_exit", "vale_of_cinders", "reliquary_exit", "Return to the Vale of Cinders")
	add_child(gate)
	gate.global_position = Vector3(0, 0, 13.6)
	poi(gate.global_position, "exit", "Exit")
	for p in [Vector3(-6.5, 0, 10), Vector3(6.5, 0, 10), Vector3(-6.5, 0, -8), Vector3(6.5, 0, -8)]:
		Props.torch(self, p, Color(1.0, 0.55, 0.25), 1.8, p.z > 0)
	for z in [4.0, -4.0]:
		Props.pillar(self, Vector3(-4.5, 0, z), 6.0)
		Props.pillar(self, Vector3(4.5, 0, z), 6.0, z < 0)
	add_child(LoreStone.create("lore_reliquary_warning", "Scratched into the door",
		"\"HE IS STILL PRAYING. DO NOT ANSWER.\"", "stone"))
	get_child(get_child_count() - 1).global_position = Vector3(-5, 0, 12)
	var trig := AreaTrigger.create("area_reliquary_depths", 6.0, "The Sunken Reliquary")
	add_child(trig)
	trig.global_position = Vector3(0, 0, -6)
	Props.torch(self, Vector3(-2, 0, -21), Color(0.7, 0.4, 1.0), 1.5)
	Props.torch(self, Vector3(2, 0, -26), Color(0.7, 0.4, 1.0), 1.5)


func _crypt_hall() -> void:
	_walls([
		[Vector3(-12, 0, -52), Vector3(-12, 0, -30)], [Vector3(12, 0, -52), Vector3(12, 0, -30)],
		[Vector3(-12, 0, -30), Vector3(-3, 0, -30)], [Vector3(3, 0, -30), Vector3(12, 0, -30)],
		[Vector3(-12, 0, -52), Vector3(-3, 0, -52)], [Vector3(3, 0, -52), Vector3(12, 0, -52)],
		[Vector3(-3, 0, -66), Vector3(-3, 0, -52)], [Vector3(3, 0, -66), Vector3(3, 0, -52)],
	])
	poi(Vector3(0, 0, -41), "ruin", "Crypt of Bells")
	# sarcophagi rows
	for z in [-35.0, -41.0, -47.0]:
		for x in [-7.5, 7.5]:
			K.part(self, K.box(Vector3(1.4, 0.9, 2.6)), Props.m("stone", Props.STONE), Vector3(x, 0.45, z))
			K.part(self, K.box(Vector3(1.5, 0.15, 2.7)), Props.m("stone_dark", Props.STONE_DARK), Vector3(x, 0.95, z))
			Props.collider_box(self, Vector3(1.4, 1.0, 2.6), Vector3(x, 0.5, z))
	for p in [Vector3(-10.5, 0, -32), Vector3(10.5, 0, -32), Vector3(-10.5, 0, -50), Vector3(10.5, 0, -50)]:
		Props.torch(self, p, Color(1.0, 0.45, 0.2), 1.8, p.x < 0 and p.z > -40)
	var chest := TreasureChest.create("chest_crypt", 4)
	add_child(chest)
	chest.global_position = Vector3(10.2, 0, -41)
	chest.rotation.y = -PI * 0.5
	poi(chest.global_position, "chest")
	# the warding brazier (quest interact objective)
	brazier = WardingBrazier.create("obj_warding_brazier")
	add_child(brazier)
	brazier.global_position = Vector3(0, 0, -49)
	poi(brazier.global_position, "objective", "Warding Brazier")
	for i in 6:
		Props.bones(self, Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-50, -32)), i)


func _boss_wing() -> void:
	# sealed door between corridor and arena
	door_body = Props.collider_box(self, Vector3(6.0, 6.0, 1.0), Vector3(0, 3.0, -63))
	door_mesh = K.part(self, K.box(Vector3(6.0, 6.0, 0.8)), K.mat(Color("#1c1820"), 0.0, 0.7, 0.4), Vector3(0, 3.0, -63))
	door_glow = K.part(self, K.torus(0.9, 1.15), K.glow_mat(Color(0.9, 0.2, 0.3), 2.5), Vector3(0, 3.0, -62.5), Vector3(90, 0, 0), Vector3.ONE, false)
	var door_label := Label3D.new()
	door_label.text = "Light the Warding Brazier"
	door_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	door_label.font_size = 40
	door_label.pixel_size = 0.006
	door_label.outline_size = 8
	door_label.modulate = Color(1.0, 0.6, 0.5)
	door_label.position = Vector3(0, 6.5, -62.4)
	door_label.name = "DoorLabel"
	add_child(door_label)
	# arena ring
	var segs := 18
	for i in segs:
		var a0 := TAU * float(i) / segs + PI * 0.5 + PI / segs
		var a1 := TAU * float(i + 1) / segs + PI * 0.5 + PI / segs
		if i == segs - 1:
			continue   # opening facing south (+Z) toward the corridor
		var p0 := ARENA + Vector3(cos(a0), 0, sin(a0)) * ARENA_R
		var p1 := ARENA + Vector3(cos(a1), 0, sin(a1)) * ARENA_R
		Props.wall(self, p0, p1, 7.0, 1.2, false, "stone_dark")
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		var p := ARENA + Vector3(cos(a), 0, sin(a)) * (ARENA_R - 3.0)
		Props.pillar(self, p, 7.0, i % 3 == 1)
		Props.flicker(self, Color(0.9, 0.2, 0.3), 2.0, 10.0, p + Vector3(0, 6.0, 0))
	K.part(self, K.cyl(ARENA_R - 1.0, ARENA_R - 1.0, 0.04, 40), K.mat(Color("#2a1e24"), 0.0, 0.8), ARENA + Vector3(0, 0.02, 0))
	K.part(self, K.torus(5.5, 6.0), K.glow_mat(Color(0.6, 0.1, 0.2), 1.5, 0.7), ARENA + Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 0.05, 1), false)
	poi(ARENA, "boss", "Vorthane")
	var trig := AreaTrigger.create("area_boss_arena", 9.0, "")
	add_child(trig)
	trig.global_position = ARENA + Vector3(0, 0, 8)
	trig.entered.connect(_start_encounter)


func _spawn_enemies() -> void:
	add_pack("hollow_sentinel", 2, Vector3(0, 0, -2), 3.0, 3)
	add_pack("gloomfang", 3, Vector3(0, 0, -22), 1.5, 3)
	add_pack("ashen_cultist", 3, Vector3(0, 0, -44), 6.0, 4)
	add_pack("hollow_sentinel", 2, Vector3(-5, 0, -38), 2.0, 4)
	add_enemy("veilstalker", 4, Vector3(6, 0, -36))
	add_enemy("cinder_colossus", 4, Vector3(0, 0, -40))
	if not Game.flag("boss_defeated_vorthane"):
		boss = BossVorthane.create_boss(5)
		enemy_root.add_child(boss)
		boss.global_position = ARENA + Vector3(0, 0, -6)
		boss.home = boss.global_position
		boss.rotation.y = 0.0
		boss.arena_center = ARENA
		boss.died.connect(func(_b): _on_boss_dead())
	else:
		_spawn_exit_portal()


func door_should_be_open() -> bool:
	if _encounter_active:
		return false
	return brazier != null and brazier.lit


func _process(_delta: float) -> void:
	var open := door_should_be_open()
	door_mesh.visible = not open
	door_glow.visible = not open
	door_body.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	for c in door_body.get_children():
		if c is CollisionShape3D:
			c.disabled = open
	var lbl := get_node_or_null("DoorLabel")
	if lbl:
		lbl.visible = not open and not _encounter_active


func _start_encounter() -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_alive():
		return
	_encounter_active = true
	Audio.play("door")
	boss.activate()


func _on_boss_dead() -> void:
	_encounter_active = false
	_spawn_exit_portal()
	if SaveSystem:
		get_tree().create_timer(1.0, false).timeout.connect(SaveSystem.autosave)


func _spawn_exit_portal() -> void:
	if exit_portal != null:
		return
	exit_portal = ZoneGate.create("portal_reliquary_out", "vale_of_cinders", "reliquary_exit", "Return to the surface")
	add_child(exit_portal)
	exit_portal.global_position = ARENA + Vector3(0, 0, -12)
	poi(exit_portal.global_position, "exit", "Way out")
	VFX.pillar(self, exit_portal.global_position, 2.0, 6.0, Color(0.6, 0.8, 1.0), 1.0)


## Called when the player dies: reset the boss fight so it can be retried.
func reset_encounter() -> void:
	_encounter_active = false
