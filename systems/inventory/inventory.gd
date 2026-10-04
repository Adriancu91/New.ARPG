class_name Inventory
extends RefCounted
## Bag of items with stacking and a fixed capacity.

signal changed

var capacity: int = 40
var items: Array = []   # Array[Item]


func is_full() -> bool:
	return items.size() >= capacity


## Adds an item. Stackables merge into existing stacks first.
## Returns true when the entire item was stored.
func add(item: Item) -> bool:
	if item == null:
		return false
	if item.is_stackable():
		var remaining := item.count
		for existing in items:
			if existing.base_id == item.base_id and existing.count < existing.max_stack:
				var space: int = existing.max_stack - existing.count
				var moved := mini(space, remaining)
				existing.count += moved
				remaining -= moved
				if remaining <= 0:
					break
		while remaining > 0:
			if is_full():
				item.count = remaining
				changed.emit()
				return false
			var stack := Item.make_stack(item.base_id, mini(remaining, item.max_stack))
			items.append(stack)
			remaining -= stack.count
		changed.emit()
		return true
	if is_full():
		return false
	for existing in items:
		if existing == item or existing.uid == item.uid:
			push_warning("Inventory: refusing to add duplicate item uid %s" % item.uid)
			return false
	items.append(item)
	changed.emit()
	return true


func get_by_uid(uid: String) -> Item:
	for it in items:
		if it.uid == uid:
			return it
	return null


func has_uid(uid: String) -> bool:
	return get_by_uid(uid) != null


## Removes a whole item (or `amount` from a stack). Returns the removed Item.
func remove(uid: String, amount: int = -1) -> Item:
	for i in items.size():
		var it: Item = items[i]
		if it.uid != uid:
			continue
		if it.is_stackable() and amount > 0 and amount < it.count:
			it.count -= amount
			changed.emit()
			var part := Item.make_stack(it.base_id, amount)
			return part
		items.remove_at(i)
		changed.emit()
		return it
	return null


func count_of(base_id: String) -> int:
	var n := 0
	for it in items:
		if it.base_id == base_id:
			n += it.count
	return n


## Consume `amount` of a stackable across stacks. Returns false if not enough.
func consume(base_id: String, amount: int) -> bool:
	if count_of(base_id) < amount:
		return false
	var left := amount
	for i in range(items.size() - 1, -1, -1):
		var it: Item = items[i]
		if it.base_id != base_id:
			continue
		var take := mini(left, it.count)
		it.count -= take
		left -= take
		if it.count <= 0:
			items.remove_at(i)
		if left <= 0:
			break
	changed.emit()
	return true


func clear() -> void:
	items.clear()
	changed.emit()


func to_array() -> Array:
	var out: Array = []
	for it in items:
		out.append(it.to_dict())
	return out


func from_array(arr: Array) -> void:
	items.clear()
	for d in arr:
		items.append(Item.from_dict(d))
	changed.emit()
