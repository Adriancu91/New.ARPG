class_name Minimap
extends Control
## Lightweight 2D-drawn map (no extra render pass). Player-centred when small;
## whole zone when `full` (toggle with M).

var full := false
var view_radius := 42.0
var _t := 0.0

const POI_COLORS := {
	"npc": Color(1.0, 0.85, 0.3), "chest": Color(0.9, 0.6, 0.25), "dungeon": Color(0.5, 0.75, 1.0),
	"shrine": Color(1.0, 0.95, 0.7), "boss": Color(1.0, 0.2, 0.3), "exit": Color(0.5, 0.75, 1.0),
	"objective": Color(1.0, 0.8, 0.3), "ruin": Color(0.7, 0.7, 0.75), "camp": Color(1.0, 0.45, 0.25),
	"forest": Color(0.6, 0.4, 0.9), "bridge": Color(0.7, 0.7, 0.75),
}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.1:
		_t = 0.0
		queue_redraw()


func _world_to_map(p: Vector3, center: Vector2, scale_: float) -> Vector2:
	return size * 0.5 + (Vector2(p.x, p.z) - center) * scale_


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.04, 0.85))
	var main = Game.main
	if main == null or main.zone == null or not is_instance_valid(main.zone):
		return
	var zone: Zone = main.zone
	var player: Node3D = Game.player
	var center: Vector2
	var scale_: float
	if full or player == null or not is_instance_valid(player):
		center = zone.bounds.get_center()
		scale_ = minf(size.x / zone.bounds.size.x, size.y / zone.bounds.size.y) * 0.95
	else:
		center = Vector2(player.global_position.x, player.global_position.z)
		scale_ = size.x / (view_radius * 2.0)
	# zone bounds
	var tl := _world_to_map(Vector3(zone.bounds.position.x, 0, zone.bounds.position.y), center, scale_)
	draw_rect(Rect2(tl, zone.bounds.size * scale_), Color(0.12, 0.11, 0.12), false, 2.0)
	for poi in zone.points_of_interest:
		var mp := _world_to_map(poi.pos, center, scale_)
		var c: Color = POI_COLORS.get(poi.kind, Color.WHITE)
		if poi.kind in ["dungeon", "boss", "exit"]:
			draw_rect(Rect2(mp - Vector2(5, 5), Vector2(10, 10)), c)
		elif poi.kind == "npc":
			draw_circle(mp, 5.0, c)
		elif poi.kind == "chest":
			draw_rect(Rect2(mp - Vector2(3, 3), Vector2(6, 6)), c)
		else:
			draw_circle(mp, 3.5, c * Color(1, 1, 1, 0.8))
		if full and poi.label != "":
			draw_string(get_theme_default_font(), mp + Vector2(8, 4), poi.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive():
			var r := 5.0 if "boss" in e.tags else 2.5
			draw_circle(_world_to_map(e.global_position, center, scale_), r, Color(0.9, 0.2, 0.2))
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.item != null and p.item.is_equipment() and ItemGenerator.RARITY_ORDER.find(p.item.rarity) >= 2:
			draw_circle(_world_to_map(p.global_position, center, scale_), 2.5, p.item.display_color())
	if player != null and is_instance_valid(player):
		var pp := _world_to_map(player.global_position, center, scale_)
		var f: Vector3 = -player.global_transform.basis.z
		var fwd := Vector2(f.x, f.z).normalized()
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([pp + fwd * 8.0, pp - fwd * 5.0 + side * 5.0, pp - fwd * 5.0 - side * 5.0]), Color(1, 1, 1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.37, 0.24), false, 1.0)
