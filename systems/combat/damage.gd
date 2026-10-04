class_name Damage
extends RefCounted
## Pure damage math, shared by player, enemies and the boss.

## A single hit travelling from attacker to target.
class Hit:
	var amount: float = 0.0
	var element: String = "physical"
	var crit: bool = false
	var source: Node = null
	var knockback: float = 0.0
	var knockback_dir: Vector3 = Vector3.ZERO
	var status: String = ""
	var status_duration: float = 0.0
	var attacker_level: int = 1
	var is_skill: bool = false
	var unblockable: bool = false


## Roll a player hit from derived stats. `mult` is the skill/attack multiplier.
static func roll_player(stats: Dictionary, mult: float, element: String, rng: RandomNumberGenerator, is_skill: bool = false) -> Hit:
	var h := Hit.new()
	var base := rng.randf_range(stats.min_damage, stats.max_damage) * mult
	if is_skill:
		base *= stats.skill_power
	base += stats.fire_damage * mult * (1.0 if element != "fire" else 1.25)
	h.crit = rng.randf() < stats.crit_chance
	if h.crit:
		base *= stats.crit_multiplier
	h.amount = maxf(1.0, base)
	h.element = element
	h.attacker_level = int(stats.get("level", 1))
	h.is_skill = is_skill
	return h


## Armor mitigation: armor / (armor + 50 + 10 * attacker_level), capped at 75%.
static func armor_reduction(armor: float, attacker_level: int) -> float:
	if armor <= 0.0:
		return 0.0
	return clampf(armor / (armor + 50.0 + 10.0 * attacker_level), 0.0, 0.75)


## Final damage a target takes from a hit.
static func mitigate(hit: Hit, armor: float, target_tags: Array = [], extra_reduction: float = 0.0) -> float:
	var dmg := hit.amount
	if hit.element == "physical":
		dmg *= 1.0 - armor_reduction(armor, hit.attacker_level)
	else:
		dmg *= 1.0 - armor_reduction(armor, hit.attacker_level) * 0.5
	if hit.element == "light" and "corrupted" in target_tags:
		dmg *= 1.25
	dmg *= 1.0 - clampf(extra_reduction, 0.0, 0.9)
	return maxf(1.0, roundf(dmg))
