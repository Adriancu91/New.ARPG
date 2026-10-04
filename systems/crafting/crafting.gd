class_name Crafting
extends RefCounted
## Minimal crafting foundation: salvage unwanted equipment into materials and
## brew potions from them. Recipes are intentionally few; the API is the point.

const SALVAGE := {
	"common": {"ash_shard": 1},
	"uncommon": {"ash_shard": 2},
	"rare": {"ash_shard": 3, "ember_dust": 1},
	"epic": {"ember_dust": 3},
	"legendary": {"void_pearl": 1, "ember_dust": 4},
}

const RECIPES := {
	"potion_health": {"name": "Brew Crimson Tincture", "cost": {"ash_shard": 3, "ember_dust": 1}, "gold": 5, "amount": 1},
}


## Removes the item and adds materials. Returns the materials dict or {}.
static func salvage(inv: Inventory, uid: String) -> Dictionary:
	var it := inv.get_by_uid(uid)
	if it == null or not it.is_equipment():
		return {}
	var mats: Dictionary = SALVAGE.get(it.rarity, {})
	inv.remove(uid)
	for m in mats:
		inv.add(Item.make_stack(m, mats[m]))
	return mats


static func can_craft(cd: CharacterData, recipe_id: String) -> bool:
	var r: Dictionary = RECIPES.get(recipe_id, {})
	if r.is_empty() or cd.gold < int(r.gold):
		return false
	for m in r.cost:
		if cd.inventory.count_of(m) < int(r.cost[m]):
			return false
	return true


static func craft(cd: CharacterData, recipe_id: String) -> bool:
	if not can_craft(cd, recipe_id):
		return false
	var r: Dictionary = RECIPES[recipe_id]
	for m in r.cost:
		cd.inventory.consume(m, int(r.cost[m]))
	cd.gold -= int(r.gold)
	return cd.inventory.add(Item.make_stack(recipe_id, int(r.amount)))
