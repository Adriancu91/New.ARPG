class_name QuestLog
extends RefCounted
## Quest state machine: available -> active -> ready (all objectives met)
## -> completed. Rewards are granted exactly once, guarded by `rewarded`.

signal quest_changed(quest_id: String)

const AVAILABLE := "available"
const ACTIVE := "active"
const READY := "ready"
const COMPLETED := "completed"

var states: Dictionary = {}      # quest_id -> state string
var progress: Dictionary = {}    # quest_id -> {objective_id: count}
var rewarded: Dictionary = {}    # quest_id -> true


func state(qid: String) -> String:
	return states.get(qid, AVAILABLE)


func is_active(qid: String) -> bool:
	return state(qid) == ACTIVE or state(qid) == READY


func accept(qid: String) -> bool:
	if DB.get_quest(qid).is_empty() or state(qid) != AVAILABLE:
		return false
	states[qid] = ACTIVE
	progress[qid] = {}
	for obj in DB.get_quest(qid).objectives:
		progress[qid][obj.id] = 0
	quest_changed.emit(qid)
	return true


func objective_count(qid: String, obj_id: String) -> int:
	return int(progress.get(qid, {}).get(obj_id, 0))


## Generic event entry point. type = kill/collect/explore/interact/boss.
## For "kill" targets are matched against the enemy's tags.
## Returns true if any quest changed.
func notify(type: String, targets: Array, amount: int = 1) -> bool:
	var any := false
	for qid in states.keys():
		if state(qid) != ACTIVE:
			continue
		var q := DB.get_quest(qid)
		var changed_q := false
		for obj in q.objectives:
			if obj.type != type or not (obj.target in targets):
				continue
			var cur := objective_count(qid, obj.id)
			var goal := int(obj.count)
			if cur >= goal:
				continue
			progress[qid][obj.id] = mini(goal, cur + amount)
			changed_q = true
		if changed_q:
			any = true
			_check_ready(qid)
			quest_changed.emit(qid)
	return any


## Collect objectives track what the player currently holds.
func sync_collect(qid: String, inventory: Inventory) -> void:
	if not is_active(qid):
		return
	var q := DB.get_quest(qid)
	var changed_q := false
	for obj in q.objectives:
		if obj.type != "collect":
			continue
		var have := mini(int(obj.count), inventory.count_of(obj.target))
		if have != objective_count(qid, obj.id):
			progress[qid][obj.id] = have
			changed_q = true
	if changed_q:
		var was := state(qid)
		states[qid] = ACTIVE
		_check_ready(qid)
		if was != state(qid) or changed_q:
			quest_changed.emit(qid)


func _check_ready(qid: String) -> void:
	if is_objectives_complete(qid):
		states[qid] = READY


func is_objectives_complete(qid: String) -> bool:
	var q := DB.get_quest(qid)
	if q.is_empty():
		return false
	for obj in q.objectives:
		if objective_count(qid, obj.id) < int(obj.count):
			return false
	return true


## Marks complete. Returns the reward dictionary the first time only,
## otherwise an empty dictionary (prevents duplicated rewards).
func complete(qid: String) -> Dictionary:
	if state(qid) != READY or rewarded.get(qid, false):
		return {}
	states[qid] = COMPLETED
	rewarded[qid] = true
	quest_changed.emit(qid)
	return DB.get_quest(qid).get("rewards", {})


func active_quests() -> Array:
	var out: Array = []
	for qid in states:
		if is_active(qid):
			out.append(qid)
	return out


func to_dict() -> Dictionary:
	return {"states": states.duplicate(true), "progress": progress.duplicate(true), "rewarded": rewarded.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	states = d.get("states", {}).duplicate(true)
	progress = {}
	var p: Dictionary = d.get("progress", {})
	for qid in p:
		progress[qid] = {}
		for oid in p[qid]:
			progress[qid][oid] = int(p[qid][oid])
	rewarded = d.get("rewarded", {}).duplicate(true)
