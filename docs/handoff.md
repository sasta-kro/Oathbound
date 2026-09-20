# Handoff: codebase status audit

**Snapshot: 2026-09-21 02:11, commit `17fb9f2` (local, ahead of origin by one), 346 of 346 GUT tests passing across 27 test scripts.**

Purpose: a durable record of implementation status, usable as a handoff for any new contributor session with no prior context. Historical per-change essays are in git history; this file is the current state. `Oathbound_Specification_v0.6.md` is the authority for intended gameplay, `architecture.md` for system structure, `implementation_status.md` for verified feature behavior, `commit_hygiene.md` for the serialization rules every commit must follow.

## 1. What the game is now

A complete, playable 2D creature-collecting RPG built with Godot 4.7.2 (Compatibility renderer, 960 by 540 logical viewport). The full main story ships end to end: a taught first hour in Town and Area One (binding, field mending, the overworld strike, the ambush, the rout, the inn, the satchel), a catacombs garrison in Area Two, the dead wood and the barrow in Area Three, and an epilogue after the king falls. A run spans four connected areas, 32 main quests plus 6 side quests, visible roaming encounters with overworld first strikes, 1v1 cooldown battles, binding capture, shops, an inn, chests, save slots, music, and an ending that stays ended.

## 2. Systems inventory

All systems below are implemented and test-covered unless listed in section 6.

- **Overworld**: continuous analog movement, eight-direction facing, interaction (E) and overworld strike (F), companion partner that follows and strikes, neutral and hostile wild creatures with leash, chase, windup and strike, dynamic spawn zones with timed respawn, altar-beacon doorways with boss sealing, treasure chests (once per journey), area travel with entrance markers.
- **Battle**: pure-logic `BattleEngine` with event-log playback in `BattleScene`, cooldowns, accuracy, priority with turn-order indicators (`speed_leader`, FIRST STRIKE / AMBUSHES FIRST / GOES FIRST / SPEED TIE), switching, forced replacement, statuses (poison, burn, stun), stat modifiers, support moves with ally targeting, item use in battle, binding, running, boss rules, damage floor, XP with level caps, evolution, abilities, guided tutorial battles (`BattleGuide` subclasses).
- **Progression and story**: quest system (data-driven `QuestData` resources, five statuses, objective kinds defeat/bind/talk/reach/event, refusal and abandonment, turn-in to a non-giver), 32-quest unbroken main chain, scripted field lessons (`field_strike`, `field_ambush`, `field_rout`, `field_binding`, `field_mending`), quest compass and HUD arrow, boss gating with level-cap rewards, epilogue, story-complete persistence.
- **World simulation**: `GameState` autoload (party, satchel, scrolls, currency, quests, defeated bosses, opened chests, haven, location, play time), `SaveService` (3 manual slots, autosave, backups, corruption fallback, atomic writes), area baking pipeline (`area_painter.gd` + `bake_area.gd` + layouts under `scripts/dev/layouts/`).
- **Presentation**: code-built UI theme (no CSS, no art assets required), field menu (party, journal, quests, satchel, saves, settings), shop and inn counters, title screen with save-aware menu, procedural battle VFX (19 presets), screen transitions, world atmosphere and foliage shaders, `MusicService` and `SfxService` with persisted volumes, NPC chatter and barks, wandering NPCs.
- **Content pipeline**: `Content` autoload registry (species, moves, abilities, quests, items, growth curves, type chart, VFX, sprites), `tools/import_monster_sprites.py` (sprite import with palette recolouring, editor-style serialization), `tools/build_overworld_sheets.py` (tileset sheet generation).

## 3. Content counts

| Kind | Count |
| --- | --- |
| Areas | 4 (town, area_one, area_two, area_three) plus legacy `test_01` and `TestScene` |
| Species | 28, all with battle sprites (overworld reuses battle art) |
| Moves | 23 |
| Abilities | 10 |
| Quests | 38 (32 main, 6 side) |
| Items | 5 |
| Types | 7 (fire, earth, water, wind, nature, rot, steel) |
| VFX presets | 19 |
| Tests | 346 across 27 scripts |

## 4. Verification workflow

Run from `game/`:

```bash
godot --headless --path . --import
godot --headless -d --path . -s addons/gut/gut_cmdln.gd
gdformat --check scripts tests
gdlint scripts tests
```

The import step is required after any pull: new `class_name` scripts otherwise fail with "Could not find type" errors from a stale class cache. Serialization rules before committing are in `commit_hygiene.md`: files written by generators must be re-saved in the editor first.

## 5. Known debt

- `gdformat`: 68 files would be reformatted. `gdlint`: 372 problems, mostly line length and max-method counts. Fix as a dedicated pass, not mixed into feature work.
- `areas/TestScene.tscn` references `res://assets/tilesets/area_one.tres`, which does not exist. Broken ref on open.
- `areas/test_01.tscn` is a legacy scratch room, unreachable in game.
- 14 deprecated GUT calls reported in the run summary. Harmless until a GUT upgrade.
- Asset licences: the golem, demon and blood-monster packs have no licence recorded in their `SOURCE.md` files ("fill in before release"). The male hero pack is unused and non-commercial.

## 6. Open gaps against the specification

Roughly in roadmap order. None of these block the current playable arc.

1. Hostile Oathkeeper encounters do not exist; Area Three's two elites are the king's likenesses rather than trainers. `BattleConfig.trainer()` exists unused.
2. Selling items, key items, the Creature Hotel, and Experience Vessel spending do not exist. Buying, the satchel, field and battle item use, vendors and the inn do.
3. Move replacement and move relearning do not exist. A fifth learned move would be lost with a message; every shipped species has exactly four, so it cannot trigger with current content.
4. Ever-bound journal state is not saved; the journal reflects the current party only.
5. World reset after defeat does not exist; the party wakes at its last haven and the world is left as it was.
6. Control rebinding does not exist.
7. Custom pixel-art UI assets do not exist; the code-built shell is temporary by design.
8. XP policy is split: battles pay participants, routs and quest rewards pay the whole party. Spec 9.5 flags this Provisional.
9. No CI. No Git LFS (fine until large audio assets land).

## 7. Small bugs worth knowing

- Stun survives a switch-out and fires on the creature's next action.
- The hand-placed Area One Guardian respawns on every re-entry; only boss defeats persist.
- The field HUD location label is hard-coded to "THE VERDANT REACH".
- The dialogue-panel and battle-caption copy is English-first and unreviewed.

## 8. Suggested next steps

1. Push the pending local commit (commit hygiene doc plus importer serialization fix).
2. A formatting and lint pass as its own commit (see section 5).
3. Fix or delete `TestScene.tscn`; decide the fate of `test_01.tscn`.
4. Pick from section 6 in order; items 2 and 3 (hotel, move relearning) unlock content the story is already positioned for.
5. Before release: resolve asset licences (section 5), add CI running import plus GUT.
