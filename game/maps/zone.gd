class_name Zone
extends Node3D
## Base class for a playable region. Subclasses build geometry, enemies and
## interactables in build(). New regions = new Zone subclasses registered in
## ZoneRegistry; nothing else needs to change.

const K = preload("res://game/characters/model_kit.gd")

var zone_id := ""
var display_name := ""
var music := ""
var ambience := ""
var spawns: Dictionary = {}          # spawn_id -> Vector3
var bounds := Rect2(-80, -80, 160, 160)
var points_of_interest: Array = []   # [{pos: Vector3, kind: String, label: String}]
var enemy_root: Node3D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = hash(zone_id)
	enemy_root = Node3D.new()
	enemy_root.name = "Enemies"
	add_child(enemy_root)
	build()


func build() -> void:
	pass


func spawn_point(id: String) -> Vector3:
	return spawns.get(id, spawns.get("start", Vector3.ZERO))


func add_enemy(enemy_id: String, lvl: int, pos: Vector3) -> Enemy:
	var e := Enemy.create(enemy_id, lvl)
	enemy_root.add_child(e)
	e.global_position = pos
	e.home = pos
	e.rotation.y = rng.randf() * TAU
	return e


func add_pack(enemy_id: String, count: int, center: Vector3, radius: float, lvl: int) -> Array:
	var out: Array = []
	for i in count:
		var a := TAU * float(i) / float(count) + rng.randf() * 0.5
		var p := center + Vector3(cos(a), 0, sin(a)) * radius * rng.randf_range(0.4, 1.0)
		out.append(add_enemy(enemy_id, lvl, p))
	return out


func poi(pos: Vector3, kind: String, label: String = "") -> void:
	points_of_interest.append({"pos": pos, "kind": kind, "label": label})


func alive_enemies() -> Array:
	var out: Array = []
	for e in enemy_root.get_children():
		if e is Enemy and e.is_alive():
			out.append(e)
	return out


# ------------------------------------------------------------ environment

func make_environment(kind: String) -> void:
	var env := Environment.new()
	var we := WorldEnvironment.new()
	we.environment = env
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	if kind == "outdoor":
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color(0.05, 0.05, 0.1)
		sm.sky_horizon_color = Color(0.22, 0.16, 0.22)
		sm.ground_horizon_color = Color(0.12, 0.09, 0.1)
		sm.ground_bottom_color = Color(0.02, 0.02, 0.03)
		sm.sun_angle_max = 10.0
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.32, 0.3, 0.42)
		env.ambient_light_energy = 0.55
		env.fog_light_color = Color(0.2, 0.17, 0.24)
		env.fog_density = 0.011
		env.fog_sky_affect = 0.6
		env.ssao_enabled = true
		var moon := DirectionalLight3D.new()
		moon.light_color = Color(0.7, 0.72, 0.95)
		moon.light_energy = 0.9
		moon.rotation_degrees = Vector3(-52, -35, 0)
		moon.shadow_enabled = true
		moon.directional_shadow_max_distance = 60.0
		add_child(moon)
		var rim := DirectionalLight3D.new()
		rim.light_color = Color(0.95, 0.5, 0.35)
		rim.light_energy = 0.25
		rim.rotation_degrees = Vector3(-20, 150, 0)
		add_child(rim)
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.01, 0.01, 0.015)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.25, 0.22, 0.32)
		env.ambient_light_energy = 0.55
		env.fog_light_color = Color(0.06, 0.05, 0.08)
		env.fog_density = 0.02
		env.ssao_enabled = true
		var key := DirectionalLight3D.new()
		key.light_color = Color(0.5, 0.45, 0.7)
		key.light_energy = 0.3
		key.rotation_degrees = Vector3(-60, 20, 0)
		add_child(key)
	add_child(we)


func make_ground(size: Vector2, base: Color, variation: Color, center := Vector3.ZERO, tex_scale: float = 0.08) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _ground_texture(base, variation)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * tex_scale
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = center
	add_child(mi)
	Props.collider_box(self, Vector3(size.x, 1.0, size.y), center + Vector3(0, -0.5, 0))


func _ground_texture(base: Color, variation: Color) -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = hash(zone_id)
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var fine := (noise.get_noise_2d(x * 7.0, y * 7.0) + 1.0) * 0.5
			img.set_pixel(x, y, base.lerp(variation, clampf(n * 1.2 - 0.1, 0.0, 1.0)).darkened(fine * 0.25))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Paints a darker path strip on the ground between points.
func make_path(points: Array, width: float, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var mid := (a + b) * 0.5
		var d := b - a
		var seg := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(width, d.length() + width * 0.5)
		seg.mesh = pm
		seg.material_override = mat
		add_child(seg)
		seg.position = mid + Vector3(0, 0.015 + i * 0.001, 0)
		seg.rotation.y = atan2(d.x, d.z)


func make_bounds(rect: Rect2, height: float = 6.0) -> void:
	var c := rect.get_center()
	var thick := 2.0
	Props.collider_box(self, Vector3(rect.size.x, height, thick), Vector3(c.x, height * 0.5, rect.position.y))
	Props.collider_box(self, Vector3(rect.size.x, height, thick), Vector3(c.x, height * 0.5, rect.end.y))
	Props.collider_box(self, Vector3(thick, height, rect.size.y), Vector3(rect.position.x, height * 0.5, c.y))
	Props.collider_box(self, Vector3(thick, height, rect.size.y), Vector3(rect.end.x, height * 0.5, c.y))
