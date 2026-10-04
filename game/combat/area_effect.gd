class_name AreaEffect
extends Node3D
## Telegraphed area attack. Shows a ground marker that fills up during
## `delay`, then damages every opponent inside the circle or cone.
## Also used for traps (triggered when an opponent steps inside).

const K = preload("res://game/characters/model_kit.gd")

var team := "player"
var radius := 3.0
var delay := 0.5
var shape := "circle"           # circle | cone
var cone_angle := 90.0
var forward := Vector3.FORWARD
var make_hit: Callable
var color := Color.WHITE
var is_trap := false
var trap_life := 10.0
var follow: Node3D = null       # optional: stay centered on a node while charging
var _t := 0.0
var _fired := false
var _fill: MeshInstance3D
var _edge: MeshInstance3D
var _fill_mat: StandardMaterial3D
var on_fire: Callable


static func spawn(ctx: Node, pos: Vector3, cfg: Dictionary) -> AreaEffect:
	var a := AreaEffect.new()
	a.team = cfg.get("team", "player")
	a.radius = cfg.get("radius", 3.0)
	a.delay = cfg.get("delay", 0.5)
	a.shape = cfg.get("shape", "circle")
	a.cone_angle = cfg.get("angle", 90.0)
	a.forward = cfg.get("forward", Vector3.FORWARD)
	a.make_hit = cfg.get("make_hit", Callable())
	a.color = cfg.get("color", Color.WHITE)
	a.is_trap = cfg.get("trap", false)
	a.trap_life = cfg.get("trap_life", 10.0)
	a.follow = cfg.get("follow")
	if cfg.has("on_fire"):
		a.on_fire = cfg.on_fire
	WorldHost.get_host(ctx).add_child(a)
	a.global_position = Vector3(pos.x, 0.06, pos.z)
	a._build()
	return a


func _build() -> void:
	_edge = MeshInstance3D.new()
	_fill = MeshInstance3D.new()
	_fill_mat = K.glow_mat(color, 1.5, 0.35)
	var edge_mat := K.glow_mat(color, 2.5, 0.9)
	if shape == "cone":
		_edge.mesh = _cone_mesh(1.0, 0.92)
		_fill.mesh = _cone_mesh(1.0, 0.0)
		rotation.y = atan2(forward.x, forward.z)
	else:
		_edge.mesh = K.torus(0.94, 1.0)
		var d := CylinderMesh.new()
		d.top_radius = 1.0
		d.bottom_radius = 1.0
		d.height = 0.02
		d.radial_segments = 32
		_fill.mesh = d
	_edge.material_override = edge_mat
	_fill.material_override = _fill_mat
	for m in [_edge, _fill]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	_edge.scale = Vector3(radius, 1, radius)
	_fill.scale = Vector3(0.01, 1, 0.01) if not is_trap else Vector3(radius, 1, radius)
	if is_trap:
		_fill_mat.albedo_color.a = 0.18


func _cone_mesh(r: float, inner: float) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var half := deg_to_rad(cone_angle * 0.5)
	var segs := 20
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := -half + 2.0 * half * i / segs
		var a1 := -half + 2.0 * half * (i + 1) / segs
		var o0 := Vector3(sin(a0), 0, cos(a0))
		var o1 := Vector3(sin(a1), 0, cos(a1))
		for v in [o0 * inner, o0 * r, o1 * r, o0 * inner, o1 * r, o1 * inner]:
			im.surface_add_vertex(v)
	im.surface_end()
	return im


func _physics_process(delta: float) -> void:
	if _fired:
		return
	_t += delta
	if follow != null and is_instance_valid(follow):
		global_position = Vector3(follow.global_position.x, 0.06, follow.global_position.z)
	if is_trap:
		_edge.rotation.y += delta
		if _t >= trap_life:
			queue_free()
			return
		if not CombatUtils.in_radius(get_tree(), team, global_position, radius * 0.5).is_empty():
			_fire()
		return
	var k := clampf(_t / maxf(delay, 0.01), 0.0, 1.0)
	_fill.scale = Vector3(radius * k, 1, radius * k)
	_fill_mat.albedo_color.a = 0.2 + 0.35 * k
	if _t >= delay:
		_fire()


func targets() -> Array:
	if shape == "cone":
		return CombatUtils.in_cone(get_tree(), team, global_position, forward, radius, cone_angle)
	return CombatUtils.in_radius(get_tree(), team, global_position, radius)


func _fire() -> void:
	_fired = true
	var hits := targets()
	for c in hits:
		if make_hit.is_valid():
			c.take_hit(make_hit.call(c))
	if on_fire.is_valid():
		on_fire.call(hits)
	if shape == "circle":
		VFX.ring(self, global_position, radius, color, 0.4)
		VFX.pillar(self, global_position, radius * 0.5, 2.5, color, 0.4)
	VFX.flash(self, global_position, color, 3.0, radius * 2.0)
	var tw := create_tween()
	tw.tween_property(_fill_mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
