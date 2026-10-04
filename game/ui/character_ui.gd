class_name CharacterUI
extends GameWindow
## Attributes (spend points) and derived stats.

var info: Label
var attr_rows: Dictionary = {}
var points_label: Label
var derived: RichTextLabel

const ATTR_DESC := {
	"might": "Melee damage (Dawnwarden), +1 health per point",
	"agility": "Critical chance, attack speed, ranged & dual-blade damage",
	"spirit": "Resource pool and regeneration, skill power",
	"vitality": "+6 maximum health per point, health regeneration",
}


func _ready() -> void:
	setup_window("Character", Vector2(620, 600))
	info = T.label("", 17, T.TEXT)
	body.add_child(info)
	points_label = T.label("", 16, Color(0.6, 1.0, 0.6))
	body.add_child(points_label)
	for a in CharacterData.ATTRIBUTES:
		var row := HBoxContainer.new()
		var name_l := T.label(a.capitalize(), 18, T.GOLD)
		name_l.custom_minimum_size.x = 110
		row.add_child(name_l)
		var val := T.label("", 18)
		val.custom_minimum_size.x = 60
		row.add_child(val)
		var plus := T.button("+", func(): _spend(a))
		row.add_child(plus)
		var d := T.label(ATTR_DESC[a], 13, T.TEXT_DIM)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)
		body.add_child(row)
		attr_rows[a] = [val, plus]
	body.add_child(T.separator())
	derived = RichTextLabel.new()
	derived.bbcode_enabled = true
	derived.fit_content = true
	derived.custom_minimum_size = Vector2(560, 240)
	body.add_child(derived)
	Events.stats_changed.connect(func(): _maybe_refresh())


func _maybe_refresh() -> void:
	if visible:
		refresh()


func _spend(a: String) -> void:
	if Game.character.spend_attribute(a):
		Audio.play("ui_click")
	refresh()


func refresh() -> void:
	var cd := Game.character
	if cd == null:
		return
	var cls := cd.class_data()
	info.text = "%s, %s\n%s  -  Level %d  (%d / %d XP)" % [cd.hero_name, cls.title, cls.name, cd.level, cd.xp, Progression.xp_to_next(cd.level)]
	points_label.text = "Unspent attribute points: %d" % cd.attribute_points
	var s: Dictionary = Game.player.stats if Game.player else cd.compute_stats()
	for a in attr_rows:
		attr_rows[a][0].text = str(int(s[a]))
		attr_rows[a][1].disabled = cd.attribute_points <= 0
	var lines := [
		"[color=#c9a45c]Health[/color] %d     [color=#c9a45c]%s[/color] %d     [color=#c9a45c]Stamina[/color] %d" % [s.max_health, cls.resource_name, s.max_mana, s.max_stamina],
		"[color=#c9a45c]Weapon damage[/color] %d - %d   (+%d fire)" % [s.min_damage, s.max_damage, s.fire_damage],
		"[color=#c9a45c]Critical chance[/color] %.1f%%   x%.1f damage" % [s.crit_chance * 100.0, s.crit_multiplier],
		"[color=#c9a45c]Attack speed[/color] %.0f%%     [color=#c9a45c]Movement[/color] %.1f" % [s.attack_speed * 100.0, s.move_speed],
		"[color=#c9a45c]Armor[/color] %d   (%.0f%% physical reduction vs level %d)" % [s.armor, Damage.armor_reduction(s.armor, cd.level) * 100.0, cd.level],
		"[color=#c9a45c]Skill power[/color] %.0f%%     [color=#c9a45c]Life on hit[/color] %d" % [s.skill_power * 100.0, s.life_on_hit],
		"[color=#c9a45c]Regeneration[/color] %.1f health/s, %.1f %s/s" % [s.health_regen, s.mana_regen, cls.resource_name.to_lower()],
		"[color=#c9a45c]Kills[/color] %d     [color=#c9a45c]Gold[/color] %d" % [cd.kills, cd.gold],
	]
	derived.text = "\n".join(lines)
