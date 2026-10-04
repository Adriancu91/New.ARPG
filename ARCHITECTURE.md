# Architecture

Godot 4.3, GDScript only, no plugins or external dependencies. The guiding rule is **working simple systems that can grow**: content lives in JSON, rules live in plain `RefCounted` classes that are unit-testable without a scene tree, and nodes in `game/` only translate those rules into things you can see and touch.

```
                         data/*.json  (classes, skills, items, enemies, quests, npcs)
                               |
                               v
  autoloads:  InputSetup  Events  DB  Game  SaveSystem  Audio
                 |          |      |     |       |          |
                 |    signal bus   |  session state   JSON files in user://saves
                 v                 v     v
  systems/ (pure rules)    CharacterData, Inventory, Equipment, Item, ItemGenerator,
                           LootTable, Damage, StatusEffects, Progression, QuestLog, Crafting
                               |
                               v
  game/ (nodes)            Main -> Zone (ValeOfCinders | SunkenReliquary)
                                    -> Player, Enemy, BossVorthane, NPC, LootPickup, TreasureChest,
                                       ZoneGate, AreaTrigger, Projectile, AreaEffect, VFX
                           CanvasLayer -> HUD, Minimap, InventoryUI, CharacterUI, SkillsUI,
                                          QuestUI, DialogueUI, MerchantUI, Menus
```

## Folder map

| Path | Contents |
|---|---|
| `data/` | All content definitions. Adding a skill, item base, affix, enemy, quest or dialogue line is a JSON edit. |
| `systems/core/` | Autoloads: `input_setup.gd` (all bindings incl. gamepad), `events.gd` (signal bus), `database.gd` (`DB`), `game_state.gd` (`Game`). |
| `systems/combat/` | `Damage` (hit rolls, armor curve, elemental rules), `StatusEffects` (burn/chill/stun/buffs). |
| `systems/inventory/` | `Item`, `Inventory` (stacking, capacity, no duplicates), `Equipment` (slot rules, class weapon restriction). |
| `systems/loot/` | `ItemGenerator` (base → rarity → affixes → level scaling, uniques), `LootTable` (enemy/chest/boss tables, quest-aware drops). |
| `systems/progression/` | `Progression` (XP curve), `CharacterData` (all persistent hero state + derived stats). |
| `systems/quests/` | `QuestLog` state machine: available → active → ready → completed, rewards once. |
| `systems/crafting/` | Salvage + recipes (potion brewing). |
| `systems/save/` | `SaveSystem`: atomic JSON writes, manual + auto slots, latest-slot detection. |
| `systems/audio/` | `Audio`: buses, pooled players, music/ambience, procedural placeholder synthesis, file overrides. |
| `systems/tests/` | Unit test runner + suites, acceptance bot, class smoke test, benchmark, screenshot tour. |
| `game/characters/` | `Player`, `CameraRig`, `HumanoidRig` (procedural animation), `HeroModels`, `ModelKit`. |
| `game/enemies/`, `game/bosses/` | `Enemy` (data-driven AI), `EnemyModels`, `BeastRig`, `BossVorthane`. |
| `game/combat/` | `Combatant` base, `Projectile`, `AreaEffect` (telegraphs, traps), `VFX`, `FloatingText`, `CombatUtils`, `WorldHost`. |
| `game/skills/` | `SkillExecutor`: one behaviour per skill *type*. |
| `game/maps/` | `Zone` base, the two zones, props and interactables (chest, lore stone, brazier, gate, triggers). |
| `game/npc/`, `game/items/`, `game/ui/` | NPC dialogue/merchant, loot pickups, all UI. |

## Key flows

**Scene flow.** `game/main.tscn` (`main.gd`) owns the world container, camera, UI layer and menus. `change_zone(id, spawn)` frees the current `Zone`, instantiates the new one (`Main.ZONES` registry), spawns a fresh `Player` bound to the persistent `Game.character`, and autosaves. Transient objects (projectiles, loot, VFX) are parented to the active zone through `WorldHost`, so a zone change cleans everything up.

**Combat pipeline.** Attacker builds a `Damage.Hit` (amount, element, crit, knockback, status, source) → target `Combatant.take_hit()` → `Damage.mitigate()` (armor curve, elemental and light-vs-corrupted rules, buffs like Aegis) → health, knockback, status effects, hit flash, floating number → `source.on_hit_dealt()` (life on hit / life steal) → death → `Events.enemy_killed` → XP, quest progress, loot. Target queries (`CombatUtils.in_cone / in_radius / in_segment`) use group membership and flat distance: cheap, deterministic, and independent of physics layers.

**Skills.** `data/skills.json` entries name a `type`: `melee_cone`, `projectile`, `multi_projectile`, `aoe_target`, `aoe_self`, `dash_strike`, `buff`, `trap` (plus `passive` stat bonuses). `SkillExecutor` implements each type once; damage scales with rank (`rank_bonus`) and Spirit (`skill_power`). 20+ skills per class is therefore mostly data work.

**Enemy AI.** `Enemy` is a small state machine (IDLE wander → CHASE → WINDUP with a visible telegraph → attack → RECOVER, RETURN/leash). Archetype-specific steering (casters keep distance, assassins circle and lunge, heavies slam an area). Packs alert each other. `BossVorthane` extends `Enemy` with its own attack scheduler and phase logic.

**Derived stats.** `CharacterData.compute_stats(buffs)` merges class base, attributes, equipment (implicits + affixes), passive skills and active buffs into one dictionary used by the player, UI and comparison tooltips.

**Quests.** Game events (`enemy_killed` tags, `area_discovered`, `object_interacted`, `boss_defeated`, inventory changes) call `QuestLog.notify()` / `sync_collect()`. `Game.complete_quest()` grants rewards exactly once (guarded by `rewarded`), hands over quest items, sets unlock flags and auto-accepts the follow-up quest.

**Saving.** `Game.to_save_dict()` → `{version, character, quests, world{flags, opened_chests, discovered, interacted, taken_pickups}, zone, spawn, position, playtime}`. Written atomically (`.tmp` then rename) to `user://saves/slot_1.json` (manual) or `autosave.json`. On Windows `user://` is `%APPDATA%\Godot\app_userdata\Gloamreach\`.

## Extending the game

- **New class**: add an entry in `data/classes.json` (stats, palette, weapon type, skill list), skills in `data/skills.json`, a builder in `HeroModels.build()`, and an optional unique in `items.json → boss_uniques`.
- **New enemy**: add to `data/enemies.json` with an existing `archetype` (or a new one in `EnemyModels` + `Enemy._steer/_begin_attack`).
- **New region**: subclass `Zone`, build geometry/enemies in `build()`, register in `Main.ZONES`, connect with a `ZoneGate`.
- **New quest**: add to `data/quests.json` and give the NPC dialogue nodes with `accept:` / `complete:` actions.
- **Real art/audio**: replace `HeroModels` / `EnemyModels` builders with imported scenes exposing the same rig API (`play(action, duration)`, `move_ratio`, `die()`), and drop audio files named after sound ids into `audio/sfx` or `audio/music`.

## Testing architecture

| Layer | Entry point | What it proves |
|---|---|---|
| Parse check | `tools/check.sh` | every script compiles |
| Unit tests | `systems/tests/test_runner.tscn` | damage, health/death, status, XP/levels, attributes, item generation, rarity, uniques, inventory, equipment, loot tables, quests, save/load, data integrity |
| Acceptance | `systems/tests/acceptance/acceptance_bot.tscn -- --phase=1/2` | VS-001…VS-024 by playing the real game through input actions, in two OS processes, offline |
| Class smoke | `systems/tests/class_smoke.tscn` | every skill/attack of all three heroines |
| Benchmark | `systems/tests/benchmark.tscn` | frame cost in a 15+ enemy fight, memory/node stability across zone reloads |
| Visual | `systems/tests/screenshot_tour.tscn` | rendered screenshots of menus, zones, UI, boss |

`tools/run_acceptance.sh` runs everything and `tools/make_test_report.py` writes `TEST_REPORT.md` from the recorded JSON — no result is ever typed by hand.
