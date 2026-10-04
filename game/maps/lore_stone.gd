class_name LoreStone
extends Interactable
## Environmental storytelling: readable inscriptions, graves, letters.

const K = preload("res://game/characters/model_kit.gd")

var title := ""
var text := ""


static func create(id: String, title_: String, text_: String, style: String = "stone") -> LoreStone:
	var s := LoreStone.new()
	s.object_id = id
	s.title = title_
	s.text = text_
	s.prompt = "Read"
	match style:
		"grave":
			K.part(s, K.box(Vector3(0.6, 0.9, 0.15)), K.mat(Color("#5a5a60"), 0.0, 0.9), Vector3(0, 0.45, 0), Vector3(0, 0, 4))
			K.part(s, K.box(Vector3(0.7, 0.08, 1.4)), K.mat(Color("#3a3226"), 0.0, 1.0), Vector3(0, 0.04, 0.8))
		"letter":
			K.part(s, K.box(Vector3(0.4, 0.02, 0.3)), K.mat(Color("#d8cfb0"), 0.2, 0.9), Vector3(0, 0.05, 0), Vector3(0, 20, 0))
			K.part(s, K.sphere(0.25), K.mat(Color("#bdb5a0"), 0.0, 0.6), Vector3(0.5, 0.15, 0.3), Vector3.ZERO, Vector3(1, 0.6, 1))
		_:
			K.part(s, K.box(Vector3(0.9, 1.6, 0.35)), K.mat(Color("#4a4852"), 0.0, 0.9), Vector3(0, 0.8, 0))
			K.part(s, K.box(Vector3(0.6, 0.7, 0.02)), K.glow_mat(Color(0.6, 0.8, 1.0), 1.2, 0.8), Vector3(0, 1.0, 0.18))
	K.light(s, Color(0.6, 0.75, 1.0), 0.4, 2.5, Vector3(0, 1.2, 0.6))
	return s


func interact(player) -> void:
	Events.notify.emit(title, Color(0.75, 0.85, 1.0))
	if Game.main and Game.main.has_method("show_lore"):
		Game.main.show_lore(title, text)
	super.interact(player)
