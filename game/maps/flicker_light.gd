class_name FlickerLight
extends OmniLight3D
## Subtle fire flicker for torches and campfires.

var _base := -1.0
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	_base = light_energy
	_seed = randf() * 100.0


func _process(delta: float) -> void:
	if _base < 0.0:
		_base = light_energy
	_t += delta
	light_energy = _base * (0.85 + 0.1 * sin(_t * 9.0 + _seed) + 0.06 * sin(_t * 23.0 + _seed * 2.0))
