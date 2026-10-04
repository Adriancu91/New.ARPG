extends Node
## Local JSON save files in user://saves/. No network, no cloud.
## Writes are atomic (temp file then rename) so a crash cannot corrupt a save.

const SAVE_DIR := "user://saves"
const MANUAL_SLOT := "slot_1"
const AUTO_SLOT := "autosave"
const AUTOSAVE_INTERVAL := 120.0

var save_dir: String = SAVE_DIR      # overridable for tests
var _autosave_timer := 0.0
var autosave_enabled := true


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)


func _process(delta: float) -> void:
	if not Game.in_game or not autosave_enabled or get_tree().paused:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		autosave()


func slot_path(slot: String) -> String:
	return "%s/%s.json" % [save_dir, slot]


func save_game(slot: String = MANUAL_SLOT) -> bool:
	if Game.character == null:
		return false
	DirAccess.make_dir_recursive_absolute(save_dir)
	var data := Game.to_save_dict()
	data["slot"] = slot
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: cannot open %s (%s)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open(save_dir)
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	var err := dir.rename(tmp.get_file(), path.get_file())
	if err != OK:
		push_error("Save failed: rename error %d" % err)
		return false
	_autosave_timer = 0.0
	Events.game_saved.emit(slot)
	return true


func autosave() -> bool:
	if not autosave_enabled:
		return false
	var ok := save_game(AUTO_SLOT)
	if ok:
		Events.notify.emit("Autosaved", Color(0.7, 0.7, 0.7))
	return ok


func read_save(slot: String) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Corrupted save: %s" % path)
		return {}
	return parsed


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## The most recent valid save across manual and autosave slots.
func latest_slot() -> String:
	var best := ""
	var best_time := -1
	for slot in [MANUAL_SLOT, AUTO_SLOT]:
		if not has_save(slot):
			continue
		var t := FileAccess.get_modified_time(slot_path(slot))
		if t > best_time:
			best_time = t
			best = slot
	return best


func load_game(slot: String) -> bool:
	var d := read_save(slot)
	if d.is_empty():
		return false
	var ok := Game.apply_save_dict(d)
	if ok:
		Events.game_loaded.emit(slot)
	return ok


func delete_save(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


func summary(slot: String) -> String:
	var d := read_save(slot)
	if d.is_empty():
		return ""
	var c: Dictionary = d.get("character", {})
	var cls := DB.get_class_data(c.get("class_id", ""))
	return "%s  -  %s Lv %d  -  %s" % [c.get("hero_name", "?"), cls.get("name", "?"), int(c.get("level", 1)), d.get("saved_at", "")]
