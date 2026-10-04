class_name LootPickup
extends Node3D
## A dropped item or gold pile. Walk over it to collect. Shows a rarity-colored
## beam + name; equipment that beats what you wear is marked with an arrow.

const K = preload("res://game/characters/model_kit.gd")
const PICKUP_RADIUS := 1.25

var item: Item = null
var gold := 0
var persist_id := ""            # world-placed pickups remember being taken
var origin := ""                # e.g. "enemy:hollow_sentinel", "chest:chest_chapel", "boss:vorthane"
var _t := 0.0
var _label: Label3D
var _blocked_msg_t := 0.0
var _spawn_from := Vector3.ZERO
var _spawn_to := Vector3.ZERO
var _fly := 0.0


static func drop_bundle(ctx: Node, pos: Vector3, loot: Dictionary, big: bool = false, origin_: String = "") -> Array:
	var out: Array = []
	var n: int = loot.items.size() + (1 if loot.gold > 0 else 0)
	var i := 0
	var radius := 1.6 if big else 1.0
	if loot.gold > 0:
		out.append(spawn(ctx, pos, null, int(loot.gold), _scatter(i, n, radius, pos)))
		i += 1
	for it in loot.items:
		out.append(spawn(ctx, pos, it, 0, _scatter(i, n, radius, pos)))
		i += 1
	for p in out:
		p.origin = origin_
	return out


static func _scatter(i: int, n: int, r: float, pos: Vector3) -> Vector3:
	if n <= 1:
		return pos + Vector3(0.3, 0, 0.3)
	var a := TAU * float(i) / float(n) + 0.4
	return pos + Vector3(cos(a), 0, sin(a)) * r


static func spawn(ctx: Node, from: Vector3, it: Item, gold_amount: int, to = null) -> LootPickup:
	var p := LootPickup.new()
	p.item = it
	p.gold = gold_amount
	p.add_to_group("pickups")
	var host: Node = WorldHost.get_host(ctx)
	host.add_child(p)
	p._spawn_from = from
	p._spawn_to = to if to != null else from
	p._spawn_to.y = 0.0
	p.global_position = from
	p._build()
	if it != null and it.is_equipment() and ItemGenerator.RARITY_ORDER.find(it.rarity) >= 2:
		Audio.play("rare_drop", 0.0, -4.0)
	return p


func _build() -> void:
	var color := Color(1.0, 0.8, 0.3) if item == null else item.display_color()
	var body := MeshInstance3D.new()
	if item == null:
		body.mesh = K.cyl(0.22, 0.28, 0.12, 10)
		body.material_override = K.mat(Color(1.0, 0.8, 0.25), 0.8, 0.2, 1.0)
	elif item.is_equipment():
		body.mesh = K.box(Vector3(0.18, 0.5, 0.06)) if item.slot == "weapon" else K.box(Vector3(0.32, 0.22, 0.25))
		body.material_override = K.mat(color, 0.6, 0.3, 0.6)
	else:
		body.mesh = K.sphere(0.14)
		body.material_override = K.mat(color, 1.2, 0.3, 0.2)
	body.position.y = 0.25
	add_child(body)
	body.name = "Body"
	if item != null:
		var tier := ItemGenerator.RARITY_ORDER.find(item.rarity) if item.is_equipment() else (2 if item.kind == "quest_items" else 0)
		var beam := MeshInstance3D.new()
		beam.mesh = K.cyl(0.06, 0.12, 2.5 + tier * 0.8, 8)
		beam.material_override = K.glow_mat(color, 2.0, 0.35)
		beam.position.y = (2.5 + tier * 0.8) * 0.5
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		if tier >= 2:
			K.light(self, color, 0.8 + tier * 0.3, 3.5, Vector3(0, 0.8, 0))
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.pixel_size = 0.005
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.position.y = 1.0
	_label.render_priority = 6
	_label.modulate = color
	_label.text = label_text()
	add_child(_label)


## e.g. "Keen Vigil Longsword  [RARE]  ▲" — the arrow means it beats your gear.
func label_text() -> String:
	if item == null:
		return "%d Gold" % gold
	var txt := item.name
	if item.count > 1:
		txt += " x%d" % item.count
	if item.is_equipment():
		txt += "  [%s]" % DB.rarity(item.rarity).name.to_upper()
		var verdict := upgrade_verdict(item)
		if verdict > 0:
			txt += "  ▲"
		elif verdict == -2:
			txt += "  (other class)"
	return txt


## 1 = upgrade, 0 = not better, -2 = cannot equip.
static func upgrade_verdict(it: Item) -> int:
	if Game.character == null or it == null or not it.is_equipment():
		return 0
	var eq := Game.character.equipment
	if not eq.can_equip(it):
		return -2
	var cur := eq.equipped_counterpart(it)
	if cur == null:
		return 1
	return 1 if it.power_score() > cur.power_score() else 0


func _physics_process(delta: float) -> void:
	_t += delta
	if _fly < 1.0:
		_fly = minf(1.0, _fly + delta * 2.5)
		var p := _spawn_from.lerp(_spawn_to, _fly)
		p.y = sin(_fly * PI) * 1.2
		global_position = p
		return
	var body := get_node_or_null("Body")
	if body:
		body.rotation.y += delta * 1.5
		body.position.y = 0.25 + sin(_t * 3.0) * 0.06
	_blocked_msg_t = maxf(0.0, _blocked_msg_t - delta)
	var player: Node3D = Game.player
	if player == null or not is_instance_valid(player) or not player.is_alive():
		return
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if d <= PICKUP_RADIUS:
		collect()


func collect() -> bool:
	if is_queued_for_deletion():
		return false
	if item == null:
		Game.add_gold(gold)
		Audio.play("gold")
		Events.notify.emit("+%d Gold" % gold, Color(1.0, 0.85, 0.3))
		_taken()
		return true
	var desc := item.name + (" x%d" % item.count if item.count > 1 else "")
	if not Game.give_item(item):
		if _blocked_msg_t <= 0.0:
			Events.notify.emit("Inventory full", Color(1, 0.4, 0.4))
			_blocked_msg_t = 3.0
		return false
	Audio.play("pickup")
	var msg := "Picked up " + desc
	if item.is_equipment() and upgrade_verdict(item) > 0:
		msg += "  ▲ Upgrade! (I to equip)"
	Events.notify.emit(msg, item.display_color())
	_taken()
	return true


func _taken() -> void:
	if persist_id != "":
		Game.world_list_add("taken_pickups", persist_id)
	queue_free()
