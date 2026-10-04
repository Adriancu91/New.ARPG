class_name CameraRig
extends Camera3D
## ARPG camera: fixed high angle, smooth follow, mouse-wheel zoom, gentle
## auto zoom-out during boss fights, optional screen shake.

const PITCH_DEG := 56.0
const MIN_DIST := 9.0
const MAX_DIST := 30.0

var target: Node3D
var distance := 15.0
var _desired := 15.0
var _shake := 0.0
var boss_mode := false
var shake_enabled := true
var _focus := Vector3.ZERO


func _ready() -> void:
	fov = 50.0
	far = 220.0
	current = true
	Events.boss_encounter_started.connect(func(_n): boss_mode = true)
	Events.boss_encounter_ended.connect(func(): boss_mode = false)


func snap() -> void:
	if target:
		_focus = target.global_position
		_apply(0.0)


func shake(amount: float) -> void:
	if shake_enabled:
		_shake = maxf(_shake, amount)


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("zoom_in"):
		_desired = clampf(_desired - 1.5, MIN_DIST, MAX_DIST)
	elif ev.is_action_pressed("zoom_out"):
		_desired = clampf(_desired + 1.5, MIN_DIST, MAX_DIST)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var want := maxf(_desired, 22.0) if boss_mode else _desired
	distance = lerpf(distance, want, 1.0 - exp(-4.0 * delta))
	_focus = _focus.lerp(target.global_position, 1.0 - exp(-10.0 * delta))
	_apply(delta)


func _apply(delta: float) -> void:
	var pitch := deg_to_rad(PITCH_DEG)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * distance
	var look := _focus + Vector3(0, 1.0, 0)
	global_position = look + offset
	look_at(look, Vector3.UP)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
		var s := _shake * _shake
		h_offset = randf_range(-1, 1) * s * 0.8
		v_offset = randf_range(-1, 1) * s * 0.8
	else:
		h_offset = 0.0
		v_offset = 0.0
