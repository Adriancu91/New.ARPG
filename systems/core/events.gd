extends Node
## Global signal bus. Systems emit here so UI, quests and audio can react
## without hard references to each other.

signal enemy_killed(enemy_id: String, tags: Array, xp: int, position: Vector3)
signal boss_defeated(boss_id: String)
signal player_damaged(amount: float)
signal player_died
signal player_respawned
signal xp_gained(amount: int)
signal leveled_up(new_level: int)
signal stats_changed
signal inventory_changed
signal equipment_changed
signal gold_changed(total: int)
signal item_picked_up(item)                     # Item
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal area_discovered(area_id: String)
signal object_interacted(object_id: String)
signal skill_used(skill_id: String)
signal skills_changed
signal notify(text: String, color: Color)       # on-screen toast
signal boss_health_changed(boss_name: String, current: float, maximum: float, phase: int)
signal boss_encounter_started(boss_name: String)
signal boss_encounter_ended
signal zone_changed(zone_id: String)
signal game_saved(slot: String)
signal game_loaded(slot: String)
signal dialogue_requested(npc)                  # NPC node
