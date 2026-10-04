class_name NPC
extends Interactable
## Data-driven NPC (data/npcs.json): branching dialogue with quest
## conditions/actions and optional merchant stock.

const K = preload("res://game/characters/model_kit.gd")

var npc_id := ""
var def: Dictionary = {}
var stock: Array = []           # Array[Item] for sale
var _marker: Label3D
var rig


static func create(id: String) -> NPC:
	var n := NPC.new()
	n.npc_id = id
	n.object_id = id
	n.def = DB.get_npc(id)
	n.prompt = "Talk to " + n.def.get("name", "?")
	n._build_model()
	return n


func _build_model() -> void:
	rig = HumanoidRig.new()
	rig.build_skeleton(0.92, 0.2, 1.4, 0.1)
	rig.hunch = 0.18
	var robe := K.mat(Color("#3b3a46"), 0.0, 0.95)
	var skin := K.mat(Color("#cfae94"), 0.0, 0.6)
	var beard := K.mat(Color("#d8d4cc"), 0.0, 0.8)
	K.part(rig.hips, K.cyl(0.2, 0.36, 0.95, 12), robe, Vector3(0, -0.45, 0))
	K.part(rig.torso, K.cyl(0.22, 0.2, 0.55), robe, Vector3(0, 0.27, 0))
	K.part(rig.torso, K.box(Vector3(0.12, 0.8, 0.02)), K.mat(Color("#8a6d3b"), 0.1, 0.4, 0.8), Vector3(0, 0.1, 0.21))
	for arm in [rig.arm_l, rig.arm_r]:
		K.limb(arm, 0.07, 0.09, 0.55, robe)
		K.part(arm, K.sphere(0.05), skin, Vector3(0, -0.58, 0))
	K.part(rig.head, K.sphere(0.11), skin, Vector3(0, 0.06, 0))
	K.part(rig.head, K.prism(Vector3(0.16, 0.2, 0.08)), beard, Vector3(0, -0.06, 0.07), Vector3(180, 0, 0))
	K.part(rig.head, K.cyl(0.0, 0.16, 0.25, 10), robe, Vector3(0, 0.15, -0.03), Vector3(-15, 0, 0))
	# lantern on a staff
	K.part(rig.hand_r, K.cyl(0.02, 0.02, 1.9), K.mat(Color("#4a3322")), Vector3(0, 0.45, 0.05))
	var lantern := K.pivot(rig.hand_r, "Lantern", Vector3(0, 1.45, 0.25))
	K.part(lantern, K.box(Vector3(0.16, 0.22, 0.16)), K.glow_mat(Color(1.0, 0.8, 0.4), 3.0, 0.9))
	K.light(lantern, Color(1.0, 0.75, 0.4), 2.5, 9.0, Vector3.ZERO, true)
	var vis := Node3D.new()
	vis.rotation_degrees.y = 180
	add_child(vis)
	vis.add_child(rig)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	cs.shape = shape
	cs.position.y = 0.9
	col.add_child(cs)
	add_child(col)
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.font_size = 96
	_marker.pixel_size = 0.006
	_marker.outline_size = 12
	_marker.position.y = 2.6
	_marker.no_depth_test = true
	add_child(_marker)
	var name_lbl := Label3D.new()
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.font_size = 34
	name_lbl.pixel_size = 0.005
	name_lbl.outline_size = 8
	name_lbl.modulate = Color(0.95, 0.85, 0.6)
	name_lbl.text = "%s\n%s" % [def.get("name", ""), def.get("title", "")]
	name_lbl.position.y = 2.15
	name_lbl.no_depth_test = true
	add_child(name_lbl)


func _process(_d: float) -> void:
	if Game.character == null:
		return
	# "!" = quest available, "?" = ready to turn in
	var m := ""
	for qid in DB.quests:
		var q := DB.get_quest(qid)
		if q.get("turn_in", "") == npc_id and Game.quests.state(qid) == QuestLog.READY:
			m = "?"
			break
		if q.get("giver", "") == npc_id and Game.quests.state(qid) == QuestLog.AVAILABLE and _quest_unlocked(qid):
			m = "!"
	_marker.text = m
	_marker.modulate = Color(1.0, 0.85, 0.2) if m == "!" else Color(0.5, 1.0, 0.5)
	# face the player when close
	var p: Node3D = Game.player
	if p and is_instance_valid(p) and global_position.distance_to(p.global_position) < 6.0:
		var dir := p.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.1)


func _quest_unlocked(qid: String) -> bool:
	# A quest that is another quest's "next" unlocks when that quest completes.
	for other in DB.quests:
		if DB.get_quest(other).get("next", "") == qid:
			return Game.quests.state(other) == QuestLog.COMPLETED
	return true


func interact(player) -> void:
	super.interact(player)
	Audio.play("ui_open")
	Events.dialogue_requested.emit(self)


# ---------------------------------------------------------------- dialogue

func check_condition(cond: String) -> bool:
	var parts := cond.split(":")
	if parts.size() < 2:
		return true
	var qid := parts[1]
	var st := Game.quests.state(qid)
	match parts[0]:
		"quest_available": return st == QuestLog.AVAILABLE and _quest_unlocked(qid)
		"quest_active": return st == QuestLog.ACTIVE
		"quest_ready": return st == QuestLog.READY
		"quest_completed": return st == QuestLog.COMPLETED
		"flag": return Game.flag(qid)
	return false


func start_node() -> String:
	for rule in def.dialogue.start:
		if not rule.has("if") or check_condition(rule["if"]):
			return rule["goto"]
	return "idle"


func node(node_id: String) -> Dictionary:
	return def.dialogue.nodes.get(node_id, {"text": "...", "options": [{"text": "Farewell.", "action": "close"}]})


## Executes an option action. Returns the next node id, "" to close,
## or "trade" to open the merchant screen.
func run_option(opt: Dictionary) -> String:
	if opt.has("goto"):
		return opt["goto"]
	var action: String = opt.get("action", "close")
	var parts := action.split(":")
	match parts[0]:
		"accept":
			Game.accept_quest(parts[1])
			return ""
		"complete":
			Game.complete_quest(parts[1])
			return start_node()
		"trade":
			return "trade"
	return ""


# ---------------------------------------------------------------- merchant

func ensure_stock() -> void:
	if not stock.is_empty() or Game.character == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in int(def.get("stock_random", 3)):
		var it := ItemGenerator.generate(rng, Game.character.level + 1, ItemGenerator.roll_rarity(rng, "uncommon", 0.3), Game.character.class_data().weapon_type)
		if it:
			stock.append(it)


static func price_of(it: Item) -> int:
	if it.is_stackable():
		return int(DB.stackable_def(it.base_id).get("price", 5))
	var mult: float = DB.rarity(it.rarity).power
	return maxi(5, int(round(it.power_score() * 1.8 * mult)))


static func sell_price(it: Item) -> int:
	return maxi(1, int(price_of(it) * 0.25)) * maxi(1, it.count)


func buy_potion() -> bool:
	var price := int(DB.stackable_def("potion_health").price)
	if Game.character.gold < price:
		return false
	if not Game.character.inventory.add(Item.make_stack("potion_health", 1)):
		return false
	Game.add_gold(-price)
	return true


func buy(it: Item) -> bool:
	var price := price_of(it)
	if Game.character.gold < price or Game.character.inventory.is_full():
		return false
	stock.erase(it)
	Game.character.inventory.add(it)
	Game.add_gold(-price)
	return true


func sell(it: Item) -> bool:
	if it.kind == "quest_items":
		return false
	var got := Game.character.inventory.remove(it.uid)
	if got == null:
		return false
	Game.add_gold(sell_price(got))
	return true
