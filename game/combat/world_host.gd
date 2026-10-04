class_name WorldHost
extends RefCounted
## Where transient world objects (projectiles, loot, VFX) are parented:
## the active zone, so they are cleaned up automatically on zone change.


static func get_host(ctx: Node) -> Node:
	if Game.main != null and is_instance_valid(Game.main) and Game.main.get("zone") != null and is_instance_valid(Game.main.zone):
		return Game.main.zone
	if ctx != null and ctx.is_inside_tree():
		return ctx.get_tree().current_scene
	return null
