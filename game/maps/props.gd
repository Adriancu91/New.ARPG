class_name Props
extends RefCounted
## PLACEHOLDER environment props built from primitives: ruins, trees, rocks,
## torches, statues. All collision is simple boxes/cylinders on layer 1.

const K = preload("res://game/characters/model_kit.gd")

static var STONE := Color("#55525c")
static var STONE_DARK := Color("#3a3840")
static var _mats: Dictionary = {}


## Shared materials for static props (they never flash, so sharing is fine).
static func m(key: String, color: Color, emission: float = 0.0, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		_mats[key] = K.mat(color, emission, rough, metal)
	return _mats[key]


static func collider_box(parent: Node3D, size: Vector3, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)
	body.position = pos
	body.rotation.y = rot_y
	return body


static func collider_cyl(parent: Node3D, r: float, h: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.position = pos + Vector3(0, h * 0.5, 0)
	return body


static func wall(parent: Node3D, from: Vector3, to: Vector3, height: float = 3.0, thick: float = 0.8, ruined: bool = true, mat_key: String = "stone") -> void:
	var mid := (from + to) * 0.5
	var d := to - from
	var length := Vector2(d.x, d.z).length()
	var yaw := atan2(d.x, d.z)
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = mid
	holder.rotation.y = yaw
	var mat := m(mat_key, STONE if mat_key == "stone" else STONE_DARK)
	if ruined:
		# uneven top: several blocks of varying height
		var segs := maxi(1, int(length / 1.6))
		var seglen := length / segs
		for i in segs:
			var h := height * (0.45 + 0.55 * absf(sin(i * 2.17 + from.x)))
			K.part(holder, K.box(Vector3(thick, h, seglen * 1.02)), mat, Vector3(0, h * 0.5, -length * 0.5 + seglen * (i + 0.5)))
	else:
		K.part(holder, K.box(Vector3(thick, height, length)), mat, Vector3(0, height * 0.5, 0))
	collider_box(parent, Vector3(thick, height, length), mid + Vector3(0, height * 0.5, 0), yaw)


static func pillar(parent: Node3D, pos: Vector3, height: float = 4.0, broken: bool = false) -> void:
	var p := Node3D.new()
	parent.add_child(p)
	p.position = pos
	var h := height * (0.45 if broken else 1.0)
	K.part(p, K.box(Vector3(1.0, 0.3, 1.0)), m("stone_dark", STONE_DARK), Vector3(0, 0.15, 0))
	K.part(p, K.cyl(0.32, 0.36, h, 10), m("stone", STONE), Vector3(0, 0.3 + h * 0.5, 0))
	if not broken:
		K.part(p, K.box(Vector3(0.9, 0.3, 0.9)), m("stone_dark", STONE_DARK), Vector3(0, 0.3 + h + 0.15, 0))
	else:
		K.part(p, K.cyl(0.32, 0.34, 1.2, 10), m("stone", STONE), Vector3(1.0, 0.32, 0.4), Vector3(0, 30, 88))
	collider_cyl(parent, 0.45, h + 0.3, pos)


static func arch(parent: Node3D, pos: Vector3, yaw_deg: float = 0.0, width: float = 4.0) -> void:
	var a := Node3D.new()
	parent.add_child(a)
	a.position = pos
	a.rotation_degrees.y = yaw_deg
	for x in [-width * 0.5, width * 0.5]:
		K.part(a, K.box(Vector3(0.8, 4.5, 0.8)), m("stone", STONE), Vector3(x, 2.25, 0))
	K.part(a, K.box(Vector3(width + 0.8, 0.7, 0.9)), m("stone_dark", STONE_DARK), Vector3(0, 4.8, 0))
	K.part(a, K.prism(Vector3(1.2, 0.8, 0.9)), m("stone", STONE), Vector3(0, 5.55, 0))
	var basis_ := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	for x in [-width * 0.5, width * 0.5]:
		collider_box(parent, Vector3(0.8, 4.5, 0.8), pos + basis_ * Vector3(x, 2.25, 0), deg_to_rad(yaw_deg))


static func dead_tree(parent: Node3D, pos: Vector3, scale_: float = 1.0, seed_: int = 0) -> void:
	var t := Node3D.new()
	parent.add_child(t)
	t.position = pos
	t.scale = Vector3.ONE * scale_
	t.rotation.y = seed_ * 1.37
	var bark := m("bark", Color("#2c2420"))
	K.part(t, K.cyl(0.12, 0.3, 4.0, 8), bark, Vector3(0, 2.0, 0), Vector3(0, 0, 4))
	for i in 5:
		var a := i * 1.3 + seed_
		var h := 2.0 + i * 0.45
		var branch := K.part(t, K.cyl(0.02, 0.09, 1.8 - i * 0.15, 6), bark, Vector3(0, h, 0), Vector3(55 + i * 4, rad_to_deg(a), 0))
		branch.position += Vector3(sin(a), 0.5, cos(a)) * 0.5
	collider_cyl(parent, 0.35 * scale_, 3.0, pos)


static func corrupted_tree(parent: Node3D, pos: Vector3, scale_: float = 1.0, seed_: int = 0) -> void:
	dead_tree(parent, pos, scale_, seed_)
	var glow := Node3D.new()
	parent.add_child(glow)
	glow.position = pos
	K.part(glow, K.sphere(0.25), K.glow_mat(Color(0.6, 0.25, 0.9), 2.5, 0.8), Vector3(0, 1.4 * scale_, 0.2), Vector3.ZERO, Vector3(0.6, 1, 0.4), false)


static func rock(parent: Node3D, pos: Vector3, size: float = 1.0, seed_: int = 0) -> void:
	var r := K.part(parent, K.sphere(0.8, 8), m("rock", Color("#4a4642")), pos + Vector3(0, size * 0.35, 0),
		Vector3(seed_ * 23 % 40, seed_ * 57 % 360, 0), Vector3(1.3, 0.75, 1.0) * size)
	r.name = "Rock"
	collider_cyl(parent, 0.8 * size, size * 1.0, pos)


static func torch(parent: Node3D, pos: Vector3, color: Color = Color(1.0, 0.6, 0.25), energy: float = 2.0, shadows: bool = false) -> OmniLight3D:
	var t := Node3D.new()
	parent.add_child(t)
	t.position = pos
	K.part(t, K.cyl(0.05, 0.07, 1.8, 6), m("iron", Color("#2a2622"), 0.0, 0.6, 0.7), Vector3(0, 0.9, 0))
	K.part(t, K.cyl(0.18, 0.08, 0.2, 8), m("iron", Color("#2a2622"), 0.0, 0.6, 0.7), Vector3(0, 1.85, 0))
	K.part(t, K.sphere(0.13), K.glow_mat(color, 4.0, 0.95), Vector3(0, 2.02, 0), Vector3.ZERO, Vector3(1, 1.5, 1), false)
	K.embers(t, color, 6, Vector3(0.08, 0.05, 0.08), Vector3(0, 2.1, 0), 0.8)
	return flicker(t, color, energy, 9.0, Vector3(0, 2.3, 0), shadows)


static func flicker(parent: Node3D, color: Color, energy: float, range_: float, pos: Vector3, shadows: bool = false) -> OmniLight3D:
	var l := FlickerLight.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.position = pos
	l.shadow_enabled = shadows
	parent.add_child(l)
	return l


static func statue_broken_saint(parent: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	parent.add_child(s)
	s.position = pos
	var marble := m("marble", Color("#b9b4aa"), 0.0, 0.6)
	K.part(s, K.box(Vector3(3.0, 1.0, 3.0)), m("stone_dark", STONE_DARK), Vector3(0, 0.5, 0))
	K.part(s, K.box(Vector3(2.2, 0.6, 2.2)), m("stone", STONE), Vector3(0, 1.3, 0))
	# kneeling robed figure, head fallen beside the plinth
	K.part(s, K.cyl(0.4, 0.75, 1.6, 12), marble, Vector3(0, 2.4, 0))
	K.part(s, K.cyl(0.35, 0.42, 1.0, 12), marble, Vector3(0, 3.6, 0))
	for sx in [-1.0, 1.0]:
		K.part(s, K.box(Vector3(0.14, 1.6, 0.6)), marble, Vector3(0.45 * sx, 3.9, -0.4), Vector3(-20, 0, 25 * sx))
	K.part(s, K.sphere(0.32), marble, Vector3(1.9, 0.3, 1.2))
	K.part(s, K.torus(0.4, 0.48), K.glow_mat(Color(1.0, 0.85, 0.5), 1.2, 0.6), Vector3(0, 4.6, -0.2), Vector3(90, 0, 0), Vector3.ONE, false)
	K.light(s, Color(1.0, 0.85, 0.6), 2.0, 10.0, Vector3(0, 5, 2), true)
	collider_box(parent, Vector3(3.0, 4.5, 3.0), pos + Vector3(0, 2.25, 0))


static func campfire(parent: Node3D, pos: Vector3) -> void:
	var c := Node3D.new()
	parent.add_child(c)
	c.position = pos
	for i in 8:
		var a := i * TAU / 8.0
		K.part(c, K.sphere(0.18, 8), m("rock", Color("#4a4642")), Vector3(cos(a), 0.1, sin(a)) * 0.7)
	for i in 3:
		K.part(c, K.cyl(0.07, 0.07, 1.0, 6), m("bark", Color("#2c2420")), Vector3(0, 0.15, 0), Vector3(80, i * 60, 0))
	K.part(c, K.sphere(0.3), K.glow_mat(Color(1.0, 0.55, 0.2), 4.0, 0.85), Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(1, 1.6, 1), false)
	K.embers(c, Color(1.0, 0.6, 0.25), 20, Vector3(0.3, 0.1, 0.3), Vector3(0, 0.5, 0), 1.6)
	flicker(c, Color(1.0, 0.6, 0.3), 3.0, 12.0, Vector3(0, 1.2, 0), true)


static func tent(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var t := Node3D.new()
	parent.add_child(t)
	t.position = pos
	t.rotation_degrees.y = yaw
	K.part(t, K.prism(Vector3(3.0, 2.2, 3.4)), m("canvas", Color("#4e4636")), Vector3(0, 1.1, 0), Vector3(0, 0, 0))
	collider_box(parent, Vector3(3.0, 2.0, 3.4), pos + Vector3(0, 1.0, 0), deg_to_rad(yaw))


static func banner(parent: Node3D, pos: Vector3, color: Color) -> void:
	var b := Node3D.new()
	parent.add_child(b)
	b.position = pos
	K.part(b, K.cyl(0.05, 0.05, 4.0, 6), m("bark", Color("#2c2420")), Vector3(0, 2.0, 0))
	K.part(b, K.box(Vector3(0.9, 1.8, 0.03)), K.mat(color, 0.1, 0.9), Vector3(0.45, 3.0, 0), Vector3(0, 0, -4))


static func bones(parent: Node3D, pos: Vector3, seed_: int) -> void:
	var bone := m("bone", Color("#bdb5a0"), 0.0, 0.7)
	for i in 4:
		var a := seed_ * 0.7 + i * 1.9
		K.part(parent, K.cyl(0.04, 0.05, 0.6, 6), bone, pos + Vector3(cos(a), 0.05, sin(a)) * 0.4, Vector3(90, rad_to_deg(a) * 3.0, 0))
	K.part(parent, K.sphere(0.14, 10), bone, pos + Vector3(0.2, 0.12, -0.1))


## Scatter decorative rocks/tufts in one draw call.
static func scatter(parent: Node3D, mesh: Mesh, mat: Material, count: int, area: Rect2, rng: RandomNumberGenerator, avoid: Array = [], scale_range := Vector2(0.6, 1.4)) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var transforms: Array = []
	var tries := 0
	while transforms.size() < count and tries < count * 4:
		tries += 1
		var p := Vector3(rng.randf_range(area.position.x, area.end.x), 0, rng.randf_range(area.position.y, area.end.y))
		var ok := true
		for a in avoid:
			if Vector2(p.x, p.z).distance_to(Vector2(a.x, a.z)) < a.y:
				ok = false
				break
		if not ok:
			continue
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.3), s))
		transforms.append(Transform3D(b, p))
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
