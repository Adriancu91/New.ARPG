class_name UITheme
extends RefCounted
## Original dark-fantasy UI style: near-black panels, thin antique-gold
## borders, parchment text. Built in code so it is easy to tweak.

const BG := Color(0.045, 0.04, 0.055, 0.94)
const BG_SOFT := Color(0.08, 0.07, 0.09, 0.9)
const GOLD := Color(0.79, 0.64, 0.36)
const GOLD_DIM := Color(0.45, 0.37, 0.24)
const TEXT := Color(0.9, 0.86, 0.78)
const TEXT_DIM := Color(0.62, 0.58, 0.52)
const RED := Color(0.75, 0.16, 0.18)
const GOOD := Color(0.45, 0.9, 0.5)
const BAD := Color(0.95, 0.4, 0.4)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.93, 0.75))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_DIM * Color(1, 1, 1, 0.6))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("normal", "Button", button_style(Color(0.1, 0.085, 0.1), GOLD_DIM))
	t.set_stylebox("hover", "Button", button_style(Color(0.17, 0.13, 0.12), GOLD))
	t.set_stylebox("pressed", "Button", button_style(Color(0.24, 0.16, 0.12), GOLD))
	t.set_stylebox("disabled", "Button", button_style(Color(0.07, 0.065, 0.075), Color(0.25, 0.22, 0.2)))
	t.set_stylebox("focus", "Button", button_style(Color(0, 0, 0, 0), GOLD))
	var tip := panel_style()
	tip.bg_color = Color(0.03, 0.025, 0.035, 0.97)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.02, 0.02, 0.025, 0.9)
	bar_bg.border_color = GOLD_DIM
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("grabber_area", "HSlider", bar_bg)
	_theme = t
	return t


static func panel_style(border: Color = GOLD_DIM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 8
	return s


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func fill_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(2)
	return s


static func label(text: String, size: int = 17, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func title(text: String, size: int = 26) -> Label:
	var l := label(text, size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = min_w
	b.pressed.connect(func():
		Audio.play("ui_click")
		cb.call())
	return b


static func bar(fill: Color, size: Vector2) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = size
	p.add_theme_stylebox_override("fill", fill_style(fill))
	return p


static func separator() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = GOLD_DIM
	s.add_theme_stylebox_override("separator", sb)
	return s


## Rich multi-line item description, with comparison against `against`.
static func item_bbcode(it: Item, against: Item = null) -> String:
	if it == null:
		return ""
	var c := it.display_color().to_html(false)
	var out := "[font_size=19][color=#%s][b]%s[/b][/color][/font_size]\n" % [c, it.name]
	if it.is_equipment():
		var slot_txt := it.slot.capitalize()
		if it.weapon_type != "":
			slot_txt += " - " + it.weapon_type.replace("_", " ").capitalize()
		out += "[color=#%s]%s %s[/color]   [color=#9a9384]Item level %d[/color]\n" % [c, DB.rarity(it.rarity).name, slot_txt, it.item_level]
		if it.max_dmg > 0:
			out += "[font_size=18]Damage %d - %d[/font_size]%s\n" % [it.min_dmg, it.max_dmg, _delta((it.min_dmg + it.max_dmg) * 0.5, (against.min_dmg + against.max_dmg) * 0.5 if against != null else 0.0, against != null, false)]
		if it.armor > 0:
			out += "[font_size=18]Armor %d[/font_size]%s\n" % [it.armor, _delta(it.armor, against.armor if against != null else 0.0, against != null, false)]
		for k in it.implicit:
			out += "[color=#e8dcc0]%s[/color]\n" % Item.format_stat(k, it.implicit[k])
		for k in it.affixes:
			out += "[color=#8fb3ff]%s[/color]\n" % Item.format_stat(k, it.affixes[k])
		if against != null:
			var lost: Array = []
			for k in against.affixes:
				if not it.affixes.has(k):
					lost.append(Item.format_stat(k, against.affixes[k]))
			if not lost.is_empty():
				out += "[color=#e06a6a]Loses: %s[/color]\n" % ", ".join(lost)
		var ps := it.power_score()
		out += "\n[color=#c9a45c]Power %s[/color]" % ps
		if against != null:
			out += _delta(ps, against.power_score(), true, true)
		if Game.character and not Game.character.equipment.can_equip(it):
			out += "\n[color=#e06a6a]%s[/color]" % Game.character.equipment.why_cannot_equip(it)
		if it.lore != "":
			out += "\n\n[i][color=#b0a080]%s[/color][/i]" % it.lore
	else:
		if it.count > 1:
			out += "Quantity: %d\n" % it.count
		out += "[color=#b8b0a0]%s[/color]" % it.description()
		if it.kind == "quest_items":
			out += "\n[color=#ffd77a]Quest item[/color]"
	return out


static func _delta(mine: float, theirs: float, show: bool, is_power: bool) -> String:
	if not show:
		return ""
	var d := mine - theirs
	if absf(d) < 0.05:
		return "  [color=#9a9384](=)[/color]"
	var col := "#6fe07a" if d > 0 else "#e06a6a"
	var arrow := "▲" if d > 0 else "▼"
	return "  [color=%s]%s %+.1f%s[/color]" % [col, arrow, d, " (better)" if is_power and d > 0 else (" (worse)" if is_power else "")]
