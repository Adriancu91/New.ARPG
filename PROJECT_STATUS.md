# Project Status

*Updated: 2026-10-04 — build 0.1.0 — Godot 4.3-stable*

## Current milestone

**M6 — Polish (in progress).** Milestones M0–M5 are complete and verified. The vertical slice is functionally complete and passes acceptance; the remaining polish work is dominated by replacing placeholder art and audio.

## Realistic completion

| Scope | Estimate | Why |
|---|---|---|
| Vertical slice — **gameplay systems** | **~90%** | Full loop works end to end and is tested; missing: settings persistence, key rebinding UI, multiple save slots. |
| Vertical slice — **including final-quality art/audio** | **~45%** | Every model, animation, VFX, icon, sound and music track is a procedural placeholder. |
| Long-term target (multi-region, multi-class full game) | **~8%** | 1 region + 1 dungeon + 1 boss of many; skill trees at 7 of 20+ abilities per class. |

## Test results (latest run — see [TEST_REPORT.md](TEST_REPORT.md))

- **Acceptance:** 24 PASS / 0 FAIL / 1 BLOCKED → Acceptance Score **100%** of executable tests (24/24); **all 20 critical tests PASS → VERTICAL SLICE ACCEPTED**.
  - BLOCKED: **VS-025 Performance** — no mid-range GPU in the build environment. CPU cost per frame with 15+ enemies: avg ≈2.6 ms, p99 ≈5 ms; memory stable across 6 zone reload cycles.
- **Unit tests:** 42 / 42 PASS.
- **All three heroines:** every skill + basic/heavy attack verified (class smoke test).
- **Windows build:** exported `.exe` ran the same two-process acceptance playthrough under Wine: 22/22 PASS (not a substitute for real Windows hardware).
- **Stability:** after the final fixes, acceptance phase 1 was repeated 10 times in a row: 10/10 runs fully passing, 0 player deaths, 0 navigation failures.
- **Offline:** the playthrough runs inside a network namespace without network; no networking APIs exist in game code.

## Completed systems

Godot project + Git structure · input map (keyboard/mouse, gamepad prepared) · ARPG camera (zoom, smoothing, boss framing, shake) · data-driven content database · player controller (move, attack, heavy, dodge with i-frames, block, skills, potions, interact) · 3 heroines with 7 skills each · 8 skill behaviours · damage/armor/elements/crits/status effects · floating damage numbers, hit flash, knockback · 5 enemy archetypes with telegraphed AI · 2-phase boss with summons and unique loot · XP/levels/attributes/skill ranks · procedural items (5 rarities, 13 affixes, implicits, 4 uniques) · inventory with stacking, discard, salvage · equipment with comparison and upgrade hints · loot drops with rarity beams · chests · crafting (salvage, potion brewing) · merchant · branching dialogue · quest system (kill/collect/explore/interact/boss) and a 2-quest chain · outdoor region + dungeon + boss arena · minimap and full map · lore objects · HUD, inventory, character, skills, quest log, dialogue, trade, pause, settings, death screen · local manual/auto saves with atomic writes · audio buses with synthesized placeholder SFX/music · Windows + Linux export presets · unit tests, acceptance bot, class smoke test, benchmark, screenshot tour, report generator.

## Working systems with limitations

- **Visuals:** primitive-mesh placeholders with procedural animation (see the placeholder inventory in [ART_DIRECTION.md](ART_DIRECTION.md)).
- **Audio:** synthesized placeholder sounds and drones.
- **Enemy navigation:** steering + sidestepping, no navigation mesh; enemies can occasionally hug walls in tight ruins.
- **Settings** (volumes, fullscreen, damage numbers, camera shake) apply immediately but are not yet saved between sessions.
- **One save slot** (+ autosave).

## Failed systems

None known. No acceptance test is failing.

## Known issues

- VS-025 not measured on a real mid-range GPU (BLOCKED, not PASS).
- No test has been executed on real Windows hardware (Linux + Wine only).
- Headless runs print `Parameter "m" is null` from Godot's dummy renderer (immediate-mode meshes); not present with a real renderer.
- With the dummy audio driver, Godot reports two leaked looping-music playbacks at shutdown (cosmetic).
- The acceptance bot steers with `move_override`/`aim_override` instead of a physical mouse (WASD itself is tested with real input actions in VS-003).

## Next milestone

**M7 — Production art pass**, starting with Seraphine Vael (flagship model, rig and animation set), then enemies, the boss and a modular ruin kit; in parallel **M8 — Windows RC**: run `tools/run_acceptance.sh` and the benchmark on a mid-range Windows PC to close VS-025, add settings persistence, key rebinding and save slots. Details in [ROADMAP.md](ROADMAP.md).
