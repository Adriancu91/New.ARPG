class_name GameWindow
extends PanelContainer
## Base for centered in-game windows (inventory, character, skills...).

const T = preload("res://game/ui/ui_theme.gd")

var body: VBoxContainer
var title_label: Label


func _init() -> void:
	theme = T.theme()
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup_window(title: String, min_size: Vector2) -> void:
	custom_minimum_size = min_size
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title_label = T.title(title, 24)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	head.add_child(T.button("X", close))
	v.add_child(T.separator())
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)


func open() -> void:
	visible = true
	_center()
	Audio.play("ui_open")
	refresh()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _center() -> void:
	reset_size()
	var vp := get_viewport_rect().size
	position = (vp - size) * 0.5


func refresh() -> void:
	pass
