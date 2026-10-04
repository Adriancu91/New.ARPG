class_name ItemGenerator
extends RefCounted
## Procedural equipment generation: base -> rarity -> affixes -> level scaling.

const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]


static func roll_rarity(rng: RandomNumberGenerator, min_rarity: String = "common", luck: float = 0.0) -> String:
	var rarities: Dictionary = DB.items.rarities
	var min_idx := RARITY_ORDER.find(min_rarity)
	var total := 0.0
	var weights: Array = []
	for i in RARITY_ORDER.size():
		var w := 0.0
		if i >= min_idx:
			w = float(rarities[RARITY_ORDER[i]].weight) * (1.0 + luck * i)
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in RARITY_ORDER.size():
		r -= weights[i]
		if r <= 0.0 and weights[i] > 0.0:
			return RARITY_ORDER[i]
	return RARITY_ORDER[maxi(min_idx, 0)]


## Pick a base appropriate for the item level. preferred_weapon biases weapon
## drops toward the player's class so loot is usually usable.
static func pick_base(rng: RandomNumberGenerator, item_level: int, preferred_weapon: String = "", slot: String = "") -> String:
	var candidates: Array = []
	var bases: Dictionary = DB.items.bases
	for id in bases:
		var b: Dictionary = bases[id]
		if b.get("starter", false):
			continue
		if int(b.level) > item_level:
			continue
		if slot != "" and b.slot != slot:
			continue
		candidates.append(id)
	if candidates.is_empty():
		return ""
	# explicit weapon request of a given type
	if slot == "weapon" and preferred_weapon != "":
		var typed := candidates.filter(func(id): return bases[id].get("weapon_type", "") == preferred_weapon)
		if not typed.is_empty():
			candidates = typed
	# weapon bias
	elif preferred_weapon != "" and slot == "" and rng.randf() < 0.35:
		var weapons := candidates.filter(func(id): return bases[id].get("weapon_type", "") == preferred_weapon)
		if not weapons.is_empty():
			candidates = weapons
	else:
		var non_foreign := candidates.filter(func(id):
			var wt: String = bases[id].get("weapon_type", "")
			return wt == "" or wt == preferred_weapon or preferred_weapon == "")
		if not non_foreign.is_empty() and rng.randf() < 0.8:
			candidates = non_foreign
	# Prefer the highest tier the level allows.
	candidates.sort_custom(func(a, b): return int(bases[a].level) > int(bases[b].level))
	if candidates.size() > 1 and rng.randf() < 0.6:
		var top_level := int(bases[candidates[0]].level)
		var top := candidates.filter(func(id): return int(bases[id].level) == top_level)
		return top[rng.randi() % top.size()]
	return candidates[rng.randi() % candidates.size()]


static func generate(rng: RandomNumberGenerator, item_level: int, rarity: String = "", preferred_weapon: String = "", slot: String = "", base_id: String = "") -> Item:
	if base_id == "":
		base_id = pick_base(rng, item_level, preferred_weapon, slot)
	var base := DB.item_base(base_id)
	if base.is_empty():
		return null
	if rarity == "":
		rarity = roll_rarity(rng)
	var rdef := DB.rarity(rarity)
	var it := Item.new()
	it.uid = Item.new_uid()
	it.base_id = base_id
	it.kind = "equipment"
	it.slot = base.slot
	it.weapon_type = base.get("weapon_type", "")
	it.rarity = rarity
	it.item_level = maxi(1, item_level)
	var lvl_scale := 1.0 + 0.08 * (it.item_level - 1)
	var mult: float = float(rdef.stat_mult) * lvl_scale
	if base.has("min_dmg"):
		it.min_dmg = roundf(float(base.min_dmg) * mult * rng.randf_range(0.95, 1.08))
		it.max_dmg = maxf(it.min_dmg + 1.0, roundf(float(base.max_dmg) * mult * rng.randf_range(0.95, 1.08)))
	if base.has("armor"):
		it.armor = roundf(float(base.armor) * mult * rng.randf_range(0.95, 1.1))
	_roll_affixes(rng, it, int(rdef.affixes))
	it.name = _compose_name(it, base.name)
	return it


static func _roll_affixes(rng: RandomNumberGenerator, it: Item, count: int) -> void:
	var pool: Array = []
	var affs: Dictionary = DB.items.affixes
	for id in affs:
		if it.slot in affs[id].slots:
			pool.append(id)
	for i in count:
		if pool.is_empty():
			break
		var id: String = pool[rng.randi() % pool.size()]
		pool.erase(id)
		var a: Dictionary = affs[id]
		var v: float = rng.randf_range(float(a.min), float(a.max)) + float(a.per_level) * (it.item_level - 1)
		if a.get("percent", false):
			v = snappedf(v, 0.005)
		else:
			v = roundf(v)
		it.affixes[id] = v


static func _compose_name(it: Item, base_name: String) -> String:
	if it.affixes.is_empty():
		return base_name
	var keys := it.affixes.keys()
	var first: Dictionary = DB.affix(keys[0])
	match it.rarity:
		"uncommon":
			return "%s %s" % [base_name, first.name] if first.name.begins_with("of") else "%s %s" % [first.name, base_name]
		_:
			var prefix := ""
			var suffix := ""
			for k in keys:
				var n: String = DB.affix(k).name
				if n.begins_with("of"):
					if suffix == "": suffix = n
				elif prefix == "":
					prefix = n
			var out := base_name
			if prefix != "": out = prefix + " " + out
			if suffix != "": out = out + " " + suffix
			return out


static func make_unique(unique_id: String, item_level: int) -> Item:
	var u: Dictionary = DB.items.uniques.get(unique_id, {})
	if u.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var it := generate(rng, item_level, "legendary", "", "", u.base)
	it.affixes.clear()
	for k in u.fixed:
		it.affixes[k] = float(u.fixed[k])
	it.unique_id = unique_id
	it.name = u.name
	it.lore = u.get("lore", "")
	it.rarity = u.get("rarity", "legendary")
	return it


static func make_starter(base_id: String) -> Item:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var base := DB.item_base(base_id)
	var it := Item.new()
	it.uid = Item.new_uid()
	it.base_id = base_id
	it.kind = "equipment"
	it.slot = base.slot
	it.weapon_type = base.get("weapon_type", "")
	it.rarity = "common"
	it.item_level = 1
	it.min_dmg = float(base.get("min_dmg", 0))
	it.max_dmg = float(base.get("max_dmg", 0))
	it.armor = float(base.get("armor", 0))
	it.name = base.name
	return it
