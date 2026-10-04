class_name VFX
extends RefCounted
## One-shot visual effects built from primitives and tweens (PLACEHOLDERS).

const K = preload("res://game/characters/model_kit.gd")


static func _host(ctx: Node) -> Node:
	if ctx == null or not ctx.is_inside_tree():
		return null
	return WorldHost.get_host(ctx)


## Expanding ring on the ground.
static func ring(ctx: Node, pos: Vector3, radius: float, color: Color, duration: float = 0.45) -> void:
	var host := _host(ctx)
	if host == null:
		return
	var n := MeshInstance3D.new()
	n.mesh = K.torus(0.85, 1.0)
	var m := K.glow_mat(color, 3.0, 0.9)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(n)
	n.global_position = pos + Vector3(0, 0.15, 0)
	n.scale = Vector3.ONE * radius * 0.2
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale", Vector3(radius, 1.0, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(n.queue_free)


## Flat arc swipe in front of an attacker.
static func slash(ctx: Node, pos: Vector3, forward: Vector3, radius: float, angle_deg: float, color: Color, duration: float = 0.22) -> void:
	var host := _host(ctx)
	if host == null:
		return
	var n := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	n.mesh = im
	var m := K.glow_mat(color, 2.5, 0.75)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var segs := 14
	var half := deg_to_rad(angle_deg * 0.5)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := -half + (2.0 * half) * float(i) / segs
		var a1 := -half + (2.0 * half) * float(i + 1) / segs
		var in_r := radius * 0.45
		var p0 := Vector3(sin(a0) * in_r, 0, cos(a0) * in_r)
		var p1 := Vector3(sin(a0) * radius, 0, cos(a0) * radius)
		var p2 := Vector3(sin(a1) * radius, 0, cos(a1) * radius)
		var p3 := Vector3(sin(a1) * in_r, 0, cos(a1) * in_r)
		for v in [p0, p1, p2, p0, p2, p3]:
			im.surface_add_vertex(v)
	im.surface_end()
	host.add_child(n)
	n.global_position = pos + Vector3(0, 1.0, 0)
	var f := Vector3(forward.x, 0, forward.z).normalized()
	if f != Vector3.ZERO:
		n.rotation.y = atan2(f.x, f.z)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.tween_property(n, "scale", Vector3(1.1, 1, 1.1), duration)
	tw.chain().tween_callback(n.queue_free)


## Vertical column of light / fire.
static func pillar(ctx: Node, pos: Vector3, radius: float, height: float, color: Color, duration: float = 0.6) -> void:
	var host := _host(ctx)
	if host == null:
		return
	var n := MeshInstance3D.new()
	n.mesh = K.cyl(1.0, 1.0, 1.0, 16)
	var m := K.glow_mat(color, 3.0, 0.6)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(n)
	n.global_position = pos + Vector3(0, height * 0.5, 0)
	n.scale = Vector3(radius, height, radius)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale", Vector3(radius * 0.1, height * 1.2, radius * 0.1), duration).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(n.queue_free)


## Short-lived light flash.
static func flash(ctx: Node, pos: Vector3, color: Color, energy: float = 3.0, range_: float = 6.0, duration: float = 0.3) -> void:
	var host := _host(ctx)
	if host == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	host.add_child(l)
	l.global_position = pos + Vector3(0, 1.2, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


static func burst(ctx: Node, pos: Vector3, color: Color, amount: int = 20, speed: float = 5.0) -> void:
	var host := _host(ctx)
	if host == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var qm := K.glow_mat(color, 4.0)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = qm
	p.mesh = q
	host.add_child(p)
	p.global_position = pos + Vector3(0, 1.0, 0)
	p.emitting = true
	p.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
