class_name ZoneGate
extends Interactable
## Doorway to another zone. Optionally sealed until a world flag is set.

const K = preload("res://game/characters/model_kit.gd")

var target_zone := ""
var target_spawn := "start"
var required_flag := ""
var sealed_text := "It is sealed."
var _seal: MeshInstance3D
var _glow: MeshInstance3D


static func create(id: String, zone: String, spawn: String, label: String, flag: String = "", sealed_msg: String = "") -> ZoneGate:
	var g := ZoneGate.new()
	g.object_id = id
	g.target_zone = zone
	g.target_spawn = spawn
	g.required_flag = flag
	g.prompt = label
	if sealed_msg != "":
		g.sealed_text = sealed_msg
	var stone := K.mat(Color("#4a4650"), 0.0, 0.9)
	var gold := K.mat(Color("#8a6d3b"), 0.2, 0.3, 0.9)
	for x in [-1.6, 1.6]:
		K.part(g, K.box(Vector3(0.7, 4.0, 0.9)), stone, Vector3(x, 2.0, 0))
		K.part(g, K.box(Vector3(0.9, 0.3, 1.1)), gold, Vector3(x, 4.1, 0))
	K.part(g, K.box(Vector3(4.2, 0.7, 1.0)), stone, Vector3(0, 4.45, 0))
	K.part(g, K.prism(Vector3(1.6, 0.9, 0.9)), stone, Vector3(0, 5.25, 0))
	g._glow = K.part(g, K.box(Vector3(2.5, 3.8, 0.1)), K.glow_mat(Color(0.5, 0.75, 1.0), 1.6, 0.55), Vector3(0, 1.9, 0), Vector3.ZERO, Vector3.ONE, false)
	g._seal = K.part(g, K.box(Vector3(2.5, 3.8, 0.3)), K.mat(Color("#2a2228"), 0.0, 0.9, 0.2), Vector3(0, 1.9, 0))
	K.part(g._seal, K.torus(0.5, 0.65), K.glow_mat(Color(0.8, 0.2, 0.3), 2.0), Vector3(0, 0.3, 0.17), Vector3(90, 0, 0), Vector3.ONE, false)
	for x in [-1.6, 1.6]:
		var col := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.7, 4.0, 0.9)
		cs.shape = bs
		cs.position = Vector3(x, 2.0, 0)
		col.add_child(cs)
		g.add_child(col)
	K.light(g, Color(0.5, 0.7, 1.0), 1.5, 7.0, Vector3(0, 2.5, 1.5))
	return g


func is_open() -> bool:
	return required_flag == "" or Game.flag(required_flag)


func _process(_d: float) -> void:
	if _seal:
		_seal.visible = not is_open()
		_glow.visible = is_open()


func get_prompt() -> String:
	return prompt if is_open() else "Sealed"


func interact(player) -> void:
	if not is_open():
		Events.notify.emit(sealed_text, Color(0.9, 0.5, 0.5))
		return
	Audio.play("door")
	super.interact(player)
	Game.request_zone(target_zone, target_spawn)
