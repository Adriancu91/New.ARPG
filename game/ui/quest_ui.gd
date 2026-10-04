class_name QuestUI
extends GameWindow
## Quest log: active, ready and completed quests with objectives.

var text: RichTextLabel


func _ready() -> void:
	setup_window("Quest Log", Vector2(680, 520))
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.custom_minimum_size = Vector2(640, 440)
	body.add_child(text)
	Events.quest_updated.connect(func(_q): _maybe_refresh())


func _maybe_refresh() -> void:
	if visible:
		refresh()


func refresh() -> void:
	var out := ""
	var any := false
	for qid in DB.quests:
		var st := Game.quests.state(qid)
		if st == QuestLog.AVAILABLE:
			continue
		any = true
		var q := DB.get_quest(qid)
		var tag: String = {"active": "[color=#e8c66a]ACTIVE[/color]", "ready": "[color=#6fe07a]COMPLETE - return to quest giver[/color]", "completed": "[color=#9a9384]COMPLETED[/color]"}.get(st, st)
		out += "[font_size=20][color=#c9a45c]%s[/color][/font_size]   %s\n" % [q.title, tag]
		out += "[color=#b8b0a0]%s[/color]\n" % q.description
		for obj in q.objectives:
			var n := Game.quests.objective_count(qid, obj.id)
			var done := n >= int(obj.count) or st == QuestLog.COMPLETED
			out += "  %s %s  (%d/%d)\n" % ["[color=#6fe07a]✓[/color]" if done else "[color=#e8c66a]•[/color]", obj.text, mini(n, int(obj.count)) if st != QuestLog.COMPLETED else int(obj.count), int(obj.count)]
		var r: Dictionary = q.rewards
		out += "[color=#9a9384]Rewards: %d XP, %d gold%s[/color]\n\n" % [int(r.get("xp", 0)), int(r.get("gold", 0)), ", items" if r.has("items") or r.has("random_item") else ""]
	if not any:
		out = "[color=#9a9384]No quests yet. Brother Ivenn waits by the campfire south of the ruins.[/color]"
	text.text = out
