class_name CombatUtils
extends RefCounted
## Target queries shared by attacks, skills, projectiles and AoEs.
## Uses group membership + flat (XZ) distance: cheap, deterministic and
## independent of physics layers.


static func opponents(tree: SceneTree, team: String) -> Array:
	var group := "enemies" if team == "player" else "player"
	var out: Array = []
	for n in tree.get_nodes_in_group(group):
		if n is Combatant and n.is_alive():
			out.append(n)
	return out


static func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func in_radius(tree: SceneTree, team: String, center: Vector3, radius: float) -> Array:
	var out: Array = []
	for c in opponents(tree, team):
		var r: float = radius + c.get_meta("hit_radius", 0.4)
		if flat(c.global_position).distance_to(flat(center)) <= r:
			out.append(c)
	return out


## Cone with apex at origin facing `forward` (XZ), full angle in degrees.
static func in_cone(tree: SceneTree, team: String, origin: Vector3, forward: Vector3, range_: float, angle_deg: float) -> Array:
	var out: Array = []
	var f := flat(forward).normalized()
	for c in opponents(tree, team):
		var to := flat(c.global_position) - flat(origin)
		var hr: float = c.get_meta("hit_radius", 0.4)
		var d := to.length()
		if d > range_ + hr:
			continue
		if d < hr + 0.3:
			out.append(c)
			continue
		var ang := rad_to_deg(absf(f.angle_to(to.normalized())))
		# widen the effective cone by the target's size
		var slack := rad_to_deg(atan2(hr, maxf(d, 0.01)))
		if ang <= angle_deg * 0.5 + slack:
			out.append(c)
	return out


## Distance from point p to segment a-b on the XZ plane.
static func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var pa := flat(p) - flat(a)
	var ba := flat(b) - flat(a)
	var h := clampf(pa.dot(ba) / maxf(ba.length_squared(), 0.0001), 0.0, 1.0)
	return (pa - ba * h).length()


static func in_segment(tree: SceneTree, team: String, a: Vector3, b: Vector3, width: float) -> Array:
	var out: Array = []
	for c in opponents(tree, team):
		if segment_distance(c.global_position, a, b) <= width + c.get_meta("hit_radius", 0.4):
			out.append(c)
	return out


## Walk distance along dir from origin before hitting world geometry.
static func clear_distance(world: World3D, origin: Vector3, dir: Vector3, max_dist: float, exclude: Array = []) -> float:
	var space := world.direct_space_state
	var from := origin + Vector3(0, 0.8, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * max_dist, 1)
	q.exclude = exclude
	var r := space.intersect_ray(q)
	if r.is_empty():
		return max_dist
	return maxf(0.0, from.distance_to(r.position) - 0.6)
