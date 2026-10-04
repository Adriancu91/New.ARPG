# TEST_REPORT

Build: **0.1.0** (git `3298fb8`)  
Engine: 4.3-stable (official)  
Date of run: 2026-10-04  
Environment: Linux x86_64 VM, headless (dummy renderer) for gameplay tests; automated player = `systems/tests/acceptance/acceptance_bot.gd`.

Every result below was produced by an actual execution of the game. Raw outputs: `systems/tests/output/` (unit_results.json, acceptance_phase1.json, acceptance_phase2.json, offline_evidence.json, perf_*.json, *.log). Re-run everything with `tools/run_acceptance.sh`.

## Summary

| Metric | Value |
|---|---|
| Acceptance tests PASS | 24 / 25 |
| FAIL | 0  |
| BLOCKED | 1 (VS-025) |
| **Acceptance Score** (PASS / executable) | **100.0%** (24/24) |
| Critical tests passing | 20 / 20 |
| Unit tests | 42 passed, 0 failed |

**VERTICAL SLICE = ACCEPTED**

VS-025 is not a critical test. It is BLOCKED (not PASS): GPU performance on a mid-range PC still has to be measured on real hardware.

## Acceptance tests

### VS-001 - Game Launch (critical)
- **Test ID:** VS-001
- **Description:** Game Launch
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Main menu shown on boot with New Game enabled; gameplay reached (zone 'vale_of_cinders' loaded, player spawned).
- **Known Issues:** Executed on Linux headless (Godot 4.3) - the Windows build was not launched on Windows hardware.

### VS-002 - Character Selection (critical)
- **Test ID:** VS-002
- **Description:** Character Selection
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Selected Dawnwarden -> Seraphine Vael (Dawnwarden), Lv 1, HP 204/204, Radiance 90, weapon 'Worn Oathblade', zone vale_of_cinders.
- **Known Issues:** None observed.

### VS-003 - Movement (critical)
- **Test ID:** VS-003
- **Description:** Movement
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** WASD input actions: velocity after 1 frame(s); walked 19.4 m south and was stopped by the boundary wall at z=63.40 (wall 66.0); moved back north/left/right freely; camera focus offset 0.00 m while moving, 0.11 m at rest.
- **Known Issues:** None observed.

### VS-004 - Basic Combat (critical)
- **Test ID:** VS-004
- **Description:** Basic Combat
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Killed a Hollowed Sentinel with basic attacks (LMB action) only: 5 hits landed, health 60 -> 0, 6 floating damage numbers present, hit flash + knockback applied.
- **Known Issues:** None observed.

### VS-005 - Skill (critical)
- **Test ID:** VS-005
- **Description:** Skill
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Key 1 cast Radiant Cleave (Light cone): [30] skill damage to the target, resource 90.0 -> 78.0 (cost 12, minus regen), cooldown 2.50s started and blocked immediate re-use; key 2 cast Aegis of Dawn (damage-reduction buff active=true).
- **Known Issues:** None observed.

### VS-006 - Dodge
- **Test ID:** VS-006
- **Description:** Dodge
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Space: dodge moved 5.77 m in 0.32s, i-frames 0.22s then ended, 22 stamina spent, instant re-dodge refused. Spamming dodge for 6 s kept the player invulnerable only 24% of frames (cooldown + stamina gate).
- **Known Issues:** None observed.

### VS-007 - Enemy AI (critical)
- **Test ID:** VS-007
- **Description:** Enemy AI
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Sentinel idle while player was 15 m away (aggro=false); detected the player at 8.4 m (detect radius 13), closed from 8.5 m to 2.2 m, telegraphed and landed 2 hit(s) (HP 204 -> 181); AI states observed: ["CHASE", "WINDUP", "RECOVER"]; it was then killed (died=true). Hit detail: ["dist 2.2 state WINDUP frame 1090 kb 5.0", "dist 0.2 state WINDUP frame 1214 kb 5.0"]
- **Known Issues:** None observed.

### VS-008 - XP (critical)
- **Test ID:** VS-008
- **Description:** XP
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Killing the sentinel awarded 25 XP (expected 25 from data: base 25, enemy Lv 1 vs player Lv 1); total XP 0 -> 25; HUD XP bar shows 25 == character XP 25.
- **Known Issues:** None observed.

### VS-009 - Level Up (critical)
- **Test ID:** VS-009
- **Description:** Level Up
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Kill granting 20 XP took the hero from 95 XP (Lv 1, threshold 100) to Lv 2 with 15 XP carried over; 'LEVEL 2' banner shown=true; attribute points 0 -> 5, skill points 0 -> 1; max health 204 -> 213; health refilled=true.
- **Known Issues:** None observed.

### VS-010 - Loot (critical)
- **Test ID:** VS-010
- **Description:** Loot
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Enemy drop 'Vigil Longsword' [common, base sword_vigil, ilvl 1] from enemy:hollow_sentinel: pickup showed rarity beam + name label, walked over it -> in inventory. Total pickups collected in this fight: 3 (2 equipment).
- **Known Issues:** None observed.

### VS-011 - Inventory (critical)
- **Test ID:** VS-011
- **Description:** Inventory
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Pressed I: window open=true, 9 bag items shown in the grid with icons; selecting the looted item shows: "Worn Oathblade / Common Weapon - Sword   Item level 1 / Damage 8 - 12  ▼ -2.5 /  / Power 20  ▼ -5.0 (worse)"
- **Known Issues:** None observed.

### VS-012 - Equipment (critical)
- **Test ID:** VS-012
- **Description:** Equipment
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Equipped 'Vigil Longsword' into weapon via inventory right-click. 'Vigil Longsword' returned to the bag (bag size unchanged). Damage 13-20 -> 13-19, armor 15 -> 15, max health 237 -> 237; live player stats updated=true; duplicate uids=false.
- **Known Issues:** None observed.

### VS-013 - Item Comparison
- **Test ID:** VS-013
- **Description:** Item Comparison
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Selected 'Vigil Longsword' in the bag while wearing 'Vigil Longsword': the selected panel shows per-stat deltas and a verdict ("Vigil Longsword / Common Weapon - Sword   Item level 1 / Damage 10 - 15  ▲ +0.5 /  / Power 25  ▲ +1.0 (better)"); the 'Currently equipped' panel shows 'Vigil Longsword'.
- **Known Issues:** None observed.

### VS-014 - Quest Start (critical)
- **Test ID:** VS-014
- **Description:** Quest Start
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Pressed E near Brother Ivenn -> dialogue 'intro' -> 'offer' -> accepted. State=active. Quest log lists 'The Ashen Toll'; HUD tracker: Quests | The Ashen Toll |   - Put down Hollowed Sentinels (0/5) |   - Recover Reliquary Lamp Fragments (0/3) |   - Find the Shrine of the Broken Saint | 
- **Known Issues:** None observed.

### VS-015 - Quest Progression
- **Test ID:** VS-015
- **Description:** Quest Progression
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Objectives advanced by gameplay: kills 5/5, kills 5/5, shrine explored=true, fragments 4/3, fragments 5/3. Mid-quest save contained the live kill count=true. State now 'ready'.
- **Known Issues:** None observed.

### VS-016 - Quest Completion (critical)
- **Test ID:** VS-016
- **Description:** Quest Completion
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Turned in at Ivenn (node 'toll_done'): +260 XP (Lv 3 -> 3), +75 gold, potions 8 -> 11, random rare item granted (bag 12 -> 12 items), fragments consumed; second completion attempt returned false with no extra gold; Reliquary unsealed; follow-up quest active; completion + rewarded flag present in save=true.
- **Known Issues:** None observed.

### VS-017 - Dungeon (critical)
- **Test ID:** VS-017
- **Description:** Dungeon
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Gate open after quest=true; pressed E -> zone 'sunken_reliquary' loaded, player at entrance with HP 376/376, 13 enemies + boss spawned; 'Descend' objective updated=true.
- **Known Issues:** None observed.

### VS-018 - Boss (critical)
- **Test ID:** VS-018
- **Description:** Boss
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Entered arena -> boss bar shown=true; boss cast 20 telegraphed area attacks + 7 projectiles; boss hit the player 11 time(s); player damaged boss=true; phase 2 (enrage + summons) reached=true; boss HP trace ["100%", "79%", "58%", "48%", "39%", "17%"]; attempts=1, player deaths so far=0.
- **Known Issues:** None observed.

### VS-019 - Boss Defeat (critical)
- **Test ID:** VS-019
- **Description:** Boss Defeat
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Vorthane died: victory banner=true, encounter ended (bar hidden=true), exit portal spawned=true; unique 'Dawnbreaker, Oath of Vorthane's Ruin' dropped and collected=true; world flag boss_defeated_vorthane=true; quest 'The Hollow Bishop' -> ready (objectives {"enter_reliquary":1,"light_brazier":1,"slay_bishop":1}).
- **Known Issues:** None observed.

### VS-020 - Save (critical)
- **Test ID:** VS-020
- **Description:** Save
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Esc -> Save Game wrote user://saves/slot_1.json (13864 bytes): character Seraphine Vael Lv 5, 794 XP, 609 gold, 20 bag items, 8 equipped, skills {"aegis_of_dawn":1,"ascendant_wrath":0,"celestial_ward":0,"dawnblade_discipline":0,"judgment_circle":1,"radiant_cleave":2,"sunlance":1}, quests {"q_ashen_toll":"completed","q_hollow_bishop":"ready"}, world flags {"boss_defeated_vorthane":true,"reliquary_unsealed":true}, zone sunken_reliquary.
- **Known Issues:** None observed.

### VS-021 - Load (critical)
- **Test ID:** VS-021
- **Description:** Load
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Fresh process: main menu 'Continue' enabled (latest slot 'slot_1'), loaded into zone 'sunken_reliquary'. Compared 16 saved fields (character, level, XP, gold, inventory uids, equipment uids, skills, attributes, quests, world flags/chests/discoveries, zone): mismatches=[].
- **Known Issues:** None observed.

### VS-022 - Offline (critical)
- **Test ID:** VS-022
- **Description:** Offline
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Both acceptance processes ran under `unshare -rn` (network namespace with interfaces: 'lo'; internet probe from inside: unreachable: gaierror). Launch, gameplay, combat, inventory, quests and save/load tests passed in that environment (VS-001, VS-003, VS-004, VS-011, VS-014, VS-016, VS-020, VS-021). Static scan for networking APIs in game code: no matches .
- **Known Issues:** Verified on Linux; Windows offline behaviour is expected to be identical (no network code exists) but was not run on Windows.

### VS-023 - Restart Persistence
- **Test ID:** VS-023
- **Description:** Restart Persistence
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** Phase 1 process saved and exited with code 0; phase 2 is a new OS process that restarted the game and loaded: Lv 5, 794 XP, 609 gold, 20 items, quests {"q_ashen_toll":"completed","q_hollow_bishop":"ready"} - identical to the pre-exit snapshot.
- **Known Issues:** None observed.

### VS-024 - Complete Playthrough (critical)
- **Test ID:** VS-024
- **Description:** Complete Playthrough
- **Result:** PASS
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** New game -> character -> world -> combat -> loot -> quest -> dungeon -> boss -> boss loot -> save -> exit (process 1, exit code 0, 298 s of simulated play) -> restart -> load -> continue (process 2, exit code 0): returned to the Vale and turned in the final quest (completed=True). Script errors in logs: 0. Player deaths: 0 (respawn works). Duplicate rewards: none (checked in VS-012/VS-016). Navigation fallbacks (bot teleports): 0.
- **Known Issues:** Driven by an automated player (acceptance_bot.gd); aiming uses a scripted target point instead of a physical mouse.

### VS-025 - Performance
- **Test ID:** VS-025
- **Description:** Performance
- **Result:** BLOCKED
- **Build:** 0.1.0
- **Date:** 2026-10-04
- **Notes:** No representative mid-range gaming PC/GPU available in the build environment, so GPU frame rate could not be measured. Measured instead - CPU cost per frame (headless, Intel(R) Xeon(R) Processor @ 2.10GHz, 2 cores) during a fight with 15+ enemies: avg 2.59 ms, p99 5.05 ms, max 12.34 ms (budget 16.7 ms); zone load 74 ms; memory over 6 zone-load+combat cycles: 55.07, 59.48, 54.95, 59.48, 55.4, 59.73 MB (stable=True, orphan nodes 0). Software-rendered run (Mesa llvmpipe on CPU, not a GPU) reached 7.5 fps - not representative.
- **Known Issues:** Must be re-run with tools/run_acceptance.sh (benchmark step) on a mid-range Windows PC with a real GPU.


## Unit tests

Runner: `godot --headless res://systems/tests/test_runner.tscn` - 42 passed, 0 failed (2026-10-04T18:50:10).

| Suite | Test | Result |
|---|---|---|
| test_damage | test_armor_reduction_curve | PASS |
| test_damage | test_mitigate_physical_and_light_bonus | PASS |
| test_damage | test_roll_player_crit_and_range | PASS |
| test_damage | test_combatant_health_and_death | PASS |
| test_damage | test_burn_status_deals_damage_over_time | PASS |
| test_damage | test_stun_and_chill_speed | PASS |
| test_progression | test_xp_curve_monotonic | PASS |
| test_progression | test_level_up_with_overflow | PASS |
| test_progression | test_character_level_up_grants_points_and_stats | PASS |
| test_progression | test_spend_attributes | PASS |
| test_progression | test_enemy_xp_scaling | PASS |
| test_items | test_generation_is_valid_for_all_rarities | PASS |
| test_items | test_rarity_roll_distribution | PASS |
| test_items | test_higher_rarity_has_more_power_on_average | PASS |
| test_items | test_unique_items | PASS |
| test_items | test_item_serialization_roundtrip | PASS |
| test_items | test_jewelry_has_implicit_stats | PASS |
| test_inventory | test_stacking | PASS |
| test_inventory | test_stack_overflow_creates_new_stack | PASS |
| test_inventory | test_capacity_and_duplicates | PASS |
| test_inventory | test_remove_and_partial_stack_remove | PASS |
| test_inventory | test_salvage_and_craft | PASS |
| test_equipment | test_equip_swaps_without_duplication | PASS |
| test_equipment | test_unequip | PASS |
| test_equipment | test_class_weapon_restriction | PASS |
| test_equipment | test_rings_fill_both_slots | PASS |
| test_equipment | test_armor_item_increases_armor | PASS |
| test_equipment | test_comparison_counterpart | PASS |
| test_loot | test_enemy_loot_valid | PASS |
| test_loot | test_quest_fragment_drops_only_when_needed | PASS |
| test_loot | test_chest_loot_min_uncommon | PASS |
| test_loot | test_boss_loot_has_unique | PASS |
| test_quests | test_quest_lifecycle | PASS |
| test_quests | test_rewards_granted_once | PASS |
| test_quests | test_quest_serialization | PASS |
| test_quests | test_boss_and_interact_objectives | PASS |
| test_save | test_save_load_roundtrip | PASS |
| test_save | test_missing_or_corrupt_save | PASS |
| test_skills_data | test_classes_reference_valid_data | PASS |
| test_skills_data | test_skill_types_are_supported | PASS |
| test_skills_data | test_quest_targets_exist | PASS |
| test_skills_data | test_five_enemy_archetypes_and_boss | PASS |

## Windows build check (exported .exe under Wine)

The exported Windows binary (`Gloamreach_test.exe`, Godot 4.3 Windows release template + test scenes) was executed under Wine on Linux, offline, running the same two-process acceptance playthrough: **22/22 PASS**. Wine is a compatibility layer, not real Windows; a run on Windows hardware is still required.

| Test | Result (Wine) |
|---|---|
| VS-001 | PASS |
| VS-002 | PASS |
| VS-003 | PASS |
| VS-014 | PASS |
| VS-007 | PASS |
| VS-004 | PASS |
| VS-008 | PASS |
| VS-005 | PASS |
| VS-006 | PASS |
| VS-009 | PASS |
| VS-010 | PASS |
| VS-011 | PASS |
| VS-012 | PASS |
| VS-013 | PASS |
| VS-015 | PASS |
| VS-016 | PASS |
| VS-017 | PASS |
| VS-018 | PASS |
| VS-019 | PASS |
| VS-020 | PASS |
| VS-021 | PASS |
| VS-023 | PASS |

## Additional verification: all three heroines

`systems/tests/class_smoke.tscn` casts every hotbar skill plus basic and heavy attacks for each class against a target. All pass: **True**.

| Heroine | Action | Executed | Damage | Result |
|---|---|---|---|---|
| dawnwarden | aegis_of_dawn | True | 0 | PASS |
| dawnwarden | ascendant_wrath | True | 66 | PASS |
| dawnwarden | basic_attack | True | 9 | PASS |
| dawnwarden | heavy_attack | True | 22 | PASS |
| dawnwarden | judgment_circle | True | 41 | PASS |
| dawnwarden | radiant_cleave | True | 51 | PASS |
| dawnwarden | sunlance | True | 23 | PASS |
| hellbrand | basic_attack | True | 11 | PASS |
| hellbrand | brimstone_nova | True | 34 | PASS |
| hellbrand | demonform | True | 0 | PASS |
| hellbrand | heavy_attack | True | 26 | PASS |
| hellbrand | hellfire_orb | True | 27 | PASS |
| hellbrand | infernal_flurry | True | 65.4 | PASS |
| hellbrand | shadowstep | True | 21.7 | PASS |
| starweaver | arcane_shot | True | 42 | PASS |
| starweaver | basic_attack | True | 12 | PASS |
| starweaver | frost_snare | True | 29 | PASS |
| starweaver | gale_leap | True | 0 | PASS |
| starweaver | heavy_attack | True | 18 | PASS |
| starweaver | split_volley | True | 66 | PASS |
| starweaver | starfall | True | 72 | PASS |

## Playthrough log (phase 1, abridged)

```
[sim    0.2s | wall   0.2s] Main menu visible=true, New Game available=true
[sim    0.8s | wall   0.4s] PASS  VS-001  Game Launch  -- Main menu shown on boot with New Game enabled; gameplay reached (zone 'vale_of_cinders' loaded, player spawned).
[sim    0.8s | wall   0.4s] PASS  VS-002  Character Selection  -- Selected Dawnwarden -> Seraphine Vael (Dawnwarden), Lv 1, HP 204/204, Radiance 90, weapon 'Worn Oathblade', zone vale_of_cinders.
[sim    8.6s | wall   1.6s] PASS  VS-003  Movement  -- WASD input actions: velocity after 1 frame(s); walked 19.4 m south and was stopped by the boundary wall at z=63.40 (wall 66.0); moved back north/left/right freely; camera focus offset 0.00 m while moving, 0.11 m at rest.
[sim   12.3s | wall   2.1s] PASS  VS-014  Quest Start  -- Pressed E near Brother Ivenn -> dialogue 'intro' -> 'offer' -> accepted. State=active. Quest log lists 'The Ashen Toll'; HUD tracker: Quests | The Ashen Toll |   - Put down Hollowed Sentinels (0/5) |   - Recover Reliquary Lamp Fragments (0/3)
[sim   12.5s | wall   2.2s] Merchant opened=true, bought potion=false (gold 10 -> 10, potions 3 -> 3)
[sim   21.4s | wall   3.3s] PASS  VS-007  Enemy AI  -- Sentinel idle while player was 15 m away (aggro=false); detected the player at 8.4 m (detect radius 13), closed from 8.5 m to 2.2 m, telegraphed and landed 2 hit(s) (HP 204 -> 181); AI states observed: ["CHASE", "WINDUP", "RECOVER"]; it was then
[sim   21.4s | wall   3.3s] PASS  VS-004  Basic Combat  -- Killed a Hollowed Sentinel with basic attacks (LMB action) only: 5 hits landed, health 60 -> 0, 6 floating damage numbers present, hit flash + knockback applied.
[sim   21.4s | wall   3.3s] PASS  VS-008  XP  -- Killing the sentinel awarded 25 XP (expected 25 from data: base 25, enemy Lv 1 vs player Lv 1); total XP 0 -> 25; HUD XP bar shows 25 == character XP 25.
[sim   22.0s | wall   3.4s] PASS  VS-005  Skill  -- Key 1 cast Radiant Cleave (Light cone): [30] skill damage to the target, resource 90.0 -> 78.0 (cost 12, minus regen), cooldown 2.50s started and blocked immediate re-use; key 2 cast Aegis of Dawn (damage-reduction buff active=true).
[sim   30.4s | wall   4.6s] PASS  VS-006  Dodge  -- Space: dodge moved 5.77 m in 0.32s, i-frames 0.22s then ended, 22 stamina spent, instant re-dodge refused. Spamming dodge for 6 s kept the player invulnerable only 24% of frames (cooldown + stamina gate).
[sim   41.4s | wall   6.0s] PASS  VS-009  Level Up  -- Kill granting 20 XP took the hero from 95 XP (Lv 1, threshold 100) to Lv 2 with 15 XP carried over; 'LEVEL 2' banner shown=true; attribute points 0 -> 5, skill points 0 -> 1; max health 204 -> 213; health refilled=true.
[sim   46.5s | wall   6.6s] PASS  VS-010  Loot  -- Enemy drop 'Vigil Longsword' [common, base sword_vigil, ilvl 1] from enemy:hollow_sentinel: pickup showed rarity beam + name label, walked over it -> in inventory. Total pickups collected in this fight: 3 (2 equipment).
[sim   56.8s | wall   7.8s] PASS  VS-011  Inventory  -- Pressed I: window open=true, 9 bag items shown in the grid with icons; selecting the looted item shows: "Worn Oathblade / Common Weapon - Sword   Item level 1 / Damage 8 - 12  ▼ -2.5 /  / Power 20  ▼ -5.0 (worse)"
[sim   56.8s | wall   7.8s] PASS  VS-012  Equipment  -- Equipped 'Vigil Longsword' into weapon via inventory right-click. 'Vigil Longsword' returned to the bag (bag size unchanged). Damage 13-20 -> 13-19, armor 15 -> 15, max health 237 -> 237; live player stats updated=true; duplicate uids=false.
[sim   56.8s | wall   7.8s] PASS  VS-013  Item Comparison  -- Selected 'Vigil Longsword' in the bag while wearing 'Vigil Longsword': the selected panel shows per-stat deltas and a verdict ("Vigil Longsword / Common Weapon - Sword   Item level 1 / Damage 10 - 15  ▲ +0.5 /  / Power 25  ▲ +1.0 (better)
[sim  139.4s | wall  15.4s] PASS  VS-015  Quest Progression  -- Objectives advanced by gameplay: kills 5/5, kills 5/5, shrine explored=true, fragments 4/3, fragments 5/3. Mid-quest save contained the live kill count=true. State now 'ready'.
[sim  153.4s | wall  16.3s] PASS  VS-016  Quest Completion  -- Turned in at Ivenn (node 'toll_done'): +260 XP (Lv 3 -> 3), +75 gold, potions 8 -> 11, random rare item granted (bag 12 -> 12 items), fragments consumed; second completion attempt returned false with no extra gold; Reliquary unsealed; fo
[sim  190.4s | wall  18.9s] PASS  VS-017  Dungeon  -- Gate open after quest=true; pressed E -> zone 'sunken_reliquary' loaded, player at entrance with HP 376/376, 13 enemies + boss spawned; 'Descend' objective updated=true.
[sim  220.6s | wall  20.8s] bot: giving up on unreachable ashen_cultist at (-3, 0, -31)
[sim  240.9s | wall  21.7s] bot: giving up on unreachable ashen_cultist at (-11, 0, -31)
[sim  254.7s | wall  22.2s] Brazier lit=true, door closed before=true, open after=true, player Lv 4 HP 177/382, potions 14
[sim  291.8s | wall  24.2s] PASS  VS-018  Boss  -- Entered arena -> boss bar shown=true; boss cast 20 telegraphed area attacks + 7 projectiles; boss hit the player 11 time(s); player damaged boss=true; phase 2 (enrage + summons) reached=true; boss HP trace ["100%", "79%", "58%", "48%", "39%", "17%"]
[sim  297.8s | wall  24.4s] PASS  VS-019  Boss Defeat  -- Vorthane died: victory banner=true, encounter ended (bar hidden=true), exit portal spawned=true; unique 'Dawnbreaker, Oath of Vorthane's Ruin' dropped and collected=true; world flag boss_defeated_vorthane=true; quest 'The Hollow Bishop' -> re
[sim  297.9s | wall  24.5s] PASS  VS-020  Save  -- Esc -> Save Game wrote user://saves/slot_1.json (13864 bytes): character Seraphine Vael Lv 5, 794 XP, 609 gold, 20 bag items, 8 equipped, skills {"aegis_of_dawn":1,"ascendant_wrath":0,"celestial_ward":0,"dawnblade_discipline":0,"judgment_circle":1,"
```

## Playthrough log (phase 2)

```
[sim    0.7s | wall   0.3s] PASS  VS-021  Load  -- Fresh process: main menu 'Continue' enabled (latest slot 'slot_1'), loaded into zone 'sunken_reliquary'. Compared 16 saved fields (character, level, XP, gold, inventory uids, equipment uids, skills, attributes, quests, world flags/chests/discoveries
[sim    0.7s | wall   0.3s] PASS  VS-023  Restart Persistence  -- Phase 1 process saved and exited with code 0; phase 2 is a new OS process that restarted the game and loaded: Lv 5, 794 XP, 609 gold, 20 items, quests {"q_ashen_toll":"completed","q_hollow_bishop":"ready"} - identical to the pre-exit 
[sim   27.8s | wall   4.0s] Continued play after load: returned to Vale=true, turned in final quest=true (state completed, dialogue 'epilogue'), saved again=true
```

## Known issues across the slice

- All art and audio are procedural PLACEHOLDERS (see ART_DIRECTION.md); visual quality is far from the target.
- Gameplay tests ran on Linux; no test was executed on Windows hardware.
- Headless runs print `Parameter "m" is null` from the dummy renderer for immediate-mode meshes; it does not occur with a real renderer.
- On engine shutdown with the dummy audio driver Godot reports two leaked AudioStreamWAV playbacks (looping music) - cosmetic, exit code is 0.
