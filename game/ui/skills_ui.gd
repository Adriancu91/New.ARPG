class_name SkillsUI
extends GameWindow
## Learn and upgrade class skills with skill points.

var list: VBoxContainer
var points_label: Label


func _ready() -> void:
	setup_window("Skills", Vector2(760, 620))
	points_label = T.label("", 16, Color(0.6, 1.0, 0.6))
	body.add_child(points_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)


func refresh() -> void:
	var cd := Game.character
	if cd == null:
		return
	points_label.text = "Skill points: %d      (Hotkeys 1-5 follow the order of active skills below)" % cd.skill_points
	for c in list.get_children():
		c.queue_free()
	var hot := 0
	for sid in cd.class_data().skills:
		var sk := DB.get_skill(sid)
		var rank := cd.skill_rank(sid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.texture = Icons.for_skill(sid)
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.modulate = Color.WHITE if rank > 0 else Color(0.45, 0.45, 0.45)
		row.add_child(icon)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kind: String = sk.kind
		var key := ""
		if kind != "passive":
			hot += 1
			key = "[%d] " % hot
		var head := "%s%s   rank %d/%d" % [key, sk.name, rank, int(sk.max_rank)]
		if kind == "ultimate":
			head += "   ULTIMATE"
		elif kind == "passive":
			head += "   passive"
		v.add_child(T.label(head, 17, T.GOLD if rank > 0 else T.TEXT_DIM))
		var d := T.label(sk.desc, 13, T.TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 480
		v.add_child(d)
		if kind != "passive":
			v.add_child(T.label("Cost %d   Cooldown %.1fs   Damage x%.2f" % [int(sk.get("mana", 0)), float(sk.get("cooldown", 0)), SkillExecutor.damage_multiplier(sk, maxi(1, rank))], 12, T.TEXT_DIM))
		if cd.level < int(sk.unlock_level):
			v.add_child(T.label("Requires level %d" % int(sk.unlock_level), 12, T.BAD))
		row.add_child(v)
		var btn := T.button("Learn" if rank == 0 else "Upgrade", func():
			if Game.character.learn_skill(sid):
				Audio.play("level_up", 0.0, -8.0)
				Events.skills_changed.emit()
			refresh())
		btn.disabled = not cd.can_learn_skill(sid)
		row.add_child(btn)
		list.add_child(row)
		list.add_child(T.separator())
