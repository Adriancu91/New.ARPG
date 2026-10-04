class_name ValeOfCinders
extends Zone
## The first outdoor region: a burned valley of ruined chapels, a corrupted
## forest, a cultist camp, the Shrine of the Broken Saint and the sealed
## entrance of the Sunken Reliquary.
##
## Layout (top-down, -Z is north):
##   NW cultist camp      N  bridge + Reliquary gate (NE)
##   W  corrupted forest  C  ruined chapel        E  Shrine of the Broken Saint
##                        S  Ivenn's camp (player start)

const ENTRANCE := Vector3(34, 0, -52)
var _reinforce_cd := 0.0


func _init() -> void:
	zone_id = "vale_of_cinders"
	display_name = "The Vale of Cinders"
	music = "music_vale"
	ambience = "ambience_wind"
	bounds = Rect2(-70, -72, 140, 138)
	spawns = {
		"start": Vector3(0, 0, 44),
		"reliquary_exit": ENTRANCE + Vector3(0, 0, 6),
	}


func build() -> void:
	make_environment("outdoor")
	make_ground(Vector2(170, 170), Color("#2d2a27"), Color("#3d3528"))
	make_bounds(bounds)
	_border_rocks()
	make_path([Vector3(0, 0, 50), Vector3(0, 0, 32), Vector3(2, 0, 12), Vector3(0, 0, -4), Vector3(14, 0, -22), Vector3(28, 0, -38), ENTRANCE + Vector3(0, 0, 4)], 4.0, Color("#241f1b"))
	make_path([Vector3(2, 0, 12), Vector3(22, 0, 4), Vector3(40, 0, -2)], 3.0, Color("#241f1b"))
	make_path([Vector3(0, 0, -4), Vector3(-16, 0, -18), Vector3(-28, 0, -34)], 3.0, Color("#241f1b"))
	_camp()
	_chapel_ruins()
	_corrupted_forest()
	_cultist_camp()
	_shrine()
	_bridge_and_gate()
	_decoration()
	_spawn_enemies()


func _border_rocks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 64:
		var t := float(i) / 64.0
		var p: Vector3
		if t < 0.25: p = Vector3(lerpf(bounds.position.x, bounds.end.x, t * 4.0), 0, bounds.position.y)
		elif t < 0.5: p = Vector3(bounds.end.x, 0, lerpf(bounds.position.y, bounds.end.y, (t - 0.25) * 4.0))
		elif t < 0.75: p = Vector3(lerpf(bounds.end.x, bounds.position.x, (t - 0.5) * 4.0), 0, bounds.end.y)
		else: p = Vector3(bounds.position.x, 0, lerpf(bounds.end.y, bounds.position.y, (t - 0.75) * 4.0))
		Props.rock(self, p + Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)), r.randf_range(2.5, 4.5), i)


func _camp() -> void:
	var c := Vector3(0, 0, 36)
	Props.campfire(self, c)
	Props.tent(self, c + Vector3(-6, 0, 2), 20)
	Props.tent(self, c + Vector3(6.5, 0, 3), -25)
	Props.banner(self, c + Vector3(-3, 0, -5), Color("#8a6d3b"))
	Props.torch(self, c + Vector3(3, 0, -6))
	var ivenn := NPC.create("npc_ivenn")
	add_child(ivenn)
	ivenn.global_position = c + Vector3(3.2, 0, -1.5)
	ivenn.rotation.y = PI
	poi(ivenn.global_position, "npc", "Brother Ivenn")
	add_child(LoreStone.create("lore_ivenn_letter", "A letter, never sent",
		"\"Mira, the Vale is lost. The Bishop went below to pray the ash away and the bells have not stopped since. I will keep the lamps lit as long as the oil lasts. If you read this, do not come home.\" - I.", "letter"))
	get_child(get_child_count() - 1).global_position = c + Vector3(-3, 0, 4)


func _chapel_ruins() -> void:
	var c := Vector3(0, 0, 0)
	poi(c, "ruin", "Ruined Chapel")
	Props.wall(self, c + Vector3(-9, 0, -8), c + Vector3(-9, 0, 6), 4.5)
	Props.wall(self, c + Vector3(9, 0, -8), c + Vector3(9, 0, 1), 4.0)
	Props.wall(self, c + Vector3(-9, 0, -8), c + Vector3(-2, 0, -8), 5.0)
	Props.wall(self, c + Vector3(3, 0, -8), c + Vector3(9, 0, -8), 3.5)
	for z in [-5.0, -1.0, 3.0]:
		Props.pillar(self, c + Vector3(-5, 0, z), 5.0, z == -1.0)
		Props.pillar(self, c + Vector3(5, 0, z), 5.0, z == 3.0)
	Props.arch(self, c + Vector3(0, 0, 9), 0.0, 4.5)
	# altar, chest and the world-placed lamp fragment
	K.part(self, K.box(Vector3(3.0, 1.0, 1.4)), Props.m("stone_dark", Props.STONE_DARK), c + Vector3(0, 0.5, -6))
	K.part(self, K.box(Vector3(2.6, 0.05, 1.0)), K.mat(Color("#5a1a1e"), 0.1, 0.9), c + Vector3(0, 1.03, -6))
	Props.collider_box(self, Vector3(3.0, 1.0, 1.4), c + Vector3(0, 0.5, -6))
	Props.torch(self, c + Vector3(-2.5, 0, -7), Color(1.0, 0.55, 0.25), 1.6, true)
	Props.torch(self, c + Vector3(2.5, 0, -7), Color(1.0, 0.55, 0.25), 1.6)
	var fragment_id := "pickup_fragment_chapel"
	if not Game.world_list_has("taken_pickups", fragment_id):
		var frag := LootPickup.spawn(self, c + Vector3(0, 1.2, -6), Item.make_stack("lamp_fragment", 1), 0, c + Vector3(0, 0, -4.6))
		frag.persist_id = fragment_id
	var chest := TreasureChest.create("chest_chapel", 2)
	add_child(chest)
	chest.global_position = c + Vector3(6.5, 0, -6)
	chest.rotation.y = -PI * 0.5
	poi(chest.global_position, "chest")
	add_child(LoreStone.create("lore_chapel", "Hymnal of the Sunfallen Order",
		"\"When the last star falls, one Oath will remain. She will carry the dawn in her blade and she will not kneel.\" The page is scorched around the edges, as if someone tried to burn only this verse.", "stone"))
	get_child(get_child_count() - 1).global_position = c + Vector3(-7, 0, 5)
	for i in 5:
		Props.bones(self, c + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-6, 6)), i)
	add_child(AreaTrigger.create("area_chapel", 9.0, "Ruined Chapel"))
	get_child(get_child_count() - 1).global_position = c


func _corrupted_forest() -> void:
	var c := Vector3(-42, 0, 2)
	poi(c, "forest", "Weeping Thicket")
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for i in 46:
		var p := c + Vector3(r.randf_range(-24, 24), 0, r.randf_range(-30, 30))
		if Vector2(p.x - c.x, p.z - c.z).length() < 5.0:
			continue
		if i % 4 == 0:
			Props.corrupted_tree(self, p, r.randf_range(1.0, 1.6), i)
		else:
			Props.dead_tree(self, p, r.randf_range(0.9, 1.7), i)
	for i in 4:
		add_child(LoreStone.create("lore_grave_%d" % i, ["Grave of a Lamplighter", "Grave of a Child of the Vale", "Grave of Sister Oriel", "Unmarked Grave"][i],
			["The stone reads: KEPT THE FLAME. Someone has left a candle stub, long cold.",
			"Small, freshly dug, and empty. The dirt has been pushed out from below.",
			"\"She sang until the ash took her voice.\" Wildflowers grow here and nowhere else in the Vale.",
			"No name. Only a sword driven into the earth, rusted to the hilt."][i], "grave"))
		get_child(get_child_count() - 1).global_position = c + Vector3(-4 + i * 2.6, 0, 6 + (i % 2) * 1.5)
	var chest := TreasureChest.create("chest_forest", 2)
	add_child(chest)
	chest.global_position = c + Vector3(-12, 0, -18)
	poi(chest.global_position, "chest")
	add_child(AreaTrigger.create("area_thicket", 14.0, "Weeping Thicket"))
	get_child(get_child_count() - 1).global_position = c
	var mist := K.embers(self, Color(0.6, 0.3, 0.9), 40, Vector3(20, 1, 26), c + Vector3(0, 0.5, 0), 0.2)
	mist.lifetime = 4.0


func _cultist_camp() -> void:
	var c := Vector3(-30, 0, -40)
	poi(c, "camp", "Cinder Cult Camp")
	Props.campfire(self, c)
	Props.tent(self, c + Vector3(-6, 0, -4), 40)
	Props.tent(self, c + Vector3(5, 0, -6), -30)
	for i in 6:
		var a := i * TAU / 6.0
		Props.torch(self, c + Vector3(cos(a), 0, sin(a)) * 9.0, Color(1.0, 0.35, 0.15), 1.4)
	Props.banner(self, c + Vector3(0, 0, -9), Color("#5a1418"))
	var chest := TreasureChest.create("chest_cult_camp", 3, ["lamp_fragment:1"])
	add_child(chest)
	chest.global_position = c + Vector3(0, 0, -6)
	poi(chest.global_position, "chest")
	add_child(LoreStone.create("lore_cult_orders", "Cultist Orders",
		"\"Gather the shards of the Lamp. The Bishop's hunger must not be sealed again. Whoever brings a shard to the Reliquary will be unmade and remade.\"", "letter"))
	get_child(get_child_count() - 1).global_position = c + Vector3(3, 0, 2)
	add_child(AreaTrigger.create("area_cult_camp", 10.0, "Cinder Cult Camp"))
	get_child(get_child_count() - 1).global_position = c


func _shrine() -> void:
	var c := Vector3(46, 0, -4)
	poi(c, "shrine", "Shrine of the Broken Saint")
	Props.statue_broken_saint(self, c)
	for i in 8:
		var a := i * TAU / 8.0
		Props.pillar(self, c + Vector3(cos(a), 0, sin(a)) * 8.0, 4.5, i % 3 == 0)
	var chest := TreasureChest.create("chest_shrine", 3, ["lamp_fragment:1"])
	add_child(chest)
	chest.global_position = c + Vector3(0, 0, 4.5)
	chest.rotation.y = PI
	poi(chest.global_position, "chest")
	var trig := AreaTrigger.create("area_broken_saint", 10.0, "Shrine of the Broken Saint")
	add_child(trig)
	trig.global_position = c
	add_child(LoreStone.create("lore_saint", "The Broken Saint",
		"Saint Aurelie held back the first darkness with nothing but a lamp. The Order carved her kneeling, so that no knight would ever stand taller than her. Someone has struck her head from her shoulders.", "stone"))
	get_child(get_child_count() - 1).global_position = c + Vector3(-4, 0, 5)


func _bridge_and_gate() -> void:
	# a ravine crossed by a broken bridge, then the Reliquary gate
	var bc := Vector3(22, 0, -32)
	poi(bc, "bridge", "Old Bridge")
	for sx in [-1.0, 1.0]:
		Props.wall(self, bc + Vector3(-3, 0, 2.5 * sx), bc + Vector3(5, 0, 2.5 * sx), 1.2, 0.5, false, "stone_dark")
	K.part(self, K.box(Vector3(10, 0.3, 5)), Props.m("stone", Props.STONE), bc + Vector3(1, 0.15, 0))
	var gate := ZoneGate.create("gate_reliquary", "sunken_reliquary", "start", "Descend into the Sunken Reliquary",
		"reliquary_unsealed", "The Reliquary is sealed by a cracked sigil. Brother Ivenn may know how to open it.")
	add_child(gate)
	gate.global_position = ENTRANCE
	poi(ENTRANCE, "dungeon", "Sunken Reliquary")
	Props.wall(self, ENTRANCE + Vector3(-14, 0, -1), ENTRANCE + Vector3(-2.2, 0, -1), 5.0, 1.2, true)
	Props.wall(self, ENTRANCE + Vector3(2.2, 0, -1), ENTRANCE + Vector3(16, 0, -1), 5.0, 1.2, true)
	Props.torch(self, ENTRANCE + Vector3(-3.5, 0, 2.5), Color(0.5, 0.7, 1.0), 2.0, true)
	Props.torch(self, ENTRANCE + Vector3(3.5, 0, 2.5), Color(0.5, 0.7, 1.0), 2.0)
	add_child(AreaTrigger.create("area_reliquary_gate", 9.0, "Gate of the Sunken Reliquary"))
	get_child(get_child_count() - 1).global_position = ENTRANCE + Vector3(0, 0, 4)


func _decoration() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var avoid := [Vector3(0, 10, 0), Vector3(0, 10, 36), Vector3(46, 10, -4), Vector3(-30, 10, -40), ENTRANCE, Vector3(22, 6, -32)]
	Props.scatter(self, K.sphere(0.35, 6), Props.m("rock", Color("#4a4642")), 260, Rect2(-66, -68, 132, 130), r, avoid, Vector2(0.4, 1.4))
	var tuft := K.cyl(0.0, 0.18, 0.5, 4)
	Props.scatter(self, tuft, Props.m("dry_grass", Color("#5a4e33")), 420, Rect2(-66, -68, 132, 130), r, avoid, Vector2(0.5, 1.2))
	for i in 18:
		var p := Vector3(r.randf_range(-60, 60), 0, r.randf_range(-60, 55))
		var skip := false
		for a in avoid:
			if Vector2(p.x - a.x, p.z - a.z).length() < a.y + 3.0:
				skip = true
		if not skip:
			Props.dead_tree(self, p, r.randf_range(0.8, 1.4), i + 100)
	for i in 10:
		Props.rock(self, Vector3(r.randf_range(-55, 55), 0, r.randf_range(-55, 50)), r.randf_range(0.8, 1.8), i + 7)
	var ash := K.embers(self, Color(1.0, 0.55, 0.3), 70, Vector3(60, 4, 60), Vector3(0, 3, 0), 0.25)
	ash.lifetime = 5.0
	ash.gravity = Vector3(0.3, -0.1, 0.1)


func _spawn_enemies() -> void:
	# chapel: hollowed sentinels (quest targets)
	add_pack("hollow_sentinel", 4, Vector3(0, 0, -1), 5.0, 1)
	add_pack("hollow_sentinel", 2, Vector3(-12, 0, 16), 3.0, 1)
	# road
	add_pack("gloomfang", 3, Vector3(14, 0, 18), 3.0, 1)
	# forest
	add_pack("gloomfang", 3, Vector3(-36, 0, -8), 4.0, 2)
	add_pack("gloomfang", 3, Vector3(-48, 0, 14), 4.0, 2)
	add_pack("hollow_sentinel", 2, Vector3(-40, 0, 0), 3.0, 2)
	# cultist camp
	add_pack("ashen_cultist", 3, Vector3(-30, 0, -38), 6.0, 2)
	add_pack("hollow_sentinel", 2, Vector3(-24, 0, -32), 3.0, 2)
	# shrine
	add_pack("ashen_cultist", 2, Vector3(44, 0, 4), 6.0, 2)
	add_enemy("veilstalker", 2, Vector3(38, 0, -10))
	# north road + gate guardians
	add_enemy("veilstalker", 3, Vector3(18, 0, -26))
	add_enemy("veilstalker", 3, Vector3(26, 0, -30))
	add_enemy("cinder_colossus", 3, ENTRANCE + Vector3(0, 0, 10))
	add_pack("ashen_cultist", 2, ENTRANCE + Vector3(-8, 0, 8), 3.0, 3)


func _physics_process(delta: float) -> void:
	# Soft-lock guard: if the hunt quest still needs Hollowed but none are
	# left alive in the Vale, new ones crawl out of the chapel ruins.
	_reinforce_cd -= delta
	if _reinforce_cd > 0.0 or Game.character == null:
		return
	_reinforce_cd = 5.0
	if Game.quests.state("q_ashen_toll") != QuestLog.ACTIVE:
		return
	if Game.quests.objective_count("q_ashen_toll", "kill_hollow") >= 5:
		return
	var alive := 0
	for e in alive_enemies():
		if "hollow" in e.tags:
			alive += 1
	if alive == 0:
		var pack := add_pack("hollow_sentinel", 3, Vector3(0, 0, -2), 4.0, maxi(1, Game.character.level - 1))
		for e in pack:
			e._ready()
		Events.notify.emit("More Hollowed rise from the chapel ruins...", Color(0.75, 0.65, 1.0))
