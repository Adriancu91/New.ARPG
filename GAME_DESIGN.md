# Game Design — Gloamreach: Oath of the Ashen Vigil

*Working title (internal).* Original IP. Genre: offline single-player dark-fantasy action RPG, isometric-style camera, Windows PC first.

## Pillars

1. **Combat that answers instantly** — input → motion in one frame, readable telegraphs, dodge that rewards timing but cannot be spammed.
2. **Loot you understand at a glance** — rarity beam + name on the ground, ▲ when it beats what you wear, side-by-side comparison with per-stat deltas.
3. **A world that tells its own story** — ruins, graves, letters and statues explain what happened without cutscenes.
4. **Heroines with distinct identities** — different silhouettes, palettes and play patterns, not recolors.
5. **Short loop, long tail** — the core loop is clear in five minutes; affixes, ranks, uniques and future regions carry long-term progression.

## Core loop

Explore → fight → loot → level up → equip → unlock skills → discover → defeat bosses → expand the world.

## World and lore

Three winters ago the **Vale of Cinders** burned. Bishop **Vorthane** sealed himself inside the **Sunken Reliquary** to pray the plague of ash away — and something answered. When the seal cracked, the **Reliquary Lamp** that guarded it shattered and the dead rose as the **Hollowed**, still wearing the armor they died in. **Brother Ivenn**, the last lamplighter, keeps one flame burning at his camp. The heroine arrives as the Vale's last chance; the **Shrine of the Broken Saint** (Saint Aurelie, who held back the first darkness with a lamp) holds the memory needed to rekindle it.

Factions: the Hollowed (risen dead), the Cinder Cult (worship Vorthane's hunger, hoard the lamp shards), corrupted beasts and constructs.

## Heroines

| | Seraphine Vael — **Dawnwarden** | Kaelith Ashmourn — **Hellbrand** | Lyriel Thornwhisper — **Starweaver** |
|---|---|---|---|
| Fantasy | Last oath of the Sunfallen Order, celestial sword-saint (flagship) | Demon hunter who bargained her shadow back | Last archer of a vanished forest people |
| Weapon / style | Sword + shield, can **block** | Dual blades, fastest attacks | Bow, ranged basic attack |
| Resource | Radiance | Fury | Focus |
| Primary attribute | Might | Agility | Agility |
| Difficulty | Easy | Hard | Medium |
| Actives | Radiant Cleave, Aegis of Dawn, Sunlance, Judgment Circle, **Ascendant Wrath** (ult) | Infernal Flurry, Shadowstep, Hellfire Orb, Brimstone Nova, **Demonform** (ult) | Arcane Shot, Split Volley, Frost Snare, Gale Leap, **Starfall** (ult) |
| Passives | Celestial Ward, Dawnblade Discipline | Bloodlust, Cinder Veins | Keen Sight, Grove Ward |

All three are adult characters. Visual briefs: [ART_DIRECTION.md](ART_DIRECTION.md).

## Combat

| Action | Rules |
|---|---|
| Basic attack (LMB) | Melee cone (range/arc per class) or arrow. Interval = class base / attack speed. +3 resource on melee hit. |
| Heavy attack (RMB) | 25 stamina, 0.38 s wind-up (slowed movement), ×2 damage, 170° arc, strong knockback. |
| Dodge (Space) | 22 stamina, 0.32 s dash at 17 m/s, 0.22 s invulnerability, 0.55 s cooldown after the dash. |
| Block (Shift, Dawnwarden) | 120° frontal arc, −65% damage, drains stamina; guard breaks at 0 stamina (0.7 s stagger). |
| Skills (1–5) | Resource cost + cooldown, damage × (1 + rank bonus) × skill power (Spirit). |
| Potion (Q) | Heals 40% max health, 1 s cooldown. |
| Crits | 5% base + 0.2% per Agility + gear, ×1.5 damage, larger gold numbers. |
| Armor | reduction = armor / (armor + 50 + 10 × attacker level), max 75%; non-physical damage uses half of it. |
| Elements | Physical, Light (+25% vs corrupted), Fire (burn DoT), Shadow, Frost (chill −45% speed), Arcane. |
| Status | Burn, Chill, Stun (bosses only stagger briefly), buffs Aegis (−45% damage taken) and Demonform (+50% attack speed, +30% damage, 10% life steal). |

Enemy attacks always telegraph: red cones for melee, orange circles for slams, blue lines for lunges, red/purple circles for boss attacks.

## Progression

- XP to next level = round(100 × level^1.5). Enemy XP scales +12% per enemy level and fades against much weaker enemies.
- Per level: +5 attribute points, +1 skill point, +9 max health, full refill.
- Attributes: **Might** (melee damage, +1 health), **Agility** (crit, attack speed, ranged/dual damage), **Spirit** (resource, regen, skill power), **Vitality** (+6 health, regen).
- Skills unlock at levels 1/1/2/3/5; ranks up to 5 (ultimates 3).

## Items

- Slots: weapon, helmet, armor, gloves, boots, ring ×2, amulet. Weapons are class-restricted (sword / dual blades / bow).
- Rarities: Common (0 affixes), Uncommon (1), Rare (2), Epic (3), Legendary (4) with ×1.0 → ×1.55 base stats and drop weights 60 / 26 / 10 / 3.4 / 0.6.
- 13 affixes (attributes, health, resource, armor, crit, attack speed, movement, damage %, fire damage, life on hit). Rings and amulets have fixed implicit stats.
- Uniques with lore: Dawnbreaker, Ashen Requiem, Vigil of Stars (one per class, guaranteed from Vorthane) and The Hollow Mitre.
- Power score drives the ▲ upgrade hint; the tooltip shows per-stat deltas and lost affixes.
- Materials (Ash Shard, Ember Dust, Void Pearl) from salvage and drops; Brother Ivenn brews potions from them and trades.

## Enemies

| Enemy | Archetype | Behaviour |
|---|---|---|
| Hollowed Sentinel | corrupted warrior | melee cone after a 0.55 s telegraph, moderate armor |
| Gloomfang | beast | fast, fragile, hunts in packs |
| Ashen Cultist | ranged caster | keeps 9 m distance, shadow bolt, strafes |
| Veilstalker | assassin | circles, then lunges 7 m along a telegraphed line |
| Cinder Colossus | heavy | slow, armored, knockback-immune, fire slam AoE |

Boss — **Vorthane, the Hollow Bishop** (2.6× scale): Censer Sweep (150° cone), Sanguine Bolts (5/7-projectile fan), Grave Pillars (3/5 delayed circles under the player). At 50% health: enrage roar (knockback, brief invulnerability), summons two Gloomfangs and a Sentinel, +30% speed, faster attacks and **Requiem Nova** (8 m ring — get out). Drops the class unique, an epic+ item, a Void Pearl and gold.

## The vertical slice

1. Brother Ivenn's camp (start) — quest **The Ashen Toll**: kill 5 Hollowed Sentinels, recover 3 Lamp Fragments (chapel altar, cult camp chest, shrine chest; cultists carry spares), find the Shrine of the Broken Saint.
2. Rewards unseal the Reliquary; quest **The Hollow Bishop**: descend, light the Warding Brazier (opens the arena door), slay Vorthane, return to Ivenn.
3. Safety nets: Hollowed respawn at the chapel if the hunt can no longer be completed; death respawns you at the zone entrance (−10% gold) and resets the boss.

## UX

- No tutorial screens: the HUD lists hotkeys, the first objective appears on arrival, quest markers (! / ?) sit above Ivenn, interactables show "[E] …" prompts, sealed doors explain what opens them.
- Notifications on the left for loot, XP, quests and lore; a large banner on level up; boss bar at the top.
