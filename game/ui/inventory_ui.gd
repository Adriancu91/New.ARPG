class_name InventoryUI
extends GameWindow
## Equipment column + 40-slot bag + detail/compare panel with actions.

var equip_slots: Dictionary = {}
var bag_slots: Array = []
var detail: RichTextLabel
var compare: RichTextLabel
var selected: Item = null
var selected_equip_slot := ""
var btn_equip: Button
var btn_discard: Button
var btn_salvage: Button
var stats_label: Label
var gold_label: Label


func _ready() -> void:
	setup_window("Inventory", Vector2(1180, 640))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	# equipment column
	var eq := VBoxContainer.new()
	h.add_child(eq)
	eq.add_child(T.label("Equipped", 16, T.GOLD))
	var grid_eq := GridContainer.new()
	grid_eq.columns = 2
	eq.add_child(grid_eq)
	for s in Equipment.SLOTS:
		var box := VBoxContainer.new()
		var slot := ItemSlot.new()
		slot.equip_slot = s
		slot.selected.connect(_on_select)
		slot.activated.connect(_on_activate)
		slot.hovered.connect(_on_hover)
		box.add_child(slot)
		box.add_child(T.label(Equipment.slot_label(s), 11, T.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		grid_eq.add_child(box)
		equip_slots[s] = slot
	stats_label = T.label("", 13, T.TEXT_DIM)
	eq.add_child(stats_label)
	# bag
	var bag := VBoxContainer.new()
	h.add_child(bag)
	var bag_head := HBoxContainer.new()
	bag.add_child(bag_head)
	bag_head.add_child(T.label("Bag", 16, T.GOLD))
	gold_label = T.label("", 15, Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_RIGHT)
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_head.add_child(gold_label)
	var grid := GridContainer.new()
	grid.columns = 8
	bag.add_child(grid)
	for i in 40:
		var slot := ItemSlot.new()
		slot.selected.connect(_on_select)
		slot.activated.connect(_on_activate)
		slot.hovered.connect(_on_hover)
		grid.add_child(slot)
		bag_slots.append(slot)
	bag.add_child(T.label("Left-click: select   Right-click / double-click: equip or use   ▲ = upgrade", 12, T.TEXT_DIM))
	# details
	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(360, 0)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(det)
	det.add_child(T.label("Selected", 14, T.GOLD))
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.custom_minimum_size = Vector2(340, 200)
	detail.scroll_active = false
	det.add_child(detail)
	det.add_child(T.separator())
	det.add_child(T.label("Currently equipped", 14, T.GOLD))
	compare = RichTextLabel.new()
	compare.bbcode_enabled = true
	compare.fit_content = true
	compare.custom_minimum_size = Vector2(340, 160)
	compare.scroll_active = false
	det.add_child(compare)
	var actions := HBoxContainer.new()
	det.add_child(actions)
	btn_equip = T.button("Equip", _primary_action)
	btn_discard = T.button("Discard", _discard)
	btn_salvage = T.button("Salvage", _salvage)
	btn_salvage.tooltip_text = "Break the item down into crafting materials."
	for b in [btn_equip, btn_discard, btn_salvage]:
		actions.add_child(b)
	Events.inventory_changed.connect(_maybe_refresh)
	Events.equipment_changed.connect(_maybe_refresh)


func _maybe_refresh() -> void:
	if visible:
		refresh()


func refresh() -> void:
	var cd := Game.character
	if cd == null:
		return
	for s in Equipment.SLOTS:
		equip_slots[s].set_item(cd.equipment.get_item(s), Equipment.slot_label(s))
		equip_slots[s].set_highlight(selected != null and cd.equipment.get_item(s) == selected)
	for i in bag_slots.size():
		var it: Item = cd.inventory.items[i] if i < cd.inventory.items.size() else null
		bag_slots[i].set_item(it)
		bag_slots[i].set_highlight(it != null and it == selected)
	if selected != null and not (cd.inventory.items.has(selected) or cd.equipment.all_items().has(selected)):
		selected = null
	gold_label.text = "Gold: %d" % cd.gold
	var s := cd.compute_stats()
	stats_label.text = "Damage %d-%d\nArmor %d\nCrit %.0f%%\nPower %.0f" % [s.min_damage, s.max_damage, s.armor, s.crit_chance * 100.0, cd.damage_rating()]
	_show(selected)


func _on_hover(slot: ItemSlot) -> void:
	if slot.item != null and selected == null:
		_show(slot.item)


func _on_select(slot: ItemSlot) -> void:
	selected = slot.item
	selected_equip_slot = slot.equip_slot
	refresh()


func _on_activate(slot: ItemSlot) -> void:
	selected = slot.item
	selected_equip_slot = slot.equip_slot
	_primary_action()


func _show(it: Item) -> void:
	var cd := Game.character
	if it == null:
		detail.text = "[color=#9a9384]Select an item to inspect it.[/color]"
		compare.text = ""
		btn_equip.disabled = true
		btn_discard.disabled = true
		btn_salvage.disabled = true
		return
	var worn := cd.equipment.all_items().has(it)
	var counterpart: Item = null if worn else cd.equipment.equipped_counterpart(it)
	detail.text = T.item_bbcode(it, counterpart)
	compare.text = T.item_bbcode(counterpart) if counterpart != null else ("[color=#9a9384]Nothing equipped in this slot.[/color]" if it.is_equipment() and not worn else "")
	btn_equip.disabled = false
	if worn:
		btn_equip.text = "Unequip"
	elif it.is_equipment():
		btn_equip.text = "Equip"
		btn_equip.disabled = not cd.equipment.can_equip(it)
	elif it.base_id == "potion_health":
		btn_equip.text = "Drink"
	else:
		btn_equip.text = "-"
		btn_equip.disabled = true
	btn_discard.disabled = worn or it.kind == "quest_items"
	btn_salvage.disabled = worn or not it.is_equipment()


func _primary_action() -> void:
	var cd := Game.character
	var it := selected
	if it == null:
		return
	if cd.equipment.all_items().has(it):
		var slot := ""
		for s in Equipment.SLOTS:
			if cd.equipment.get_item(s) == it:
				slot = s
		if not cd.equipment.unequip_to(cd.inventory, slot):
			Events.notify.emit("Bag is full", Color(1, 0.4, 0.4))
	elif it.is_equipment():
		if cd.equipment.equip_from(cd.inventory, it):
			Audio.play("pickup")
		else:
			Events.notify.emit(cd.equipment.why_cannot_equip(it), Color(1, 0.4, 0.4))
	elif it.base_id == "potion_health" and Game.player:
		Game.player.try_potion()
	refresh()


func _discard() -> void:
	if selected == null or selected.kind == "quest_items":
		return
	Game.character.inventory.remove(selected.uid)
	Events.notify.emit("Discarded " + selected.name, Color(0.7, 0.7, 0.7))
	selected = null
	refresh()


func _salvage() -> void:
	if selected == null:
		return
	var mats := Crafting.salvage(Game.character.inventory, selected.uid)
	if not mats.is_empty():
		var parts: Array = []
		for m in mats:
			parts.append("%d %s" % [mats[m], DB.stackable_def(m).name])
		Events.notify.emit("Salvaged into " + ", ".join(parts), Color(0.8, 0.8, 0.8))
		Audio.play("chest", 0.2, -6.0)
	selected = null
	refresh()
