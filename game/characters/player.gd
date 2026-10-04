class_name Player
extends Combatant
## The player-controlled heroine. Reads input, owns combat timers, and maps
## CharacterData (persistent stats) onto the live combat body.

const DODGE_SPEED := 17.0
const DODGE_TIME := 0.32
const DODGE_IFRAMES := 0.22
const DODGE_COOLDOWN := 0.55
const DODGE_STAMINA := 22.0
const HEAVY_STAMINA := 25.0
const HEAVY_WINDUP := 0.38
const BLOCK_REDUCTION := 0.65
const BLOCK_ARC := 120.0
const POTION_COOLDOWN := 1.0
const INTERACT_RANGE := 2.8

var data: CharacterData
var stats: Dictionary = {}
var class_id := ""
var attack_style := "melee"
var mana := 0.0
var max_mana := 0.0
var stamina := 100.0
var max_stamina := 100.0
var rig                             # HumanoidRig
var visual_root: Node3D

# timers
var attack_timer := 0.0
var heavy_timer := -1.0
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var iframes := 0.0
var potion_cooldown := 0.0
var skill_cooldowns: Dictionary = {}
var hurt_timer := 0.0
var _regen_block := 0.0
var _dash_tween: Tween
var _step_t := 0.0
var _dodge_dir := Vector3.ZERO
var blocking := false
var guard_broken := 0.0

# control
var input_enabled := true
var aim_override = null             # Vector3 used by automated tests
var move_override = null            # Vector2 used by automated tests
var _rng := RandomNumberGenerator.new()
var camera: Camera3D = null


func setup(character: CharacterData) -> void:
	data = character
	class_id = data.class_id
	var cls := data.class_data()
	attack_style = cls.attack_style
	name = "Player"
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	set_meta("hit_radius", 0.45)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	visual_root.rotation_degrees.y = 180.0
	add_child(visual_root)
	rig = HeroModels.build(class_id)
	visual_root.add_child(rig)
	visual = visual_root
	_rng.randomize()
	for sid in data.hotbar_skills():
		skill_cooldowns[sid] = 0.0
	refresh_stats()
	health = clampf(data.health, 1.0, max_health) if data.health > 0 else max_health
	mana = clampf(data.mana, 0.0, max_mana) if data.mana >= 0 else max_mana
	stamina = max_stamina
	data.stats_changed.connect(refresh_stats)
	data.leveled_up.connect(_on_level_up)
	data.equipment.changed.connect(refresh_stats)
	_add_shadow_blob()


func _add_shadow_blob() -> void:
	var blob := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = 0.5
	d.bottom_radius = 0.5
	d.height = 0.01
	blob.mesh = d
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob.material_override = m
	blob.position.y = 0.03
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)


func refresh_stats() -> void:
	if data == null:
		return
	var old_max := max_health
	stats = data.compute_stats(status.stat_modifiers())
	level = data.level
	max_health = stats.max_health
	max_mana = stats.max_mana
	max_stamina = stats.max_stamina
	armor = stats.armor
	if old_max > 0.0 and max_health > old_max and health > 0.0:
		health += max_health - old_max
	health = minf(health, max_health)
	mana = minf(mana, max_mana)


func _on_level_up(_lv: int) -> void:
	refresh_stats()
	health = max_health
	mana = max_mana
	stamina = max_stamina


func _is_player() -> bool:
	return true


func facing() -> Vector3:
	return -global_transform.basis.z


func face_direction(dir: Vector3) -> void:
	dir.y = 0
	if dir.length() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)


func face_point(p: Vector3) -> void:
	face_direction(p - global_position)


func play_anim(action_name: String, duration: float) -> void:
	if rig:
		rig.play(action_name, duration)


func grant_invulnerability(t: float) -> void:
	iframes = maxf(iframes, t)


func is_invulnerable() -> bool:
	return iframes > 0.0


# ------------------------------------------------------------------ aim

func aim_point() -> Vector3:
	if aim_override != null:
		return aim_override
	if camera == null or not is_inside_tree():
		return global_position + facing() * 5.0
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return global_position + facing() * 5.0
	var t := (global_position.y - from.y) / dir.y
	if t < 0:
		return global_position + facing() * 5.0
	return from + dir * t


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if data == null:
		return
	process_combat(delta)
	_tick_timers(delta)
	if is_dead:
		velocity = Vector3.ZERO
		return
	_regen(delta)
	var stunned := status.is_stunned() or guard_broken > 0.0
	var move_input := _read_move()
	blocking = false
	if input_enabled and not stunned:
		_handle_actions()
	var speed: float = stats.move_speed * status.speed_multiplier()
	if dodge_timer > 0.0:
		velocity = _dodge_dir * DODGE_SPEED
	elif _dash_tween != null and _dash_tween.is_running():
		velocity = Vector3.ZERO
	else:
		if heavy_timer >= 0.0:
			speed *= 0.25
		if blocking:
			speed *= 0.4
		var mv := Vector3(move_input.x, 0, move_input.y)
		velocity.x = mv.x * speed
		velocity.z = mv.z * speed
		if mv.length() > 0.1 and attack_timer <= 0.05 and heavy_timer < 0.0 and not blocking:
			face_direction(mv)
	velocity += knockback_velocity
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if global_position.y < -20.0:
		global_position = Vector3(global_position.x, 1.0, global_position.z)
	if rig:
		var horiz := Vector2(velocity.x, velocity.z).length()
		rig.move_ratio = clampf(horiz / maxf(stats.move_speed, 0.1), 0.0, 1.0) if dodge_timer <= 0.0 else 0.0
		rig.blocking = blocking
		if horiz > 1.0 and dodge_timer <= 0.0:
			_step_t += delta * horiz
			if _step_t > 2.2:
				_step_t = 0.0
				Audio.play("footstep", 0.15, -10.0)


func _read_move() -> Vector2:
	if move_override != null:
		return move_override
	if not input_enabled:
		return Vector2.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return v.limit_length(1.0)


func _tick_timers(delta: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	potion_cooldown = maxf(0.0, potion_cooldown - delta)
	iframes = maxf(0.0, iframes - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	guard_broken = maxf(0.0, guard_broken - delta)
	_regen_block = maxf(0.0, _regen_block - delta)
	if dodge_timer > 0.0:
		dodge_timer -= delta
	for sid in skill_cooldowns:
		skill_cooldowns[sid] = maxf(0.0, skill_cooldowns[sid] - delta)
	if heavy_timer >= 0.0:
		heavy_timer += delta
		if heavy_timer >= HEAVY_WINDUP:
			heavy_timer = -1.0
			_release_heavy()
	# buffs expire -> stats may change
	if Engine.get_physics_frames() % 15 == 0:
		refresh_stats()


func _regen(delta: float) -> void:
	mana = minf(max_mana, mana + stats.mana_regen * delta)
	if _regen_block <= 0.0:
		stamina = minf(max_stamina, stamina + stats.stamina_regen * delta)
	var hr: float = stats.health_regen * (4.0 if hurt_timer <= 0.0 and not _in_combat() else 1.0)
	health = minf(max_health, health + hr * delta)


func _in_combat() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.get("aggro") and flat_distance_to(e.global_position) < 18.0:
			return true
	return false


func _handle_actions() -> void:
	if Input.is_action_just_pressed("dodge"):
		try_dodge()
	if data.class_data().get("can_block", false) and Input.is_action_pressed("block") and dodge_timer <= 0.0:
		blocking = stamina > 1.0
	if Input.is_action_pressed("attack") and not _mouse_over_ui():
		try_attack()
	if Input.is_action_just_pressed("heavy_attack") and not _mouse_over_ui():
		try_heavy()
	var bar := data.hotbar_skills()
	for i in bar.size():
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			try_skill(bar[i])
	if Input.is_action_just_pressed("potion"):
		try_potion()
	if Input.is_action_just_pressed("interact"):
		try_interact()


func _mouse_over_ui() -> bool:
	if aim_override != null:
		return false   # automated driver: no real mouse
	var vp := get_viewport()
	return vp != null and vp.gui_get_hovered_control() != null


# --------------------------------------------------------------- actions

func can_act() -> bool:
	return is_alive() and dodge_timer <= 0.0 and heavy_timer < 0.0 and not status.is_stunned() and guard_broken <= 0.0


func attack_interval() -> float:
	var base: float = data.class_data().base.attack_interval
	return base / maxf(0.3, stats.attack_speed)


func roll_hit(mult: float, element: String, is_skill: bool = false) -> Damage.Hit:
	var h := Damage.roll_player(stats, mult, element, _rng, is_skill)
	h.source = self
	return h


func try_attack() -> bool:
	if not can_act() or attack_timer > 0.0:
		return false
	attack_timer = attack_interval()
	var aim := aim_point()
	face_point(aim)
	var cls := data.class_data()
	if attack_style == "ranged":
		play_anim("shoot", attack_interval() * 0.9)
		Audio.play("bow")
		var dir := facing()
		Projectile.spawn(self, global_position + Vector3(0, 1.2, 0) + dir * 0.6, dir, {
			"team": "player", "speed": 32.0, "range": float(cls.base.attack_range), "pierce": 0,
			"color": Color(0.85, 0.95, 1.0), "size": 0.1, "arrow": true, "light": false, "source": self,
			"make_hit": func(t):
				var h := roll_hit(1.0, "physical")
				h.knockback = 2.0
				h.knockback_dir = t.global_position - global_position
				return h})
	else:
		var alt := class_id == "hellbrand" and (Engine.get_physics_frames() / 10) % 2 == 0
		play_anim("attack_b" if alt else "attack", attack_interval() * 0.9)
		Audio.play("swing")
		var fwd := facing()
		var rng_: float = cls.base.attack_range
		var arc: float = cls.base.attack_arc
		VFX.slash(self, global_position, fwd, rng_, arc, Color(1, 0.95, 0.8) if class_id == "dawnwarden" else Color(1, 0.4, 0.25))
		var any := false
		for t in CombatUtils.in_cone(get_tree(), "player", global_position, fwd, rng_, arc):
			var h := roll_hit(1.0, "physical")
			h.knockback = 3.0
			h.knockback_dir = t.global_position - global_position
			t.take_hit(h)
			any = true
		if any:
			mana = minf(max_mana, mana + 3.0)
			Audio.play("hit")
	return true


func try_heavy() -> bool:
	if not can_act() or attack_timer > 0.0 or stamina < HEAVY_STAMINA:
		return false
	stamina -= HEAVY_STAMINA
	_regen_block = 0.6
	heavy_timer = 0.0
	face_point(aim_point())
	play_anim("heavy" if attack_style == "melee" else "shoot", HEAVY_WINDUP + 0.15)
	Audio.play("heavy_swing")
	return true


func _release_heavy() -> void:
	if not is_alive():
		return
	attack_timer = attack_interval() * 0.8
	var fwd := facing()
	if attack_style == "ranged":
		Audio.play("bow")
		Projectile.spawn(self, global_position + Vector3(0, 1.2, 0) + fwd * 0.6, fwd, {
			"team": "player", "speed": 40.0, "range": 26.0, "pierce": 3,
			"color": Color(0.7, 1.0, 1.0), "size": 0.16, "arrow": true, "source": self,
			"make_hit": func(t):
				var h := roll_hit(2.0, "physical")
				h.knockback = 8.0
				h.knockback_dir = t.global_position - global_position
				return h})
		return
	var rng_: float = float(data.class_data().base.attack_range) + 0.6
	VFX.slash(self, global_position, fwd, rng_, 170.0, Color(1, 0.85, 0.5), 0.3)
	VFX.ring(self, global_position + fwd * 1.2, 1.6, Color(1, 0.8, 0.5), 0.3)
	var any := false
	for t in CombatUtils.in_cone(get_tree(), "player", global_position, fwd, rng_, 170.0):
		var h := roll_hit(2.0, "physical")
		h.knockback = 10.0
		h.knockback_dir = t.global_position - global_position
		t.take_hit(h)
		any = true
	if any:
		Audio.play("crit")
		if get_viewport() and get_viewport().get_camera_3d() and get_viewport().get_camera_3d().has_method("shake"):
			get_viewport().get_camera_3d().shake(0.25)


func try_dodge() -> bool:
	if not is_alive() or dodge_cooldown > 0.0 or dodge_timer > 0.0 or stamina < DODGE_STAMINA or status.is_stunned():
		return false
	var mv := _read_move()
	var dir := Vector3(mv.x, 0, mv.y)
	if dir.length() < 0.1:
		dir = facing()
	_dodge_dir = dir.normalized()
	face_direction(_dodge_dir)
	stamina -= DODGE_STAMINA
	_regen_block = 0.5
	dodge_timer = DODGE_TIME
	dodge_cooldown = DODGE_TIME + DODGE_COOLDOWN
	iframes = DODGE_IFRAMES
	heavy_timer = -1.0
	play_anim("dodge", DODGE_TIME)
	Audio.play("dodge")
	return true


func skill_ready(sid: String) -> bool:
	return skill_cooldowns.get(sid, 0.0) <= 0.0


func skill_block_reason(sid: String) -> String:
	var sk := DB.get_skill(sid)
	if data.skill_rank(sid) <= 0:
		return "locked"
	if not skill_ready(sid):
		return "cooldown"
	if mana < float(sk.get("mana", 0)):
		return "mana"
	return ""


func try_skill(sid: String) -> bool:
	if not can_act():
		return false
	var reason := skill_block_reason(sid)
	if reason != "":
		if reason == "mana":
			Events.notify.emit("Not enough %s" % data.class_data().resource_name, Color(0.6, 0.7, 1.0))
		elif reason == "locked":
			Events.notify.emit("Skill not learned yet (K)", Color(0.8, 0.8, 0.8))
		return false
	var sk := DB.get_skill(sid)
	var aim := aim_point()
	if not SkillExecutor.execute(self, sid, data.skill_rank(sid), aim):
		return false
	mana -= float(sk.get("mana", 0))
	skill_cooldowns[sid] = float(sk.get("cooldown", 1.0))
	attack_timer = maxf(attack_timer, 0.25)
	return true


func try_potion() -> bool:
	if potion_cooldown > 0.0 or not is_alive() or health >= max_health:
		return false
	if not data.inventory.consume("potion_health", 1):
		Events.notify.emit("No Crimson Tinctures left", Color(1, 0.5, 0.5))
		return false
	potion_cooldown = POTION_COOLDOWN
	heal(max_health * float(DB.stackable_def("potion_health").get("heal_pct", 0.4)))
	VFX.burst(self, global_position, Color(1, 0.3, 0.35), 14, 2.5)
	Audio.play("potion")
	return true


func try_interact() -> bool:
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.has_method("interact") or (n.has_method("can_interact") and not n.can_interact()):
			continue
		var d := flat_distance_to(n.global_position)
		if d <= best_d:
			best_d = d
			best = n
	if best == null:
		return false
	best.interact(self)
	return true


func nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_method("can_interact") and not n.can_interact():
			continue
		var d := flat_distance_to(n.global_position)
		if d <= best_d:
			best_d = d
			best = n
	return best


func dash_to(target: Vector3, duration: float) -> void:
	iframes = maxf(iframes, duration + 0.05)
	if _dash_tween:
		_dash_tween.kill()
	_dash_tween = create_tween()
	_dash_tween.tween_property(self, "global_position", Vector3(target.x, global_position.y, target.z), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------- receiving

func take_hit(hit: Damage.Hit) -> float:
	if not is_alive() or is_invulnerable() or hit == null or hit.amount <= 0.0:
		return 0.0
	if blocking and not hit.unblockable and hit.source != null and is_instance_valid(hit.source):
		var to_src: Vector3 = hit.source.global_position - global_position
		var ang := rad_to_deg(absf(Vector2(facing().x, facing().z).angle_to(Vector2(to_src.x, to_src.z))))
		if ang <= BLOCK_ARC * 0.5:
			stamina -= 8.0 + hit.amount * 0.4
			_regen_block = 0.7
			Audio.play("block")
			VFX.burst(self, global_position + facing() * 0.5, Color(1, 0.9, 0.5), 8, 3.0)
			if stamina <= 0.0:
				stamina = 0.0
				guard_broken = 0.7
				Events.notify.emit("Guard broken!", Color(1, 0.6, 0.3))
			hit.amount *= (1.0 - BLOCK_REDUCTION)
			hit.knockback *= 0.2
	var dmg := super.take_hit(hit)
	if dmg > 0.0:
		hurt_timer = 3.0
		Audio.play("player_hurt", 0.1, -4.0)
		Events.player_damaged.emit(dmg)
		if rig and not blocking:
			rig.play("hit", 0.2)
	return dmg


func _extra_reduction(_hit) -> float:
	return stats.get("damage_reduction", 0.0)


func on_hit_dealt(_target, dmg: float, hit: Damage.Hit) -> void:
	var gain: float = stats.get("life_on_hit", 0.0) + dmg * stats.get("life_steal", 0.0)
	if gain > 0.0:
		heal(gain)
	if hit.crit:
		Audio.play("crit", 0.05, -6.0)


func _die() -> void:
	super._die()
	if rig:
		rig.die()
	Events.player_died.emit()


func revive(at: Vector3) -> void:
	is_dead = false
	status.clear()
	global_position = at
	health = max_health
	mana = max_mana
	stamina = max_stamina
	knockback_velocity = Vector3.ZERO
	iframes = 2.0
	if rig:
		rig.dead = false
		rig.rotation = Vector3.ZERO
		rig.position = Vector3.ZERO
	Events.player_respawned.emit()


func sync_to_data() -> void:
	data.health = health
	data.mana = mana
