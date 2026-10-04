# Art Direction

**Target: stylized premium dark fantasy.** Ancient ruins, corrupted forests, forgotten temples, dramatic lighting, magical effects — mature, atmospheric and readable at ARPG camera distance. Not cartoonish, not generic mobile, not cluttered.

Priority order for every asset: **silhouette → composition → lighting → character readability → atmosphere → VFX → polygon count.**

> **Current state:** everything visible in the build is a *procedural placeholder* assembled from primitive meshes (`game/characters/model_kit.gd`). They exist to lock in silhouettes, palettes, proportions, scale and readability while the systems were built. They are **not** the intended final look. The full replacement list is at the end of this file.

## Palette and lighting

- World: desaturated ash browns, slate stone, bruised purple sky; warm firelight as the "safe" color, cold blue for magic gates, sickly violet for corruption, blood red for the boss.
- Each heroine owns a signature accent: Dawnwarden **gold/ivory**, Hellbrand **ember red**, Starweaver **teal/starlight**.
- Lighting: low cool moonlight key, warm local fires, emissive magic that blooms (glow enabled), fog for depth, filmic tonemapping.
- Rarity colors: Common `#c8c4bc`, Uncommon `#5fd36b`, Rare `#4f9bff`, Epic `#b45cff`, Legendary `#ff9a2e`.

## Heroines

All playable heroines are **clearly adult** characters. Direction: beautiful, feminine, confident, elegant, athletic or voluptuous as fits the character, memorable — an attractive fantasy heroine in fitted fantasy armor, suitable for a mature action game. Allowed: pronounced feminine silhouette, defined waist, fuller hips, visible legs, tall boots, corset-style or open-neck armor with tasteful cleavage, armored short skirts, exposed shoulders, jewelry. **Never:** nudity, explicit content, sexual poses or fetish-focused designs. Each heroine must differ in body language, face, hair, outfit structure and color — never a recolor of another.

### Seraphine Vael — Dawnwarden (flagship)
- Imposing and radiant; an ancient sword-saint. Long ivory-gold hair, gold circlet with a sun gem, a floating halo ring behind her head.
- Silver-and-gold plate over dark cloth: winged pauldrons, corset-style breastplate with gilded edging, armored plate skirt, tall dark greaves with gold cuffs, bare shoulders and upper arms, midnight-blue cape.
- Longsword glowing faint dawnlight, round silver shield with a gold sunburst.
- Poses: upright, shield forward, heroic. VFX: warm gold arcs, light pillars, sun sigils.

### Kaelith Ashmourn — Hellbrand
- Dangerous before attractive: predatory stance, low center of gravity, glowing ember eyes, swept-back horns, black hair with a crimson streak.
- Fitted dark-red leather and blackened steel, asymmetric spiked pauldron, belt of burning talismans, back loincloth, tall boots, visible legs.
- Twin curved blades with molten edges; embers drift off her constantly.
- VFX: fire slashes, black-flame novas, shadow afterimages on Shadowstep.

### Lyriel Thornwhisper — Starweaver
- Elegant and athletic, inspired by forest-folk archetypes without copying any existing IP: pointed ears, long silver braid, leaf diadem with a glowing rune.
- Teal and moss-green fitted clothing, leaf-shaped shoulder guards, asymmetric short cloak, quiver, light boots, visible legs.
- Living-wood recurve bow with a starlight string.
- VFX: cyan arcane arrows, frost runes, falling stars.

## Enemies and boss

- **Hollowed Sentinel** — hunched knight in broken, rust-streaked plate; a single violet eye-slit; notched sword and tower shield.
- **Gloomfang** — lean black quadruped with bone spines along the back, glowing red eyes, exposed fangs.
- **Ashen Cultist** — tall hood and floor-length robe, faceless dark void with two ember points, burning hands.
- **Veilstalker** — elongated, hunched, near-black skin, cyan glowing claws and spine shards; moves like a shadow.
- **Cinder Colossus** — blocky stone-and-iron construct with lava seams, huge fists, ember particles.
- **Vorthane, the Hollow Bishop** — 2.6× scale; tattered crimson robes, towering bone-white mitre, skull face with burning eyes, glowing exposed ribcage, broken halo of red spikes, censer on a chain and a gold crozier.

## Environments

- **Vale of Cinders**: burned meadow, dark dirt paths, ruined chapel with broken pillars and arches, corrupted forest of dead trees with violet growths, cultist camp with red banners and torches, kneeling headless saint statue in a ring of pillars, a broken bridge and the sealed Reliquary gate with blue magic.
- **Sunken Reliquary**: dark stone halls, rows of sarcophagi, warm torches, a warding brazier, a circular boss arena with red-lit pillars.

## UI

Original dark-fantasy UI: near-black translucent panels, thin antique-gold borders, parchment-white text, gold titles with dark outlines, minimal ornament. Do not imitate any existing game's UI.

## Asset specifications (for final art)

| Asset | Target |
|---|---|
| Heroine | 25–40k tris, 2–4 × 2K texture sets (PBR), humanoid skeleton compatible with Godot retargeting, separate head/hair/armor meshes for future customization |
| Common enemy | 6–15k tris, 1–2K textures |
| Boss | 40–60k tris, 2–4K textures |
| Props | 0.5–5k tris, trim sheets, LOD for large ruins |
| Animations | idle, walk, run, attack ×3, heavy, cast, dodge, block, hit, death, plus class-specific skill clips |
| Audio | OGG 44.1 kHz; sound ids must match `systems/audio/audio_manager.gd` |

Never use copyrighted assets without permission; record the license of every imported asset in `LICENSE.md`.

## Placeholder inventory (all must be replaced)

| Placeholder | Where | Replace with |
|---|---|---|
| Heroine models (primitive meshes) | `game/characters/hero_models.gd` | Authored rigged 3D models per the briefs above |
| Procedural humanoid/quadruped animation | `humanoid_rig.gd`, `beast_rig.gd` | Skeletal animation clips + AnimationTree |
| Enemy and boss models | `game/enemies/enemy_models.gd` | Authored models |
| NPC Brother Ivenn | `game/npc/npc.gd` | Authored model |
| Props (walls, pillars, trees, rocks, tents, statue, chest, brazier, gates) | `game/maps/props.gd`, `chest.gd`, `brazier.gd`, `zone_gate.gd`, `lore_stone.gd` | Modular ruin kit, foliage, hero props |
| Ground (noise texture) and painted paths | `game/maps/zone.gd` | Terrain with splat-mapped materials, decals |
| VFX (rings, slashes, pillars, quads) | `game/combat/vfx.gd`, `projectile.gd`, `area_effect.gd` | Shader-based VFX, trails, decals |
| Item and skill icons (pixel glyphs) | `game/ui/icons.gd` | Painted icons |
| All sound effects and music (synthesized) | `systems/audio/audio_manager.gd` | Recorded/licensed SFX, composed music |
| Default UI font | Godot default | Licensed display + body fonts |
| App icon | `assets/icon.svg` | Final key art icon |
