class_name HumanoidRig
extends Node3D
## Pivot skeleton + procedural animation for primitive-built humanoids.
## PLACEHOLDER animation: walk cycle, idle breathing, attack/heavy/cast/dodge/
## block/hit/death poses driven by code instead of authored clips.

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand_r: Node3D
var hand_l: Node3D

var hip_height := 0.95
var move_ratio := 0.0          # 0..1 set by owner
var blocking := false
var stride := 1.0
var _phase := 0.0
var _idle := 0.0
var action := ""
var action_time := 0.0
var action_duration := 0.0
var dead := false
var _death_t := 0.0
var hunch := 0.0               # forward lean for monsters
var arm_swing := 0.6


func build_skeleton(hip_h: float = 0.95, shoulder_w: float = 0.2, shoulder_h: float = 1.44, leg_w: float = 0.11) -> void:
	hip_height = hip_h
	hips = ModelKit.pivot(self, "Hips", Vector3(0, hip_h, 0))
	torso = ModelKit.pivot(hips, "Torso", Vector3.ZERO)
	head = ModelKit.pivot(torso, "Head", Vector3(0, shoulder_h - hip_h + 0.1, 0))
	arm_l = ModelKit.pivot(torso, "ArmL", Vector3(shoulder_w, shoulder_h - hip_h, 0))
	arm_r = ModelKit.pivot(torso, "ArmR", Vector3(-shoulder_w, shoulder_h - hip_h, 0))
	hand_l = ModelKit.pivot(arm_l, "HandL", Vector3(0.02, -0.58, 0.02))
	hand_r = ModelKit.pivot(arm_r, "HandR", Vector3(-0.02, -0.58, 0.02))
	leg_l = ModelKit.pivot(hips, "LegL", Vector3(leg_w, 0, 0))
	leg_r = ModelKit.pivot(hips, "LegR", Vector3(-leg_w, 0, 0))


func play(action_name: String, duration: float) -> void:
	if dead:
		return
	action = action_name
	action_time = 0.0
	action_duration = maxf(0.05, duration)


func die() -> void:
	dead = true
	_death_t = 0.0


func _process(delta: float) -> void:
	if hips == null:
		return
	if dead:
		_death_t = minf(1.0, _death_t + delta * 2.2)
		var e := ease(_death_t, 0.4)
		rotation.x = lerpf(0.0, -PI * 0.5, e)
		position.y = lerpf(0.0, 0.25, e)
		return
	_idle += delta
	_phase += delta * (2.0 + 7.5 * move_ratio) * stride
	var swing := sin(_phase) * 0.75 * move_ratio
	var bob := absf(sin(_phase)) * 0.05 * move_ratio
	hips.position.y = hip_height + bob + sin(_idle * 2.0) * 0.008
	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	torso.rotation = Vector3(hunch + 0.08 * move_ratio, sin(_phase) * 0.06 * move_ratio, 0)
	hips.rotation.y = -sin(_phase) * 0.08 * move_ratio
	arm_l.rotation = Vector3(-swing * arm_swing, 0, 0.12)
	arm_r.rotation = Vector3(swing * arm_swing, 0, -0.12)
	head.rotation = Vector3(-hunch * 0.6, 0, 0)

	if blocking:
		arm_l.rotation = Vector3(-1.35, 0.5, 0.25)
		arm_r.rotation = Vector3(-0.6, 0, -0.3)

	if action != "":
		action_time += delta
		var t := clampf(action_time / action_duration, 0.0, 1.0)
		_pose_action(t)
		if action_time >= action_duration:
			action = ""


func _pose_action(t: float) -> void:
	match action:
		"attack":
			# wind up then slash across
			var k := sin(t * PI)
			arm_r.rotation = Vector3(lerpf(-2.4, -0.4, t), lerpf(0.9, -0.9, t), -0.4 * k)
			torso.rotation.y = lerpf(0.5, -0.45, t)
			if hand_l.get_child_count() > 0:
				arm_l.rotation = Vector3(lerpf(-0.4, -2.2, t), lerpf(-0.6, 0.8, t), 0.4 * k)
		"attack_b":
			arm_l.rotation = Vector3(lerpf(-2.4, -0.4, t), lerpf(-0.9, 0.9, t), 0.4)
			arm_r.rotation = Vector3(lerpf(-0.4, -2.0, t), lerpf(0.6, -0.6, t), -0.3)
			torso.rotation.y = lerpf(-0.5, 0.45, t)
		"heavy":
			var up := clampf(t / 0.55, 0.0, 1.0)
			var down := clampf((t - 0.55) / 0.45, 0.0, 1.0)
			arm_r.rotation = Vector3(lerpf(lerpf(0.0, -3.0, up), -0.2, down), 0.2, -0.2)
			arm_l.rotation = Vector3(lerpf(lerpf(0.0, -2.8, up), -0.3, down), -0.2, 0.2)
			torso.rotation.x = lerpf(lerpf(0.0, -0.25, up), 0.35, down)
		"shoot":
			arm_l.rotation = Vector3(-1.55, 0.15, 0.0)
			arm_r.rotation = Vector3(-1.5, -0.6 * (1.0 - t), -0.2)
			torso.rotation.y = 0.35
		"cast":
			var k := sin(t * PI)
			arm_r.rotation = Vector3(-1.2 - 1.2 * k, -0.3, -0.4)
			arm_l.rotation = Vector3(-1.2 - 1.0 * k, 0.3, 0.4)
			torso.rotation.x = -0.15 * k
		"slam":
			var up := clampf(t / 0.7, 0.0, 1.0)
			var down := clampf((t - 0.7) / 0.3, 0.0, 1.0)
			arm_r.rotation = Vector3(lerpf(lerpf(0.0, -3.0, up), 0.2, down), 0, -0.2)
			arm_l.rotation = Vector3(lerpf(lerpf(0.0, -3.0, up), 0.2, down), 0, 0.2)
			torso.rotation.x = lerpf(lerpf(0.0, -0.3, up), 0.5, down)
		"dodge":
			torso.rotation.x = 0.5 * sin(t * PI)
			hips.position.y = hip_height - 0.25 * sin(t * PI)
			leg_l.rotation.x = -0.8 * sin(t * PI)
			leg_r.rotation.x = 0.6 * sin(t * PI)
		"hit":
			torso.rotation.x = -0.25 * sin(t * PI)
		"leap":
			hips.position.y = hip_height + 0.4 * sin(t * PI)
			leg_l.rotation.x = -1.0 * sin(t * PI)
			leg_r.rotation.x = -0.6 * sin(t * PI)
			arm_l.rotation.x = -2.0 * sin(t * PI)
			arm_r.rotation.x = -2.0 * sin(t * PI)
