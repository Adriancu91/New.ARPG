class_name WardingBrazier
extends Interactable
## Quest object: light it to weaken the darkness before the boss.

const K = preload("res://game/characters/model_kit.gd")

var lit := false
var _fire: Node3D
var _light: OmniLight3D


static func create(id: String) -> WardingBrazier:
	var b := WardingBrazier.new()
	b.object_id = id
	b.prompt = "Light the Warding Brazier"
	var iron := K.mat(Color("#3a3430"), 0.0, 0.5, 0.8)
	K.part(b, K.cyl(0.25, 0.35, 0.2), iron, Vector3(0, 0.1, 0))
	K.part(b, K.cyl(0.08, 0.1, 1.0), iron, Vector3(0, 0.6, 0))
	K.part(b, K.cyl(0.6, 0.35, 0.35, 12), iron, Vector3(0, 1.25, 0))
	b._fire = Node3D.new()
	b._fire.position = Vector3(0, 1.45, 0)
	b.add_child(b._fire)
	K.part(b._fire, K.sphere(0.35), K.glow_mat(Color(1.0, 0.75, 0.3), 4.0, 0.9), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.4, 1), false)
	K.embers(b._fire, Color(1.0, 0.7, 0.3), 24, Vector3(0.3, 0.2, 0.3), Vector3.ZERO, 1.4)
	b._light = K.light(b, Color(1.0, 0.75, 0.4), 4.0, 14.0, Vector3(0, 2.0, 0), true)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 1.6
	cs.shape = shape
	cs.position.y = 0.8
	col.add_child(cs)
	b.add_child(col)
	return b


func _ready() -> void:
	super._ready()
	_set_lit(Game.world_list_has("interacted", object_id))


func _set_lit(v: bool) -> void:
	lit = v
	_fire.visible = v
	_light.visible = v


func can_interact() -> bool:
	return not lit


func interact(player) -> void:
	if lit:
		return
	_set_lit(true)
	Audio.play("spell_fire")
	VFX.ring(self, global_position, 6.0, Color(1, 0.8, 0.4), 0.8)
	Events.notify.emit("The Warding Brazier blazes. The darkness recoils.", Color(1.0, 0.8, 0.4))
	super.interact(player)
