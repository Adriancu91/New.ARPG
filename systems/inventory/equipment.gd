class_name Equipment
extends RefCounted
## Worn items. Moving items between Equipment and Inventory always transfers
## the same instance, so an item can never exist in two places at once.

signal changed

const SLOTS := ["weapon", "helmet", "armor", "gloves", "boots", "ring1", "ring2", "amulet"]

var slots: Dictionary = {}   # slot_id -> Item or null
var allowed_weapon_type: String = ""


func _init() -> void:
	for s in SLOTS:
		slots[s] = null


static func slot_label(slot_id: String) -> String:
	match slot_id:
		"ring1": return "Ring I"
		"ring2": return "Ring II"
	return slot_id.capitalize()


## Equip slot an item would go to, given current occupancy.
func target_slot(item: Item) -> String:
	if item == null or not item.is_equipment():
		return ""
	if item.slot == "ring":
		if slots.ring1 == null:
			return "ring1"
		if slots.ring2 == null:
			return "ring2"
		return "ring1"
	return item.slot


func can_equip(item: Item) -> bool:
	if item == null or not item.is_equipment():
		return false
	if item.slot == "weapon" and allowed_weapon_type != "" and item.weapon_type != allowed_weapon_type:
		return false
	return true


func why_cannot_equip(item: Item) -> String:
	if item == null or not item.is_equipment():
		return "Not equippable"
	if item.slot == "weapon" and allowed_weapon_type != "" and item.weapon_type != allowed_weapon_type:
		return "Your class cannot wield %s" % item.weapon_type.replace("_", " ")
	return ""


func get_item(slot_id: String) -> Item:
	return slots.get(slot_id)


## The item currently worn in the slot the given item would replace.
func equipped_counterpart(item: Item) -> Item:
	if item == null or not item.is_equipment():
		return null
	if item.slot == "ring":
		var a: Item = slots.ring1
		var b: Item = slots.ring2
		if a == null or b == null:
			return null
		return a if a.power_score() <= b.power_score() else b
	return slots.get(item.slot)


## Moves `item` out of `inv` into its slot; any previously worn item goes back
## to `inv`. Returns true on success.
func equip_from(inv: Inventory, item: Item, force_slot: String = "") -> bool:
	if not can_equip(item) or not inv.has_uid(item.uid):
		return false
	var slot := force_slot if force_slot != "" else target_slot(item)
	if item.slot == "ring" and force_slot == "":
		var counterpart := equipped_counterpart(item)
		if counterpart != null:
			slot = "ring1" if slots.ring1 == counterpart else "ring2"
	if not slots.has(slot):
		return false
	inv.remove(item.uid)
	var previous: Item = slots[slot]
	slots[slot] = item
	if previous != null:
		inv.add(previous)
	changed.emit()
	return true


func unequip_to(inv: Inventory, slot_id: String) -> bool:
	var it: Item = slots.get(slot_id)
	if it == null or inv.is_full():
		return false
	slots[slot_id] = null
	inv.add(it)
	changed.emit()
	return true


## Direct placement used when creating a new character or loading a save.
func set_slot(slot_id: String, item: Item) -> void:
	slots[slot_id] = item
	changed.emit()


func all_items() -> Array:
	var out: Array = []
	for s in SLOTS:
		if slots[s] != null:
			out.append(slots[s])
	return out


func total_stats() -> Dictionary:
	var total: Dictionary = {}
	for it in all_items():
		var block: Dictionary = it.stat_block()
		for k in block:
			if k == "min_dmg" or k == "max_dmg":
				continue
			total[k] = total.get(k, 0.0) + block[k]
	return total


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for s in SLOTS:
		out[s] = slots[s].to_dict() if slots[s] != null else null
	return out


func from_dict(d: Dictionary) -> void:
	for s in SLOTS:
		var v = d.get(s)
		slots[s] = Item.from_dict(v) if typeof(v) == TYPE_DICTIONARY else null
	changed.emit()
