class_name DialogueUI
extends GameWindow
## NPC conversation window. Options come from data/npcs.json.

signal trade_requested(npc)

var npc: NPC
var text: RichTextLabel
var options: VBoxContainer
var current := ""


func _ready() -> void:
	setup_window("", Vector2(760, 360))
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(720, 120)
	body.add_child(text)
	body.add_child(T.separator())
	options = VBoxContainer.new()
	body.add_child(options)


func start(n: NPC) -> void:
	npc = n
	title_label.text = "%s, %s" % [n.def.get("name", ""), n.def.get("title", "")]
	open()
	show_node(n.start_node())


func show_node(node_id: String) -> void:
	current = node_id
	var nd := npc.node(node_id)
	text.text = "[color=#e8dcc0]%s[/color]" % nd.get("text", "")
	for c in options.get_children():
		c.queue_free()
	var i := 0
	for opt in nd.get("options", []):
		i += 1
		var o: Dictionary = opt
		var b := T.button("%d.  %s" % [i, o.text], func(): choose(o))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		options.add_child(b)
	_center()


## Selects a dialogue option (also used by automated tests).
func choose(opt: Dictionary) -> void:
	var nxt := npc.run_option(opt)
	if nxt == "trade":
		close()
		trade_requested.emit(npc)
	elif nxt == "":
		close()
	else:
		show_node(nxt)


func option_list() -> Array:
	return npc.node(current).get("options", [])
