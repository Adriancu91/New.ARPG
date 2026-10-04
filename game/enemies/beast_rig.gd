class_name BeastRig
extends Node3D
## Procedural quadruped gait (PLACEHOLDER animation). Same API as HumanoidRig.

var body: Node3D
var legs: Array = []
var move_ratio := 0.0
var blocking := false
var action := ""
var action_time := 0.0
var action_duration := 0.0
var dead := false
var _phase := 0.0
var _death_t := 0.0


func play(action_name: String, duration: float) -> void:
	if dead:
		return
	action = action_name
	action_time = 0.0
	action_duration = maxf(0.05, duration)


func die() -> void:
	dead = true


func _process(delta: float) -> void:
	if body == null:
		return
	if dead:
		_death_t = minf(1.0, _death_t + delta * 2.5)
		rotation.z = lerpf(0.0, PI * 0.5, ease(_death_t, 0.4))
		return
	_phase += delta * (3.0 + 11.0 * move_ratio)
	for i in legs.size():
		var off := 0.0 if i == 0 or i == 3 else PI
		legs[i].rotation.x = sin(_phase + off) * 0.7 * move_ratio
	body.position.y = 0.6 + absf(sin(_phase)) * 0.06 * move_ratio
	body.rotation.x = 0.0
	if action != "":
		action_time += delta
		var t := clampf(action_time / action_duration, 0.0, 1.0)
		match action:
			"attack", "heavy":
				body.rotation.x = -0.35 * sin(t * PI)
				body.position.z = 0.25 * sin(t * PI)
			"hit":
				body.rotation.x = 0.2 * sin(t * PI)
		if action_time >= action_duration:
			action = ""
			body.position.z = 0.0
