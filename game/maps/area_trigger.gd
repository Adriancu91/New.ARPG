class_name AreaTrigger
extends Node3D
## Fires once when the player enters a radius: area discovery, boss arena, etc.

signal entered

var area_id := ""
var radius := 5.0
var display_name := ""
var once := true
var _fired := false


static func create(id: String, r: float, name_: String = "") -> AreaTrigger:
	var t := AreaTrigger.new()
	t.area_id = id
	t.radius = r
	t.display_name = name_
	return t


func _physics_process(_d: float) -> void:
	if _fired and once:
		return
	var p: Node3D = Game.player
	if p == null or not is_instance_valid(p) or not p.is_alive():
		return
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if d <= radius:
		_fired = true
		if area_id != "":
			if display_name != "" and not Game.world_list_has("discovered", area_id):
				Events.notify.emit("Discovered: " + display_name, Color(0.85, 0.8, 1.0))
			Events.area_discovered.emit(area_id)
		entered.emit()
