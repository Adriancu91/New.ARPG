class_name StatusEffects
extends RefCounted
## Timed effects on a combatant. Debuffs: burn, chill, stun.
## Buffs: aegis, demonform. Effects refresh rather than stack.

const DEFS := {
	"burn": {"name": "Burning", "debuff": true, "color": Color(1.0, 0.45, 0.15)},
	"chill": {"name": "Chilled", "debuff": true, "color": Color(0.5, 0.85, 1.0)},
	"stun": {"name": "Stunned", "debuff": true, "color": Color(1.0, 0.95, 0.5)},
	"aegis": {"name": "Aegis of Dawn", "debuff": false, "color": Color(1.0, 0.85, 0.4)},
	"demonform": {"name": "Demonform", "debuff": false, "color": Color(1.0, 0.3, 0.2)},
}

var effects: Dictionary = {}   # id -> {time, magnitude, tick_timer}


func apply(id: String, duration: float, magnitude: float = 0.0) -> void:
	if not DEFS.has(id) or duration <= 0.0:
		return
	var cur: Dictionary = effects.get(id, {})
	effects[id] = {
		"time": maxf(duration, cur.get("time", 0.0)),
		"magnitude": maxf(magnitude, cur.get("magnitude", 0.0)),
		"tick": cur.get("tick", 0.5),
	}


func has(id: String) -> bool:
	return effects.has(id)


func remove(id: String) -> void:
	effects.erase(id)


func clear() -> void:
	effects.clear()


## Advances timers. Returns damage-over-time dealt this frame (burn).
func tick(delta: float) -> float:
	var dot := 0.0
	for id in effects.keys():
		var e: Dictionary = effects[id]
		e.time -= delta
		if id == "burn":
			e.tick -= delta
			if e.tick <= 0.0:
				e.tick += 0.5
				dot += e.magnitude * 0.5
		if e.time <= 0.0001:
			effects.erase(id)
	return dot


func speed_multiplier() -> float:
	if has("stun"):
		return 0.0
	if has("chill"):
		return 0.55
	return 1.0


func is_stunned() -> bool:
	return has("stun")


## Stat modifiers granted by active buffs (same keys as item affixes).
func stat_modifiers() -> Dictionary:
	var m: Dictionary = {}
	if has("aegis"):
		m["damage_reduction"] = effects.aegis.magnitude
	if has("demonform"):
		m["attack_speed"] = effects.demonform.magnitude
		m["damage_pct"] = 0.3
		m["life_steal"] = 0.1
	if has("chill"):
		m["attack_speed"] = m.get("attack_speed", 0.0) - 0.3
	return m


func names() -> Array:
	var out: Array = []
	for id in effects:
		out.append(id)
	return out
