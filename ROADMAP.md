# Roadmap

Milestones follow the build specification. ✅ done and verified by tests, 🟡 done with placeholders / partially, ⬜ not started.

## M0 — Foundation ✅
Godot 4.3 project, Git structure, autoload architecture, input map (keyboard + mouse, gamepad prepared), player controller, ARPG camera, base UI, save architecture, unit + acceptance test architecture.

## M1 — First hero ✅ (🟡 art)
Seraphine Vael / Dawnwarden: movement, attacks, heavy attack, dodge, block, health/resource/stamina, 5 active + 2 passive skills, procedural placeholder animation.

## M2 — Combat ✅
5 enemy archetypes with AI, damage/armor/elements/status, death, loot drops, XP and levels.

## M3 — RPG systems ✅
Inventory (stacking, discard, salvage), equipment (8 slots), 5 rarities, affixes, implicits, uniques, item comparison, attributes, skill points/ranks, character and skills screens. Plus: Hellbrand and Starweaver playable.

## M4 — World ✅ (🟡 art)
Vale of Cinders, Sunken Reliquary, NPC with branching dialogue and merchant, 2-quest chain, lore objects, chests, minimap + full map.

## M5 — Boss ✅
Vorthane, 2 phases, telegraphed attacks, summons, unique loot, victory flow, exit portal.

## M6 — Polish 🟡
Done: synthesized placeholder audio on 4 buses, particles, dynamic lights and fog, hit flash, damage numbers, camera shake, screen fades, settings (volumes, fullscreen, damage numbers, shake), memory-stable zone reloads.
Remaining: real art and animation (biggest gap), real audio and music, shader-based VFX, UI art pass and fonts, measured GPU performance on a mid-range PC.

---

## Next: M7 — Production art pass (highest priority)
1. Commission or source licensed **rigged heroine models** following ART_DIRECTION.md (Dawnwarden first), with idle/run/attack/cast/dodge/block/hit/death clips; swap `HeroModels` for imported scenes behind the same rig API.
2. Enemy and boss models + animation sets.
3. Modular ruin kit, foliage, terrain material, decals; rebuild the Vale with authored geometry and a navigation mesh.
4. Shader VFX (slash trails, light pillars, fire, frost), item/skill icons, UI frames, fonts.
5. Real SFX + 3 music tracks (exploration, dungeon, boss).

## M8 — Windows release candidate
- Run `tools/run_acceptance.sh` steps and the benchmark on a real mid-range Windows PC; fix VS-025 findings.
- Settings persistence (config file), key rebinding UI, resolution/vsync/quality presets, controller polish.
- Multiple save slots with metadata, save versioning/migration.
- Installer or itch.io/Steam-style zip, application icon, crash logging.

## M9 — Content expansion
- Skill trees: 20+ abilities per class (data entries on existing skill types + new types: channel, summon, chain, aura).
- 2–3 new regions (Zone subclasses), each with a dungeon and a boss; world map travel between regions.
- More enemy families, elites/champions with affixes, rare spawns, events.
- Crafting: reforging affixes, sockets/gems, recipes from Void Pearls.
- Secrets, side quests, lore collection, NG+ / difficulty tiers.

## M10 — Long-term
More playable classes (all data-driven), endgame dungeons, item sets, transmog, accessibility options, localization (Romanian/English first).
