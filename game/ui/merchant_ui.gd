class_name MerchantUI
extends GameWindow
## Buy from an NPC's stock, sell bag items, brew potions (crafting).

var npc: NPC
var stock_list: VBoxContainer
var sell_list: VBoxContainer
var info: RichTextLabel
var gold_label: Label


func _ready() -> void:
	setup_window("Trade", Vector2(980, 600))
	gold_label = T.label("", 16, Color(1, 0.85, 0.35))
	body.add_child(gold_label)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	h.add_child(left)
	left.add_child(T.label("For sale", 16, T.GOLD))
	stock_list = VBoxContainer.new()
	left.add_child(stock_list)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(300, 0)
	h.add_child(mid)
	mid.add_child(T.label("Sell from your bag", 16, T.GOLD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 470)
	mid.add_child(scroll)
	sell_list = VBoxContainer.new()
	scroll.add_child(sell_list)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.custom_minimum_size = Vector2(320, 470)
	h.add_child(info)


func start(n: NPC) -> void:
	npc = n
	npc.ensure_stock()
	title_label.text = "Trade - " + n.def.get("name", "")
	open()


func refresh() -> void:
	if npc == null or Game.character == null:
		return
	gold_label.text = "Your gold: %d" % Game.character.gold
	for c in stock_list.get_children():
		c.queue_free()
	for c in sell_list.get_children():
		c.queue_free()
	var potion_price := int(DB.stackable_def("potion_health").price)
	stock_list.add_child(T.button("Crimson Tincture  -  %d gold" % potion_price, func():
		if not npc.buy_potion():
			Events.notify.emit("Not enough gold", Color(1, 0.4, 0.4))
		else:
			Audio.play("gold")
		refresh()))
	var craft_cost := Crafting.RECIPES.potion_health
	var craft := T.button("Brew Tincture (3 Ash Shard, 1 Ember Dust, 5 gold)", func():
		if Crafting.craft(Game.character, "potion_health"):
			Audio.play("potion")
			Events.notify.emit("Brewed a Crimson Tincture", Color(1, 0.5, 0.5))
		refresh())
	craft.disabled = not Crafting.can_craft(Game.character, "potion_health")
	craft.tooltip_text = str(craft_cost)
	stock_list.add_child(craft)
	stock_list.add_child(T.separator())
	for it in npc.stock:
		var item: Item = it
		var b := T.button("%s  -  %d gold" % [item.name, NPC.price_of(item)], func():
			if not npc.buy(item):
				Events.notify.emit("Not enough gold or bag full", Color(1, 0.4, 0.4))
			else:
				Audio.play("gold")
			refresh())
		b.add_theme_color_override("font_color", item.display_color())
		b.mouse_entered.connect(func(): info.text = T.item_bbcode(item, Game.character.equipment.equipped_counterpart(item)))
		stock_list.add_child(b)
	for it in Game.character.inventory.items:
		var item: Item = it
		if item.kind == "quest_items":
			continue
		var b := T.button("%s%s  +%d" % [item.name, " x%d" % item.count if item.count > 1 else "", NPC.sell_price(item)], func():
			npc.sell(item)
			Audio.play("gold")
			refresh())
		b.add_theme_color_override("font_color", item.display_color())
		b.mouse_entered.connect(func(): info.text = T.item_bbcode(item, Game.character.equipment.equipped_counterpart(item)))
		sell_list.add_child(b)
