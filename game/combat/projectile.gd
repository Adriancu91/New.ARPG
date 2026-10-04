class_name Projectile
extends Node3D
## Straight-flying projectile for both teams. Hit detection is a swept
## distance test against opponents; walls stop it via a ray query.

const K = preload("res://game/characters/model_kit.gd")

var team := "player"
var direction := Vector3.FORWARD
var speed := 20.0
var max_distance := 20.0
var pierce := 0
var radius := 0.35
var explode_radius := 0.0
var make_hit: Callable          # func(target) -> Damage.Hit
var on_hit_fx: Color = Color.WHITE
var _travelled := 0.0
var _hit_ids: Dictionary = {}
var _done := false
var source: Node = null


static func spawn(ctx: Node, from: Vector3, dir: Vector3, cfg: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.team = cfg.get("team", "player")
	p.speed = cfg.get("speed", 20.0)
	p.max_distance = cfg.get("range", 20.0)
	p.pierce = cfg.get("pierce", 0)
	p.explode_radius = cfg.get("explode_radius", 0.0)
	p.radius = cfg.get("radius", 0.35)
	p.make_hit = cfg.get("make_hit", Callable())
	p.source = cfg.get("source")
	var color: Color = cfg.get("color", Color.WHITE)
	p.on_hit_fx = color
	p.direction = Vector3(dir.x, 0, dir.z).normalized()
	if p.direction == Vector3.ZERO:
		p.direction = Vector3.FORWARD
	var size: float = cfg.get("size", 0.18)
	var core := MeshInstance3D.new()
	core.mesh = K.sphere(size)
	core.material_override = K.glow_mat(color, 4.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(core)
	if cfg.get("arrow", false):
		core.scale = Vector3(0.35, 0.35, 3.5)
	var trail := MeshInstance3D.new()
	trail.mesh = K.cyl(size * 0.2, size * 0.8, 1.2, 8)
	trail.material_override = K.glow_mat(color, 2.0, 0.45)
	trail.rotation_degrees = Vector3(-90, 0, 0)
	trail.position = Vector3(0, 0, 0.7)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(trail)
	if cfg.get("light", true):
		K.light(p, color, 1.2, 3.0)
	WorldHost.get_host(ctx).add_child(p)
	p.global_position = from
	p.look_at(from + p.direction, Vector3.UP)
	return p


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := speed * delta
	var from := global_position
	var to := from + direction * step
	# world collision
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var wall := space.intersect_ray(q)
	if not wall.is_empty():
		global_position = wall.position
		_finish()
		return
	for c in CombatUtils.opponents(get_tree(), team):
		if _hit_ids.has(c.get_instance_id()):
			continue
		var hr: float = c.get_meta("hit_radius", 0.4)
		var target_pos: Vector3 = c.global_position
		if CombatUtils.segment_distance(target_pos, from, to) <= radius + hr:
			_hit_ids[c.get_instance_id()] = true
			if explode_radius > 0.0:
				global_position = Vector3(target_pos.x, from.y, target_pos.z)
				_finish()
				return
			if make_hit.is_valid():
				c.take_hit(make_hit.call(c))
			VFX.burst(self, c.global_position, on_hit_fx, 8, 3.0)
			if pierce <= 0:
				_done = true
				queue_free()
				return
			pierce -= 1
	global_position = to
	_travelled += step
	if _travelled >= max_distance:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if explode_radius > 0.0:
		VFX.ring(self, global_position - Vector3(0, global_position.y, 0), explode_radius, on_hit_fx)
		VFX.flash(self, global_position, on_hit_fx, 4.0, explode_radius * 2.5)
		Audio.play("explosion")
		for c in CombatUtils.in_radius(get_tree(), team, global_position, explode_radius):
			if make_hit.is_valid():
				c.take_hit(make_hit.call(c))
	queue_free()
