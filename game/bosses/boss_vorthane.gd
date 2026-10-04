class_name BossVorthane
extends Enemy
## Vorthane, the Hollow Bishop. Two-phase boss with telegraphed attacks:
##   Censer Sweep (cone), Sanguine Bolts (projectile fan),
##   Grave Pillars (delayed circles under the player),
##   Phase 2 (<50%): roar + summons, faster, adds Requiem Nova (big ring).

const PHASE2_AT := 0.5

var active := false
var phase := 1
var _attack_cd := 2.0
var _busy := 0.0
var _next_pattern := 0
var _transitioning := 0.0
var summon_ids: Array = []
var arena_center := Vector3.ZERO
var boss_name := ""


static func create_boss(lvl: int) -> BossVorthane:
	var b := BossVorthane.new()
	b.setup("vorthane", lvl)
	b.boss_name = b.def.name
	b.tags.append("boss")
	b.knockback_resist = 1.0
	b.drops_loot = false
	b.hp_bar.visible = false
	b.remove_child(b.hp_bar)
	b.hp_bar.queue_free()
	b.hp_bar = null
	return b


func activate() -> void:
	if active or is_dead:
		return
	active = true
	aggro = true
	target = _find_player()
	_attack_cd = 1.5
	Events.boss_encounter_started.emit(boss_name)
	_emit_health()
	Audio.play("boss_roar")
	Audio.play_music("music_boss")


func _emit_health() -> void:
	Events.boss_health_changed.emit(boss_name, health, max_health, phase)


func _think(delta: float) -> Vector3:
	if not active or not _player_ok():
		return Vector3.ZERO
	_attack_cd -= delta * (1.35 if phase == 2 else 1.0)
	_busy -= delta
	if _transitioning > 0.0:
		_transitioning -= delta
		return Vector3.ZERO
	var to_player := target.global_position - global_position
	to_player.y = 0
	var dist := to_player.length()
	if _busy > 0.0:
		return Vector3.ZERO
	_face(to_player)
	if _attack_cd <= 0.0:
		_choose_attack(dist, to_player)
		return Vector3.ZERO
	if dist > 4.5:
		return to_player.normalized() * (1.3 if phase == 2 else 1.0)
	return Vector3.ZERO


func _choose_attack(dist: float, to_player: Vector3) -> void:
	var pattern: String
	var pool: Array = ["sweep", "bolts", "pillars"]
	if phase == 2:
		pool.append("nova")
	if dist < 5.5 and randf() < 0.55:
		pattern = "sweep" if phase == 1 or randf() < 0.6 else "nova"
	else:
		pattern = pool[_next_pattern % pool.size()]
		_next_pattern += 1
	match pattern:
		"sweep": _censer_sweep(to_player)
		"bolts": _sanguine_bolts(to_player)
		"pillars": _grave_pillars()
		"nova": _requiem_nova()


func _censer_sweep(to_player: Vector3) -> void:
	var t := 0.95 if phase == 1 else 0.75
	rotation.y = atan2(-to_player.x, -to_player.z)
	if rig: rig.play("attack", t + 0.3)
	Audio.play("telegraph")
	AreaEffect.spawn(self, global_position, {
		"team": "enemy", "radius": 6.0, "delay": t, "shape": "cone", "angle": 150.0,
		"forward": to_player.normalized(), "color": Color(1.0, 0.25, 0.3),
		"make_hit": _boss_hit.bind(1.4, 8.0),
		"on_fire": func(_h): Audio.play("heavy_swing")})
	_busy = t + 0.5
	_attack_cd = 2.4


func _sanguine_bolts(to_player: Vector3) -> void:
	var t := 0.75 if phase == 1 else 0.55
	var count := 5 if phase == 1 else 7
	if rig: rig.play("cast", t + 0.2)
	Audio.play("telegraph")
	VFX.ring(self, global_position, 2.5, Color(0.9, 0.2, 0.35), t)
	get_tree().create_timer(t, false).timeout.connect(func():
		if not is_alive() or not _player_ok():
			return
		var dir := (target.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()
		var spread := deg_to_rad(70.0)
		for i in count:
			var a := -spread * 0.5 + spread * float(i) / float(count - 1)
			var d := dir.rotated(Vector3.UP, a)
			Projectile.spawn(self, global_position + Vector3(0, 2.2, 0) + d * 1.5, d, {
				"team": "enemy", "speed": 13.0, "range": 26.0, "color": Color(0.95, 0.2, 0.35),
				"size": 0.3, "make_hit": _boss_hit.bind(0.8, 3.0), "source": self, "light": i % 2 == 0})
		Audio.play("spell_shadow"))
	_busy = t + 0.4
	_attack_cd = 2.2


func _grave_pillars() -> void:
	var count := 3 if phase == 1 else 5
	if rig: rig.play("slam", 0.9)
	Audio.play("telegraph")
	var center := target.global_position
	for i in count:
		var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		var pos := center + off
		get_tree().create_timer(i * 0.18, false).timeout.connect(func():
			if not is_alive():
				return
			AreaEffect.spawn(self, pos, {
				"team": "enemy", "radius": 2.2, "delay": 1.15, "color": Color(0.75, 0.25, 1.0),
				"make_hit": _boss_hit.bind(1.3, 6.0),
				"on_fire": func(_h): Audio.play("slam", 0.1, -4.0)}))
	_busy = 0.9
	_attack_cd = 2.8


func _requiem_nova() -> void:
	if rig: rig.play("cast", 1.5)
	Audio.play("boss_roar", 0.05, -4.0)
	AreaEffect.spawn(self, global_position, {
		"team": "enemy", "radius": 8.0, "delay": 1.4, "color": Color(1.0, 0.15, 0.2), "follow": self,
		"make_hit": _boss_hit.bind(2.0, 14.0),
		"on_fire": func(_h): Audio.play("explosion")})
	_busy = 1.7
	_attack_cd = 3.0


func _boss_hit(t, mult: float, kb: float) -> Damage.Hit:
	var h := Damage.Hit.new()
	h.amount = damage * mult * rng.randf_range(0.92, 1.08)
	h.element = "shadow"
	h.source = self
	h.attacker_level = level
	h.knockback = kb
	if t != null and is_instance_valid(t):
		h.knockback_dir = t.global_position - global_position
	return h


func take_hit(hit: Damage.Hit) -> float:
	if not active:
		activate()
	if _transitioning > 0.0:
		FloatingText.spawn(self, global_position + Vector3(0, 4, 0), 0, false, "physical", false)
		return 0.0
	var dmg := _base_take_hit(hit)
	_emit_health()
	if phase == 1 and is_alive() and health <= max_health * PHASE2_AT:
		_enter_phase_two()
	return dmg


func _base_take_hit(hit: Damage.Hit) -> float:
	# Combatant behaviour without Enemy's pack-aggro logic.
	if not is_alive():
		return 0.0
	var dmg := Damage.mitigate(hit, armor, tags, 0.0)
	health = maxf(0.0, health - dmg)
	if hit.status == "burn":
		status.apply("burn", hit.status_duration * 0.5, dmg * 0.25)
	elif hit.status == "chill":
		status.apply("chill", hit.status_duration * 0.4, 0.0)
	# stuns are reduced to a short stagger on the boss
	elif hit.status == "stun" and not status.has("stun") and _busy <= 0.0:
		status.apply("stun", 0.4, 0.0)
	_flash()
	FloatingText.spawn(self, global_position + Vector3(0, 5.0, 0), dmg, hit.crit, hit.element, false)
	damaged.emit(dmg, hit)
	if hit.source != null and is_instance_valid(hit.source) and hit.source.has_method("on_hit_dealt"):
		hit.source.on_hit_dealt(self, dmg, hit)
	if health <= 0.0:
		_die()
	return dmg


func _enter_phase_two() -> void:
	phase = 2
	_transitioning = 1.6
	_busy = 0.0
	status.clear()
	Events.notify.emit("Vorthane: \"THE DAWN IS MINE TO SWALLOW!\"", Color(1.0, 0.3, 0.35))
	Audio.play("boss_roar")
	if rig: rig.play("cast", 1.6)
	VFX.ring(self, global_position, 9.0, Color(1, 0.2, 0.3), 0.9)
	VFX.flash(self, global_position, Color(1, 0.2, 0.3), 6.0, 18.0, 1.0)
	speed *= 1.3
	# push the player away
	if _player_ok():
		var h := _boss_hit(target, 0.3, 14.0)
		h.unblockable = true
		target.take_hit(h)
	_emit_health()
	# summon adds
	get_tree().create_timer(0.8, false).timeout.connect(_summon)


func _summon() -> void:
	if not is_alive():
		return
	var spots := [Vector3(5, 0, 3), Vector3(-5, 0, 3), Vector3(0, 0, -5)]
	var kinds := ["gloomfang", "gloomfang", "hollow_sentinel"]
	for i in spots.size():
		var e := Enemy.create(kinds[i], level - 1)
		e.drops_loot = false
		get_parent().add_child(e)
		e.global_position = global_position + spots[i]
		e.home = e.global_position
		e.aggro = true
		e._enter(Enemy.State.CHASE)
		summon_ids.append(e.get_instance_id())
		VFX.pillar(self, e.global_position, 1.0, 3.0, Color(0.7, 0.2, 1.0), 0.6)


func _die() -> void:
	is_dead = true
	died.emit(self)
	state = State.DEAD
	collision_layer = 0
	remove_from_group("enemies")
	active = false
	if rig: rig.die()
	Audio.play("boss_roar", 0.0, 2.0)
	Audio.play("explosion")
	VFX.flash(self, global_position, Color(1, 0.85, 0.5), 8.0, 25.0, 2.0)
	VFX.ring(self, global_position, 10.0, Color(1, 0.9, 0.6), 1.2)
	VFX.burst(self, global_position, Color(1, 0.4, 0.4), 40, 7.0)
	# summoned adds crumble with their master
	for id in summon_ids:
		var e = instance_from_id(id)
		if e != null and is_instance_valid(e) and e.is_alive():
			var h := Damage.Hit.new()
			h.amount = 99999.0
			h.element = "light"
			e.take_hit(h)
	var xp := Progression.enemy_xp(xp_value, level, Game.character.level if Game.character else 1)
	Events.enemy_killed.emit(enemy_id, tags, xp, global_position)
	Events.boss_health_changed.emit(boss_name, 0.0, max_health, phase)
	Events.boss_defeated.emit(enemy_id)
	Events.boss_encounter_ended.emit()
	if Game.character:
		var loot := LootTable.roll_boss(enemy_id, level, Game.character.class_id, Game.rng)
		LootPickup.drop_bundle(self, global_position, loot, true)
	Events.notify.emit("VICTORY  -  Vorthane, the Hollow Bishop has fallen", Color(1.0, 0.85, 0.4))
	Audio.play_music("music_reliquary")
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 1.5)
	tw.tween_callback(queue_free)
