class_name TreasureChest
extends Interactable
## Persistent treasure chest. Opened state is stored in world progression.

const K = preload("res://game/characters/model_kit.gd")

var chest_level := 1
var guaranteed: Array = []      # stack specs always inside, e.g. ["lamp_fragment:1"]
var lid: Node3D
var opened := false


static func create(id: String, lvl: int, extra: Array = []) -> TreasureChest:
	var c := TreasureChest.new()
	c.object_id = id
	c.chest_level = lvl
	c.guaranteed = extra
	c.prompt = "Open chest"
	c._build()
	return c


func _build() -> void:
	var wood := K.mat(Color("#4a2f1c"), 0.0, 0.8)
	var iron := K.mat(Color("#8a7a5a"), 0.1, 0.35, 0.9)
	K.part(self, K.box(Vector3(1.0, 0.55, 0.65)), wood, Vector3(0, 0.28, 0))
	K.part(self, K.box(Vector3(1.04, 0.06, 0.69)), iron, Vector3(0, 0.5, 0))
	for x in [-0.4, 0.4]:
		K.part(self, K.box(Vector3(0.06, 0.58, 0.69)), iron, Vector3(x, 0.29, 0))
	lid = K.pivot(self, "Lid", Vector3(0, 0.55, -0.32))
	K.part(lid, K.box(Vector3(1.0, 0.22, 0.65)), wood, Vector3(0, 0.11, 0.32))
	K.part(lid, K.box(Vector3(0.12, 0.14, 0.04)), K.glow_mat(Color(1, 0.8, 0.4), 1.5), Vector3(0, 0.05, 0.66))
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 0.8, 0.65)
	cs.shape = bs
	cs.position.y = 0.4
	col.add_child(cs)
	add_child(col)
	K.light(self, Color(1.0, 0.75, 0.35), 0.6, 3.0, Vector3(0, 1.0, 0.6))


func _ready() -> void:
	super._ready()
	if Game.world_list_has("opened_chests", object_id):
		_set_open(true)


func can_interact() -> bool:
	return not opened


func _set_open(instant: bool) -> void:
	opened = true
	if instant:
		lid.rotation_degrees.x = -110
	else:
		create_tween().tween_property(lid, "rotation_degrees:x", -110.0, 0.4).set_trans(Tween.TRANS_BACK)
	for c in get_children():
		if c is OmniLight3D:
			c.visible = false


func interact(player) -> void:
	if opened:
		return
	_set_open(false)
	Game.world_list_add("opened_chests", object_id)
	Audio.play("chest")
	var loot := LootTable.roll_chest(chest_level, Game.rng, Game.loot_context())
	for spec in guaranteed:
		var parts: PackedStringArray = spec.split(":")
		loot.items.append(Item.make_stack(parts[0], int(parts[1]) if parts.size() > 1 else 1))
	LootPickup.drop_bundle(self, global_position + Vector3(0, 0.5, 0) + global_transform.basis.z * 0.9, loot, false, "chest:" + object_id)
	super.interact(player)
