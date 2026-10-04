class_name Combatant
extends CharacterBody3D
## Shared base for anything that fights: health, status effects, knockback,
## hit flash and floating damage numbers.

signal died(who)
signal damaged(amount: float, hit)

var max_health: float = 100.0
var health: float = 100.0
var armor: float = 0.0
var level: int = 1
var tags: Array = []
var is_dead := false
var status := StatusEffects.new()
var knockback_velocity := Vector3.ZERO
var knockback_resist := 0.0
var visual: Node3D = null        # root of the procedural model
var _flash_time := 0.0
var _flash_mats: Array = []


func is_alive() -> bool:
	return not is_dead and health > 0.0


## Apply a hit. Returns the final damage dealt.
func take_hit(hit: Damage.Hit) -> float:
	if not is_alive() or hit == null or hit.amount <= 0.0:
		return 0.0
	var dmg := Damage.mitigate(hit, armor, tags, _extra_reduction(hit))
	health = maxf(0.0, health - dmg)
	if hit.knockback > 0.0 and hit.knockback_dir != Vector3.ZERO:
		knockback_velocity += hit.knockback_dir.normalized() * hit.knockback * (1.0 - knockback_resist)
	if hit.status != "":
		var mag := dmg * 0.35 if hit.status == "burn" else 0.0
		status.apply(hit.status, hit.status_duration * (1.0 - knockback_resist * 0.5), mag)
	_flash()
	FloatingText.spawn(self, global_position + Vector3(0, _text_height(), 0), dmg, hit.crit, hit.element, _is_player())
	damaged.emit(dmg, hit)
	if hit.source != null and is_instance_valid(hit.source) and hit.source.has_method("on_hit_dealt"):
		hit.source.on_hit_dealt(self, dmg, hit)
	if health <= 0.0:
		_die()
	return dmg


func _extra_reduction(_hit) -> float:
	return 0.0


func _is_player() -> bool:
	return false


func _text_height() -> float:
	return 2.2


func heal(amount: float) -> void:
	if not is_alive():
		return
	health = minf(max_health, health + amount)


func _die() -> void:
	is_dead = true
	died.emit(self)


## Applies burn damage and decays knockback. Call from _physics_process.
func process_combat(delta: float) -> void:
	var dot := status.tick(delta)
	if dot > 0.0 and is_alive():
		health = maxf(0.0, health - dot)
		if Engine.get_physics_frames() % 2 == 0:
			FloatingText.spawn(self, global_position + Vector3(0, _text_height(), 0), dot, false, "fire", _is_player())
		if health <= 0.0:
			_die()
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 40.0 * delta)
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_set_flash(false)


func _flash() -> void:
	if _flash_mats.is_empty() and visual != null:
		_collect_mats(visual)
	_flash_time = 0.1
	_set_flash(true)


func _collect_mats(n: Node) -> void:
	if n is MeshInstance3D and n.material_override is StandardMaterial3D:
		_flash_mats.append(n.material_override)
	for c in n.get_children():
		_collect_mats(c)


var _flashing := false

func _set_flash(on: bool) -> void:
	if on == _flashing:
		return
	_flashing = on
	for m in _flash_mats:
		if not is_instance_valid(m):
			continue
		if on:
			m.set_meta("pre_flash", m.albedo_color)
			m.albedo_color = Color(1.6, 1.4, 1.3)
		elif m.has_meta("pre_flash"):
			m.albedo_color = m.get_meta("pre_flash")


func flat_distance_to(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()
