class_name Progression
extends RefCounted
## XP curve and level rewards.

const MAX_LEVEL := 50
const ATTRIBUTE_POINTS_PER_LEVEL := 5
const SKILL_POINTS_PER_LEVEL := 1


static func xp_to_next(level: int) -> int:
	return int(round(100.0 * pow(float(level), 1.5)))


## Applies XP to a level/xp pair. Returns {level, xp, levels_gained}.
static func apply_xp(level: int, xp: int, amount: int) -> Dictionary:
	var gained := 0
	xp += maxi(0, amount)
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	if level >= MAX_LEVEL:
		xp = 0
	return {"level": level, "xp": xp, "levels_gained": gained}


static func enemy_xp(base_xp: int, enemy_level: int, player_level: int) -> int:
	var v := float(base_xp) * (1.0 + 0.12 * (enemy_level - 1))
	var diff := player_level - enemy_level
	if diff > 3:
		v *= maxf(0.2, 1.0 - 0.15 * (diff - 3))
	return maxi(1, int(round(v)))
