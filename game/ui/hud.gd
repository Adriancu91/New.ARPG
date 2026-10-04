class_name HUD
extends Control
## In-game heads-up display: vitals, XP, skill bar, minimap, quest tracker,
## boss bar, notifications, interaction prompt.

const T = preload("res://game/ui/ui_theme.gd")

var player: Player
var hp_bar: ProgressBar
var hp_label: Label
var res_bar: ProgressBar
var res_label: Label
var stam_bar: ProgressBar
var xp_bar: ProgressBar
var xp_label: Label
var level_label: Label
var gold_label: Label
var name_label: Label
var points_label: Label
var skill_slots: Array = []
var potion_label: Label
var prompt_label: Label
var notify_box: VBoxContainer
var quest_box: VBoxContainer
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_label: Label
var status_label: Label
var minimap: Minimap
var levelup_label: Label
var zone_label: Label
var _levelup_t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = T.theme()


func _ready() -> void:
	_build_vitals()
	_build_top_left()
	_build_minimap()
	_build_notifications()
	_build_boss_bar()
	_build_prompt()
	Events.notify.connect(notify)
	Events.leveled_up.connect(_on_level_up)
	Events.quest_updated.connect(func(_q): _refresh_quests())
	Events.quest_completed.connect(func(_q): _refresh_quests())
	Events.boss_health_changed.connect(_on_boss_health)
	Events.boss_encounter_started.connect(func(_n): boss_panel.visible = true)
	Events.boss_encounter_ended.connect(func(): get_tree().create_timer(3.0).timeout.connect(func(): boss_panel.visible = false))
	Events.xp_gained.connect(func(a): _xp_float(a))
	_refresh_quests()


func bind_player(p: Player) -> void:
	player = p
	res_bar.add_theme_stylebox_override("fill", T.fill_style(Color(p.data.class_data().resource_color)))
	_rebuild_skill_bar()
	_refresh_quests()
	boss_panel.visible = false


func _panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_vitals() -> void:
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.offset_left = -330
	bottom.offset_right = 330
	bottom.offset_top = -168
	bottom.offset_bottom = -10
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	status_label = T.label("", 15, Color(1, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	bottom.add_child(status_label)
	var panel := _panel()
	bottom.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	# health + resource side by side
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 10)
	v.add_child(bars)
	var hp_box := _bar_with_label(Color(0.72, 0.1, 0.12))
	hp_bar = hp_box[0]
	hp_label = hp_box[1]
	bars.add_child(hp_box[2])
	var res_box := _bar_with_label(Color(0.85, 0.7, 0.3))
	res_bar = res_box[0]
	res_label = res_box[1]
	bars.add_child(res_box[2])
	stam_bar = T.bar(Color(0.55, 0.75, 0.35), Vector2(0, 5))
	stam_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(stam_bar)
	# skill bar
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.name = "SkillRow"
	v.add_child(row)
	# xp
	var xp_row := HBoxContainer.new()
	v.add_child(xp_row)
	level_label = T.label("Lv 1", 15, T.GOLD)
	level_label.custom_minimum_size.x = 48
	xp_row.add_child(level_label)
	xp_bar = T.bar(Color(0.55, 0.4, 0.85), Vector2(0, 9))
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(xp_bar)
	xp_label = T.label("", 13, T.TEXT_DIM)
	xp_label.custom_minimum_size.x = 110
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_row.add_child(xp_label)


func _bar_with_label(c: Color) -> Array:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(300, 22)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := T.bar(c, Vector2(300, 22))
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(b)
	var l := T.label("", 14, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	holder.add_child(l)
	return [b, l, holder]


func _rebuild_skill_bar() -> void:
	var row: HBoxContainer = find_child("SkillRow", true, false)
	for c in row.get_children():
		c.queue_free()
	skill_slots.clear()
	if player == null:
		return
	var bar := player.data.hotbar_skills()
	for i in bar.size():
		var slot := _make_slot(str(i + 1), Icons.for_skill(bar[i]))
		slot.set_meta("skill", bar[i])
		slot.tooltip_text = "%s\n%s" % [DB.get_skill(bar[i]).name, DB.get_skill(bar[i]).desc]
		row.add_child(slot)
		skill_slots.append(slot)
	var potion := _make_slot("Q", Icons.for_item(Item.make_stack("potion_health")))
	potion.tooltip_text = "Crimson Tincture - restores 40% health"
	row.add_child(potion)
	potion_label = potion.get_node("Count")


func _make_slot(key: String, icon: Texture2D) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(54, 54)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	var tr := TextureRect.new()
	tr.texture = icon
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 3
	tr.offset_top = 3
	tr.offset_right = -3
	tr.offset_bottom = -3
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.name = "Icon"
	slot.add_child(tr)
	var cd := ColorRect.new()
	cd.name = "Cooldown"
	cd.color = Color(0, 0, 0, 0.7)
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cd)
	var k := T.label(key, 13, T.GOLD)
	k.position = Vector2(4, 1)
	k.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	k.add_theme_constant_override("outline_size", 4)
	slot.add_child(k)
	var cnt := T.label("", 15, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	cnt.name = "Count"
	cnt.set_anchors_preset(Control.PRESET_FULL_RECT)
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cnt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cnt.add_theme_constant_override("outline_size", 5)
	slot.add_child(cnt)
	return slot


func _build_top_left() -> void:
	var p := _panel()
	p.position = Vector2(14, 14)
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	name_label = T.label("", 19, T.GOLD)
	v.add_child(name_label)
	gold_label = T.label("", 15, Color(1.0, 0.85, 0.35))
	v.add_child(gold_label)
	points_label = T.label("", 14, Color(0.6, 1.0, 0.6))
	v.add_child(points_label)
	var help := T.label("I Inventory  C Character  K Skills  J Quests  M Map  Esc Menu", 12, T.TEXT_DIM)
	v.add_child(help)


func _build_minimap() -> void:
	var p := _panel()
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -244
	p.offset_right = -14
	p.offset_top = 14
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	zone_label = T.label("", 15, T.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(zone_label)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(206, 206)
	v.add_child(minimap)
	var qp := _panel()
	qp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	qp.anchor_left = 1.0
	qp.anchor_right = 1.0
	qp.offset_left = -330
	qp.offset_right = -14
	qp.offset_top = 290
	add_child(qp)
	quest_box = VBoxContainer.new()
	qp.add_child(quest_box)


func _build_notifications() -> void:
	notify_box = VBoxContainer.new()
	notify_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	notify_box.position = Vector2(18, 260)
	notify_box.custom_minimum_size = Vector2(520, 0)
	notify_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notify_box)
	levelup_label = T.title("", 44)
	levelup_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	levelup_label.anchor_left = 0.5
	levelup_label.anchor_right = 0.5
	levelup_label.offset_left = -400
	levelup_label.offset_right = 400
	levelup_label.offset_top = 150
	levelup_label.visible = false
	add_child(levelup_label)


func _build_boss_bar() -> void:
	boss_panel = _panel()
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.offset_left = -360
	boss_panel.offset_right = 360
	boss_panel.offset_top = 16
	add_child(boss_panel)
	var v := VBoxContainer.new()
	boss_panel.add_child(v)
	boss_label = T.title("", 21)
	v.add_child(boss_label)
	boss_bar = T.bar(Color(0.65, 0.08, 0.15), Vector2(690, 18))
	v.add_child(boss_bar)
	boss_panel.visible = false


func _build_prompt() -> void:
	prompt_label = T.label("", 18, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.offset_left = -300
	prompt_label.offset_right = 300
	prompt_label.offset_top = -220
	prompt_label.offset_bottom = -190
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 6)
	add_child(prompt_label)


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or Game.character == null:
		return
	var cd := Game.character
	hp_bar.max_value = player.max_health
	hp_bar.value = player.health
	hp_label.text = "%d / %d" % [ceili(player.health), roundi(player.max_health)]
	var cls := cd.class_data()
	res_bar.max_value = player.max_mana
	res_bar.value = player.mana
	res_label.text = "%s %d / %d" % [cls.resource_name, floori(player.mana), roundi(player.max_mana)]
	stam_bar.max_value = player.max_stamina
	stam_bar.value = player.stamina
	var need := Progression.xp_to_next(cd.level)
	xp_bar.max_value = need
	xp_bar.value = cd.xp
	xp_label.text = "%d / %d XP" % [cd.xp, need]
	level_label.text = "Lv %d" % cd.level
	name_label.text = "%s  -  %s" % [cd.hero_name, cls.name]
	gold_label.text = "Gold: %d" % cd.gold
	var pts := []
	if cd.attribute_points > 0:
		pts.append("%d attribute points (C)" % cd.attribute_points)
	if cd.skill_points > 0:
		pts.append("%d skill points (K)" % cd.skill_points)
	points_label.text = "  ".join(pts)
	for slot in skill_slots:
		var sid: String = slot.get_meta("skill")
		var sk := DB.get_skill(sid)
		var cdr: ColorRect = slot.get_node("Cooldown")
		var lbl: Label = slot.get_node("Count")
		var rank := cd.skill_rank(sid)
		var remaining: float = player.skill_cooldowns.get(sid, 0.0)
		if rank <= 0:
			cdr.anchor_top = 0.0
			cdr.color = Color(0, 0, 0, 0.8)
			lbl.text = "Lv%d" % int(sk.unlock_level) if cd.level < int(sk.unlock_level) else "+"
		elif remaining > 0.0:
			cdr.color = Color(0, 0, 0, 0.7)
			cdr.anchor_top = 1.0 - remaining / float(sk.cooldown)
			lbl.text = "%.1f" % remaining if remaining < 3.0 else str(ceili(remaining))
		else:
			cdr.anchor_top = 0.0
			cdr.color = Color(0.05, 0.1, 0.4, 0.55) if player.mana < float(sk.mana) else Color(0, 0, 0, 0)
			lbl.text = ""
	if potion_label:
		potion_label.text = str(cd.inventory.count_of("potion_health"))
	var it := player.nearest_interactable()
	prompt_label.text = "[E] " + it.get_prompt() if it != null else ""
	var st: Array = []
	for id in player.status.names():
		st.append(StatusEffects.DEFS[id].name)
	if player.blocking:
		st.append("Blocking")
	status_label.text = "  ".join(st)
	if _levelup_t > 0.0:
		_levelup_t -= delta
		levelup_label.modulate.a = clampf(_levelup_t, 0.0, 1.0)
		if _levelup_t <= 0.0:
			levelup_label.visible = false
	if Game.main and Game.main.zone:
		zone_label.text = Game.main.zone.display_name


func notify(text: String, color: Color = Color.WHITE) -> void:
	var l := T.label(text, 17, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	notify_box.add_child(l)
	while notify_box.get_child_count() > 7:
		notify_box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func _xp_float(amount: int) -> void:
	if amount >= 20:
		notify("+%d XP" % amount, Color(0.75, 0.6, 1.0))


func _on_level_up(lv: int) -> void:
	levelup_label.text = "LEVEL %d" % lv
	levelup_label.visible = true
	levelup_label.modulate.a = 1.0
	_levelup_t = 3.0
	notify("Level %d reached! +5 attribute points, +1 skill point" % lv, Color(1.0, 0.85, 0.4))
	if player:
		VFX.pillar(player, player.global_position, 1.2, 5.0, Color(1.0, 0.85, 0.4), 1.0)
		VFX.ring(player, player.global_position, 4.0, Color(1.0, 0.85, 0.4), 0.8)


func _on_boss_health(boss_name: String, cur: float, mx: float, phase: int) -> void:
	boss_panel.visible = cur > 0.0
	boss_label.text = boss_name + ("   -   ENRAGED" if phase >= 2 else "")
	boss_bar.max_value = mx
	boss_bar.value = cur


func _refresh_quests() -> void:
	if quest_box == null:
		return
	for c in quest_box.get_children():
		c.queue_free()
	quest_box.add_child(T.label("Quests", 16, T.GOLD))
	if Game.character == null:
		return
	var any := false
	for qid in Game.quests.active_quests():
		any = true
		var q := DB.get_quest(qid)
		var ready := Game.quests.state(qid) == QuestLog.READY
		quest_box.add_child(T.label(q.title + ("  (return to Ivenn)" if ready else ""), 15, Color(0.6, 1.0, 0.6) if ready else T.TEXT))
		for obj in q.objectives:
			var n := Game.quests.objective_count(qid, obj.id)
			var done := n >= int(obj.count)
			var txt := "  %s %s" % ["✓" if done else "-", obj.text]
			if int(obj.count) > 1:
				txt += " (%d/%d)" % [n, int(obj.count)]
			quest_box.add_child(T.label(txt, 13, T.TEXT_DIM if done else T.TEXT))
	if not any:
		var txt := "Speak to Brother Ivenn at the camp." if Game.quests.state("q_ashen_toll") == QuestLog.AVAILABLE else "The Vale is quiet... for now."
		quest_box.add_child(T.label(txt, 13, T.TEXT_DIM))
