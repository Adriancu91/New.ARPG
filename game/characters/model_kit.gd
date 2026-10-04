class_name ModelKit
extends RefCounted
## Tiny procedural-modeling kit used for PLACEHOLDER characters, monsters and
## props. Every model is assembled from primitive meshes with per-instance
## materials so hit flashes stay local. Replace with authored assets later.

static var _mesh_cache: Dictionary = {}


static func mat(color: Color, emission: float = 0.0, roughness: float = 0.7, metallic: float = 0.0, emission_color = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = emission_color if emission_color != null else color
		m.emission_energy_multiplier = emission
	return m


static func glow_mat(color: Color, energy: float = 2.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _cached(key: String, factory: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = factory.call()
	return _mesh_cache[key]


static func sphere(r: float = 0.5, segments: int = 16) -> Mesh:
	return _cached("s%s_%d" % [r, segments], func():
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segments
		m.rings = segments / 2
		return m)


static func box(size: Vector3) -> Mesh:
	return _cached("b%s" % size, func():
		var m := BoxMesh.new()
		m.size = size
		return m)


static func cyl(top: float, bottom: float, height: float, segments: int = 14) -> Mesh:
	return _cached("c%s_%s_%s_%d" % [top, bottom, height, segments], func():
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		return m)


static func capsule(r: float, h: float) -> Mesh:
	return _cached("k%s_%s" % [r, h], func():
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 14
		m.rings = 6
		return m)


static func torus(inner: float, outer: float) -> Mesh:
	return _cached("t%s_%s" % [inner, outer], func():
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 24
		m.ring_segments = 8
		return m)


static func prism(size: Vector3) -> Mesh:
	return _cached("p%s" % size, func():
		var m := PrismMesh.new()
		m.size = size
		return m)


## Adds a MeshInstance3D. rot is in degrees.
static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	return n


## A segment (capsule/cylinder) hanging DOWN from a pivot, length L.
static func limb(parent: Node3D, r_top: float, r_bot: float, length: float, material: Material, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return part(parent, cyl(r_top, r_bot, length, 10), material, offset + Vector3(0, -length * 0.5, 0))


static func light(parent: Node3D, color: Color, energy: float, range_: float, pos: Vector3 = Vector3.ZERO, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.position = pos
	l.shadow_enabled = shadows
	parent.add_child(l)
	return l


static func embers(parent: Node3D, color: Color, amount: int = 16, extent: Vector3 = Vector3(0.4, 0.6, 0.4), pos: Vector3 = Vector3(0, 1, 0), speed: float = 0.6) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var qm := glow_mat(color, 4.0, 0.99)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	p.mesh = q
	p.position = pos
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	parent.add_child(p)
	return p
