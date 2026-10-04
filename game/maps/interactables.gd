class_name Interactable
extends Node3D
## Base for things the player can press E on. Subclasses below.

var object_id := ""
var prompt := "Interact"


func _ready() -> void:
	add_to_group("interactable")


func can_interact() -> bool:
	return true


func interact(_player) -> void:
	Events.object_interacted.emit(object_id)


func get_prompt() -> String:
	return prompt
