class_name ItemSlot
extends Button
## A clickable item cell (icon + count). Left click selects, right click /
## double click triggers the primary action. Hover previews the item.

signal selected(slot)
signal activated(slot)
signal hovered(slot)

var item: Item = null
var equip_slot := ""      # set for equipment-column slots
var _count: Label
var _icon: TextureRect
var _caption: Label


func _init() -> void:
	custom_minimum_size = Vector2(56, 56)
	focus_mode = Control.FOCUS_NONE
	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 4
	_icon.offset_top = 4
	_icon.offset_right = -4
	_icon.offset_bottom = -4
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = Label.new()
	_count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.position = Vector2(30, 34)
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_count.add_theme_constant_override("outline_size", 4)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 10)
	_caption.add_theme_color_override("font_color", Color(0.5, 0.46, 0.4))
	_caption.position = Vector2(4, 2)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	gui_input.connect(_on_input)
	mouse_entered.connect(func(): hovered.emit(self))
	pressed.connect(func(): selected.emit(self))


func set_item(it: Item, caption: String = "") -> void:
	item = it
	_icon.texture = Icons.for_item(it) if it else null
	_count.text = str(it.count) if it and it.count > 1 else ""
	_caption.text = caption if it == null else ""
	if it and it.is_equipment():
		var v := LootPickup.upgrade_verdict(it)
		if v > 0 and equip_slot == "":
			_count.text = "▲"
			_count.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5))
		elif v == -2:
			_icon.modulate = Color(1, 0.55, 0.55)
		else:
			_icon.modulate = Color.WHITE
	else:
		_icon.modulate = Color.WHITE
		_count.remove_theme_color_override("font_color")


func set_highlight(on: bool) -> void:
	if on:
		add_theme_stylebox_override("normal", UITheme.button_style(Color(0.2, 0.15, 0.1), UITheme.GOLD))
	else:
		remove_theme_stylebox_override("normal")


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_RIGHT or (ev.button_index == MOUSE_BUTTON_LEFT and ev.double_click):
			activated.emit(self)
			accept_event()
