class_name Enemy
extends Combatant
## Data-driven enemy with a small state machine:
##   IDLE (wander near home) -> CHASE -> WINDUP (telegraph) -> ATTACK -> RECOVER
## Leashes home if dragged too far. Attack types: melee, projectile, lunge, slam.

enum State { IDLE, CHASE, WINDUP, RECOVER, RETURN, DEAD }

const LEASH_DISTANCE := 32.0

var enemy_id := ""
var def: Dictionary = {}
var state := State.IDLE
var target: Player = null
var aggro := false
var home := Vector3.ZERO
var speed := 3.0
var damage := 8.0
var attack_type := "melee"
var attack_range := 2.0
var detect := 12.0
var windup := 0.5
var attack_cooldown := 1.5
var _state_t := 0.0
var _cooldown := 0.0
var _wander_target := Vector3.ZERO
var _wander_wait := 0.0
var _lunge_dir := Vector3.ZERO
var _lunge_t := 0.0
var _stuck_t := 0.0
var _side := 1.0
var _telegraph: AreaEffect = null
var rig
var model: Node3D
var spawn_id := ""
var rng := RandomNumberGenerator.new()
var drops_loot := true
var xp_value := 0
var hp_bar: Node3D


static func create(id: String, lvl: int = 1) -> Enemy:
	var e := Enemy.new()
	e.setup(id, lvl)
	return e


func setup(id: String, lvl: int) -> void:
	enemy_id = id
	def = DB.get_enemy(id)
	level = maxi(1, lvl)
	name = "%s_%d" % [id, get_instance_id()]
	tags = def.get("tags", []).duplicate()
	var hp_scale := 1.0 + 0.28 * (level - 1)
	max_health = float(def.health) * hp_scale
	health = max_health
	armor = float(def.get("armor", 0)) * (1.0 + 0.1 * (level - 1))
	damage = float(def.damage) * (1.0 + 0.18 * (level - 1))
	speed = float(def.speed)
	detect = float(def.detect)
	attack_range = float(def.attack_range)
	windup = float(def.get("attack_windup", 0.5))
	attack_cooldown = float(def.get("attack_cooldown", 1.5))
	attack_type = def.get("attack_type", "melee")
	knockback_resist = float(def.get("knockback_resist", 0.0))
	xp_value = int(def.xp)
	rng.randomize()
	_side = 1.0 if rng.randf() < 0.5 else -1.0
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 4
	var sc: float = def.get("scale", 1.0)
	set_meta("hit_radius", 0.45 * sc)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * sc
	cap.height = maxf(1.7 * sc, cap.radius * 2.0)
	shape.shape = cap
	shape.position = Vector3(0, cap.height * 0.5, 0)
	add_child(shape)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.rotation_degrees.y = 180.0
	add_child(vis)
	model = EnemyModels.build(id)
	vis.add_child(model)
	rig = model.get_meta("rig")
	visual = vis
	_build_hp_bar(sc)


func _build_hp_bar(sc: float) -> void:
	hp_bar = Node3D.new()
	hp_bar.position = Vector3(0, 2.2 * sc + 0.2, 0)
	add_child(hp_bar)
	var bg := Sprite3D.new()
	bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bg.texture = _px_tex(Color(0, 0, 0, 0.75))
	bg.pixel_size = 1.0
	bg.scale = Vector3(1.1, 0.12, 1)
	bg.no_depth_test = true
	bg.render_priority = 4
	hp_bar.add_child(bg)
	var fg := Sprite3D.new()
	fg.name = "Fill"
	fg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fg.texture = _px_tex(Color(0.85, 0.15, 0.15))
	fg.pixel_size = 1.0
	fg.scale = Vector3(1.04, 0.07, 1)
	fg.centered = true
	fg.no_depth_test = true
	fg.render_priority = 5
	hp_bar.add_child(fg)
	hp_bar.visible = false


static var _tex_cache := {}
static func _px_tex(c: Color) -> Texture2D:
	var key := c.to_html()
	if not _tex_cache.has(key):
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(c)
		_tex_cache[key] = ImageTexture.create_from_image(img)
	return _tex_cache[key]


func _ready() -> void:
	home = global_position
	_wander_target = home


func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	hp_bar.visible = is_alive() and health < max_health
	var fill: Sprite3D = hp_bar.get_node("Fill")
	var k := clampf(health / max_health, 0.0, 1.0)
	fill.scale.x = 1.04 * k
	fill.offset.x = -(1.0 - k) * 0.5 / maxf(k, 0.01)


func _physics_process(delta: float) -> void:
	process_combat(delta)
	if is_dead:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_state_t += delta
	if target == null or not is_instance_valid(target):
		target = _find_player()
	var desired := Vector3.ZERO
	var spd_mult := status.speed_multiplier()
	if status.is_stunned():
		_cancel_telegraph()
		if state == State.WINDUP:
			_enter(State.RECOVER)
	else:
		desired = _think(delta)
	var v := desired * speed * spd_mult
	if _lunge_t > 0.0:
		_lunge_t -= delta
		v = _lunge_dir * float(def.get("lunge_speed", 20.0))
	velocity.x = v.x + knockback_velocity.x
	velocity.z = v.z + knockback_velocity.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - 24.0 * delta
	var before := global_position
	move_and_slide()
	if global_position.y < -20.0:
		global_position = home
	# simple stuck handling: slide sideways when blocked while chasing
	if desired.length() > 0.1 and before.distance_to(global_position) < speed * delta * 0.2:
		_stuck_t += delta
		if _stuck_t > 0.6:
			_side = -_side
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	if rig:
		rig.move_ratio = clampf(Vector2(velocity.x, velocity.z).length() / maxf(speed, 0.1), 0.0, 1.0)
	_update_hp_bar()


func _find_player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] if not ps.is_empty() else null


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0


func _player_ok() -> bool:
	return target != null and is_instance_valid(target) and target.is_alive()


func _think(_delta: float) -> Vector3:
	var to_player := Vector3.ZERO
	var dist := INF
	if _player_ok():
		to_player = target.global_position - global_position
		to_player.y = 0
		dist = to_player.length()
	match state:
		State.IDLE:
			if _player_ok() and (dist <= detect or (aggro and dist < detect * 2.0)):
				aggro = true
				_alert_pack()
				_enter(State.CHASE)
				return Vector3.ZERO
			return _wander(_delta)
		State.CHASE:
			if not _player_ok():
				aggro = false
				_enter(State.RETURN)
				return Vector3.ZERO
			if global_position.distance_to(home) > LEASH_DISTANCE and dist > 6.0:
				aggro = false
				_enter(State.RETURN)
				return Vector3.ZERO
			_face(to_player)
			if dist <= attack_range and _cooldown <= 0.0:
				_begin_attack(to_player)
				return Vector3.ZERO
			return _steer(to_player, dist)
		State.WINDUP:
			if _player_ok() and attack_type != "lunge":
				_face(to_player)
			if _state_t >= windup:
				_execute_attack()
				_enter(State.RECOVER)
			return Vector3.ZERO
		State.RECOVER:
			if _state_t >= 0.35 + (0.25 if attack_type == "slam" else 0.0):
				_enter(State.CHASE)
			if attack_type == "projectile" and _player_ok() and dist < float(def.get("preferred_range", 8.0)) * 0.6:
				return -to_player.normalized() * 0.8
			return Vector3.ZERO
		State.RETURN:
			var to_home := home - global_position
			to_home.y = 0
			health = minf(max_health, health + max_health * 0.25 * _delta)
			if to_home.length() < 1.0:
				_enter(State.IDLE)
				return Vector3.ZERO
			if _player_ok() and dist < detect * 0.6:
				aggro = true
				_enter(State.CHASE)
			_face(to_home)
			return to_home.normalized()
	return Vector3.ZERO


func _steer(to_player: Vector3, dist: float) -> Vector3:
	var dir := to_player.normalized()
	match def.get("archetype", ""):
		"ranged_caster":
			var pref: float = def.get("preferred_range", 8.0)
			if dist < pref * 0.7:
				dir = -dir
			elif dist < attack_range:
				dir = dir.cross(Vector3.UP) * _side
		"assassin":
			if dist < 9.0 and dist > attack_range * 0.6:
				dir = (dir + dir.cross(Vector3.UP) * _side * 0.9).normalized()
	# separation from other enemies so packs don't stack
	var sep := Vector3.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or not o.is_alive():
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0
		var l := d.length()
		if l < 1.4 and l > 0.01:
			sep += d / l * (1.4 - l)
	if _stuck_t > 0.3:
		dir = (dir + dir.cross(Vector3.UP) * _side).normalized()
	return (dir + sep * 0.8).limit_length(1.0)


func _wander(delta: float) -> Vector3:
	_wander_wait -= delta
	var to := _wander_target - global_position
	to.y = 0
	if to.length() < 0.6 or _wander_wait < -6.0:
		if _wander_wait <= 0.0:
			_wander_wait = rng.randf_range(2.0, 5.0)
			var a := rng.randf() * TAU
			_wander_target = home + Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, 4.0)
		return Vector3.ZERO
	_face(to)
	return to.normalized() * 0.35


func _alert_pack() -> void:
	if not is_inside_tree():
		return
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self and o is Enemy and o.state == State.IDLE and o.global_position.distance_to(global_position) < 8.0:
			o.aggro = true
			o._enter(State.CHASE)


func _face(dir: Vector3) -> void:
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.25)


func facing() -> Vector3:
	return -global_transform.basis.z


func _begin_attack(to_player: Vector3) -> void:
	_enter(State.WINDUP)
	_face(to_player)
	rotation.y = atan2(-to_player.x, -to_player.z)
	var anim := "attack"
	match attack_type:
		"projectile": anim = "cast"
		"slam": anim = "slam"
		"lunge": anim = "attack"
	if rig:
		rig.play(anim, windup + 0.2)
	Audio.play("enemy_attack", 0.1, -6.0)
	# telegraphs: everything shows intent; heavy attacks show the exact area
	match attack_type:
		"slam":
			_telegraph = AreaEffect.spawn(self, global_position + facing() * 1.6, {
				"team": "enemy", "radius": float(def.get("slam_radius", 3.5)), "delay": windup,
				"color": Color(1.0, 0.35, 0.1), "make_hit": _make_hit.bind(1.6, true)})
		"lunge":
			_lunge_dir = to_player.normalized()
			_telegraph = AreaEffect.spawn(self, global_position, {
				"team": "enemy", "radius": attack_range, "delay": windup, "shape": "cone", "angle": 22.0,
				"forward": _lunge_dir, "color": Color(0.35, 0.8, 1.0),
				"make_hit": func(_t): return null})
			_telegraph.make_hit = Callable()
		"melee":
			_telegraph = AreaEffect.spawn(self, global_position, {
				"team": "enemy", "radius": attack_range + 0.3, "delay": windup, "shape": "cone", "angle": 100.0,
				"forward": to_player.normalized(), "color": Color(0.9, 0.2, 0.2), "follow": self})
			_telegraph.make_hit = Callable()   # damage applied in _execute_attack


func _cancel_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _make_hit(_t, mult: float = 1.0, unblockable: bool = false) -> Damage.Hit:
	var h := Damage.Hit.new()
	h.amount = damage * mult * rng.randf_range(0.9, 1.1)
	h.element = def.get("element", "physical")
	h.source = self
	h.attacker_level = level
	h.knockback = 5.0 if attack_type != "slam" else 9.0
	if _t != null and is_instance_valid(_t):
		h.knockback_dir = _t.global_position - global_position
	h.unblockable = unblockable
	if h.element == "fire" and attack_type == "slam":
		h.status = "burn"
		h.status_duration = 2.5
	return h


func _execute_attack() -> void:
	_cooldown = attack_cooldown
	if not _player_ok():
		_cancel_telegraph()
		return
	match attack_type:
		"melee":
			_telegraph = null
			var fwd := facing()
			VFX.slash(self, global_position, fwd, attack_range + 0.3, 100.0, Color(0.9, 0.3, 0.3), 0.18)
			if target in CombatUtils.in_cone(get_tree(), "enemy", global_position, fwd, attack_range + 0.3, 100.0):
				target.take_hit(_make_hit(target))
		"projectile":
			var dir := target.global_position - global_position
			Projectile.spawn(self, global_position + Vector3(0, 1.3, 0) + dir.normalized() * 0.6, dir, {
				"team": "enemy", "speed": float(def.get("projectile_speed", 12.0)), "range": attack_range + 4.0,
				"color": Color(def.get("glow", "#ff6a3a")), "size": 0.22, "make_hit": _make_hit, "source": self})
			Audio.play("spell_shadow", 0.1, -6.0)
		"lunge":
			_telegraph = null
			_lunge_t = attack_range / float(def.get("lunge_speed", 20.0))
			var end := global_position + _lunge_dir * attack_range
			get_tree().create_timer(_lunge_t * 0.7, false).timeout.connect(func():
				if is_alive() and _player_ok() and CombatUtils.segment_distance(target.global_position, global_position - _lunge_dir * attack_range, end) < 1.3:
					target.take_hit(_make_hit(target, 1.0)))
			VFX.burst(self, global_position, Color(0.4, 0.8, 1.0), 10, 3.0)
		"slam":
			_telegraph = null
			Audio.play("slam")
			var cam := get_viewport().get_camera_3d() if get_viewport() else null
			if cam and cam.has_method("shake"):
				cam.shake(0.3)


func take_hit(hit: Damage.Hit) -> float:
	var dmg := super.take_hit(hit)
	if dmg > 0.0 and is_alive():
		if not aggro:
			aggro = true
			_alert_pack()
			if state == State.IDLE or state == State.RETURN:
				_enter(State.CHASE)
		if rig and state != State.WINDUP:
			rig.play("hit", 0.15)
	return dmg


func _die() -> void:
	super._die()
	_cancel_telegraph()
	state = State.DEAD
	collision_layer = 0
	collision_mask = 1
	remove_from_group("enemies")
	if hp_bar:
		hp_bar.visible = false
	if rig:
		rig.die()
	Audio.play("enemy_die", 0.1, -3.0)
	var lvl_xp := Progression.enemy_xp(xp_value, level, Game.character.level if Game.character else 1)
	Events.enemy_killed.emit(enemy_id, tags, lvl_xp, global_position)
	if drops_loot:
		_drop_loot()
	VFX.burst(self, global_position, Color(def.get("glow", "#ffffff")), 14, 3.0)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(self, "position:y", position.y - 1.5, 1.2)
	tw.tween_callback(queue_free)


func _drop_loot() -> void:
	if Game.character == null:
		return
	var loot := LootTable.roll_enemy(enemy_id, level, Game.rng, Game.loot_context())
	LootPickup.drop_bundle(self, global_position, loot, false, "enemy:" + enemy_id)
