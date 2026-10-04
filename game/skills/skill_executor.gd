class_name SkillExecutor
extends RefCounted
## Executes data-driven skills (data/skills.json). Each "type" is a reusable
## behaviour, so new skills are usually just new JSON entries:
##   melee_cone, projectile, multi_projectile, aoe_target, aoe_self,
##   dash_strike, buff, trap.

const ELEMENT_SOUND := {
	"light": "spell_light", "fire": "spell_fire", "shadow": "spell_shadow",
	"frost": "spell_frost", "arcane": "spell_arcane", "physical": "swing",
}


static func damage_multiplier(sk: Dictionary, rank: int) -> float:
	return float(sk.get("dmg_mult", 1.0)) * (1.0 + float(sk.get("rank_bonus", 0.0)) * maxi(0, rank - 1))


static func element_color(element: String) -> Color:
	return FloatingText.ELEMENT_COLORS.get(element, Color.WHITE)


## Returns true if the skill was executed.
static func execute(player, skill_id: String, rank: int, aim: Vector3) -> bool:
	var sk := DB.get_skill(skill_id)
	if sk.is_empty():
		return false
	var type: String = sk.get("type", "")
	var element: String = sk.get("element", "physical")
	var color := element_color(element)
	var mult := damage_multiplier(sk, rank)
	var origin: Vector3 = player.global_position
	var to_aim := aim - origin
	to_aim.y = 0.0
	var dir: Vector3 = to_aim.normalized() if to_aim.length() > 0.05 else player.facing()
	var status_id: String = sk.get("status", "")
	var status_dur: float = sk.get("status_duration", 0.0)
	var make_hit := func(target) -> Damage.Hit:
		var h: Damage.Hit = player.roll_hit(mult, element, true)
		h.status = status_id
		h.status_duration = status_dur
		h.knockback = float(sk.get("knockback", 0.0))
		if target != null:
			h.knockback_dir = (target.global_position - player.global_position)
		return h
	Audio.play(ELEMENT_SOUND.get(element, "swing"))
	player.face_direction(dir)

	match type:
		"melee_cone":
			var hits := int(sk.get("hits", 1))
			player.play_anim("attack", 0.3)
			for i in hits:
				var delay := 0.08 + i * 0.11
				player.get_tree().create_timer(delay, false).timeout.connect(func():
					if not is_instance_valid(player) or not player.is_alive():
						return
					var fwd: Vector3 = player.facing()
					VFX.slash(player, player.global_position, fwd, float(sk.range), float(sk.angle), color)
					for t in CombatUtils.in_cone(player.get_tree(), "player", player.global_position, fwd, float(sk.range), float(sk.angle)):
						t.take_hit(make_hit.call(t)))
		"projectile":
			player.play_anim("shoot" if player.attack_style == "ranged" else "cast", 0.3)
			Projectile.spawn(player, origin + Vector3(0, 1.1, 0) + dir * 0.6, dir, {
				"team": "player", "speed": float(sk.get("speed", 20)), "range": float(sk.get("range", 20)),
				"pierce": int(sk.get("pierce", 0)), "explode_radius": float(sk.get("explode_radius", 0.0)),
				"color": color, "size": 0.22, "make_hit": make_hit, "source": player,
				"arrow": player.attack_style == "ranged"})
		"multi_projectile":
			player.play_anim("shoot", 0.3)
			var count := int(sk.get("count", 3))
			var spread := deg_to_rad(float(sk.get("spread", 40)))
			for i in count:
				var a := -spread * 0.5 + spread * (float(i) / maxf(1.0, count - 1))
				var d: Vector3 = dir.rotated(Vector3.UP, a)
				Projectile.spawn(player, origin + Vector3(0, 1.1, 0) + d * 0.6, d, {
					"team": "player", "speed": float(sk.get("speed", 20)), "range": float(sk.get("range", 20)),
					"pierce": 0, "color": color, "size": 0.12, "make_hit": make_hit, "source": player,
					"arrow": true, "light": i == count / 2})
		"aoe_target":
			player.play_anim("cast", 0.4)
			var reach := minf(to_aim.length(), float(sk.get("range", 12)))
			var center: Vector3 = origin + dir * reach
			AreaEffect.spawn(player, center, {
				"team": "player", "radius": float(sk.radius), "delay": float(sk.get("delay", 0.5)),
				"color": color, "make_hit": make_hit,
				"on_fire": func(_h): Audio.play("explosion")})
		"aoe_self":
			player.play_anim("leap" if sk.kind == "ultimate" else "cast", maxf(0.3, float(sk.get("delay", 0.2)) + 0.1))
			AreaEffect.spawn(player, origin, {
				"team": "player", "radius": float(sk.radius), "delay": float(sk.get("delay", 0.2)),
				"color": color, "make_hit": make_hit, "follow": player,
				"on_fire": func(_h): Audio.play("explosion")})
			if sk.kind == "ultimate":
				player.grant_invulnerability(float(sk.get("delay", 0.2)) + 0.2)
		"dash_strike":
			var backwards: bool = sk.get("backwards", false)
			var d: Vector3 = -dir if backwards else dir
			var dist := minf(float(sk.get("range", 8)), to_aim.length() if not backwards else float(sk.get("range", 8)))
			dist = minf(dist, CombatUtils.clear_distance(player.get_world_3d(), origin, d, dist, [player.get_rid()]))
			var end: Vector3 = origin + d * dist
			if float(sk.get("dmg_mult", 0.0)) > 0.0:
				for t in CombatUtils.in_segment(player.get_tree(), "player", origin, end, float(sk.get("radius", 1.5))):
					t.take_hit(make_hit.call(t))
				VFX.slash(player, end, d, 2.5, 200.0, color)
			VFX.burst(player, origin, color, 16, 4.0)
			player.dash_to(end, 0.15)
			player.play_anim("leap", 0.3)
		"buff":
			player.play_anim("cast", 0.45)
			var buff: String = sk.get("buff", "")
			var mag := float(sk.get("magnitude", 0.0)) + float(sk.get("rank_bonus", 0.0)) * maxi(0, rank - 1)
			player.status.apply(buff, float(sk.get("duration", 5.0)), mag)
			if buff == "aegis":
				player.heal(player.max_health * 0.10)
			VFX.ring(player, origin, 2.5, color, 0.6)
			VFX.pillar(player, origin, 1.0, 3.0, color, 0.6)
			player.refresh_stats()
		"trap":
			player.play_anim("cast", 0.3)
			var reach := minf(to_aim.length(), float(sk.get("range", 10)))
			AreaEffect.spawn(player, origin + dir * reach, {
				"team": "player", "radius": float(sk.radius), "trap": true, "trap_life": float(sk.get("duration", 10)),
				"color": color, "make_hit": make_hit,
				"on_fire": func(_h): Audio.play("spell_frost")})
		_:
			push_warning("Unknown skill type %s" % type)
			return false
	Events.skill_used.emit(skill_id)
	return true
