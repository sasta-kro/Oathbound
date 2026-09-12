# Handoff: Project Status and Roadmap

**As of:** 12 September 2026, commit `71f7b25` ("added save system") plus uncommitted quest-system work.
**Tests:** 192 / 192 GUT tests passing.

Read in this order: this file, then `Oathbound_Specification_v0.5.md`, then `architecture.md`. `spec_audit_2026-09-12.md` explains every divergence found when the spec was revised.

## 1. What the game is right now

A playable vertical slice of the overworld-and-battle loop in two hand-painted areas:

- **Town** (walled village, hub and starter settlement in one): Knight heals the party, Elder gives the first main quest, Merchant and Child give side quests.
- **Area One** (meadow, road, pond, ruins, altar): six spawn zones over six species, a hand-placed hostile Cinderclaw guarding the altar, a Scout NPC with the second main quest.
- Player starts with a level-7 Emberling and 5 Binding Scrolls. Roam, strike creatures on the field with F, fight 1v1 turn battles, bind creatures, level up, evolve Emberling at 16, complete four quests, save to slots.

Roughly 10 to 15 minutes of content against a 40 to 60 minute target.

## 2. The last three pieces of work, and how they were built

These are the most recent implementations. The next developer will most likely touch them first.

### 2.1 Quest system (uncommitted at handoff)

**Files:** `scripts/quests/quest_data.gd`, `quest_objective.gd`, `quest_log.gd`; `content/quests/*.tres` (4 quests); `scripts/content/content_registry.gd` (quest index + validation); `scripts/world_actor.gd` (`quest_ids`, `actor_id()`, `current_quest()`); `scripts/game_state.gd` (quest wrappers, rewards, save keys); `scripts/main.gd::_talk_to` (dialogue branches); `scripts/dialogue_panel.gd::ask()` (choice list); `scripts/ui/field_ui.gd::_quests` (log page, L key, notices); `assets/ui/icons/quests.svg`; `tests/test_quest_system.gd` (22 tests); `docs/map_authoring.md` (Quests section); the two area scenes and their layouts (giver `quest_ids`).

**How:** quests are content resources. `QuestLog` is pure state: five statuses, per-objective tallies, `report(kind, target)` advances every active quest that matches so one action can progress several quests. `GameState` wraps it, pays rewards, emits signals and includes it in the save. The overworld reports four event kinds (REACH on area load, TALK on interact, DEFEAT on victory or rout, BIND on bind). An NPC's `current_quest()` picks what to talk about (ready to turn in > in progress > offerable); `main._talk_to` runs the matching branch through `DialoguePanel.ask`, which returns the chosen reply index. Every quest state change autosaves.

**Deliberate choices:** a quest never fails; abandoning resets progress; `requires` chains main quests; missing dialogue lines fall back to defaults so a quest is playable with just an offer line; loading a save drops quests whose content no longer exists.

**To finish:** commit it. Then consider `bound_species` for the journal (see 4.2) since bind objectives now exist.

### 2.2 Save system (commit `71f7b25`)

**Files:** `scripts/save/save_service.gd`, `scripts/ui/save_slot_list.gd`, `scripts/ui/title_screen.gd`, `scripts/game_state.gd` (`to_dict`/`from_dict`, location, play time, `active_slot`), `scripts/main.gd` (`_autosave`, `save_to_slot`, `load_from_slot`, `return_to_title`, window-close save), `tests/gut_pre_run.gd`, `tests/test_save_system.gd`.

**How:** `SaveService` only moves dictionaries to and from `user://saves/` (three manual slots, one autosave, `.backup` per slot, temp-file swap, `format_version`). `GameState` builds the dictionary and is the single owner of what is saved. The field autosaves at state boundaries and records the player's area, position and facing before every write; `GameState.take_resume_request()` tells the field once to open at the saved spot. The title screen's Continue picks the most recent slot of either kind. Destructive slot actions arm on first press and act on the second.

**Deliberate departure from spec v0.4:** manual slots were added on request; the v0.5 spec now says so (21.1).

### 2.3 Town and Area One maps (commit `c1ed0a4`)

**Files:** `areas/town.tscn`, `areas/area_one.tscn`, `scripts/dev/layouts/town_layout.gd`, `area_one_layout.gd`, `scripts/dev/area_painter.gd`, `bake_area.gd`, `build_overworld_tileset.gd`, `snapshot_area.gd`, `assets/tilesets/*`, `tools/build_overworld_sheets.py`, `tools/pack_sprite_sheet.py`.

**How:** layout scripts describe a map in cells (terrain regions, named sprites, scattered dressing, actors, zones, exits) and `bake_area.gd` writes the `.tscn`. From then on the scene is hand-edited in the editor; re-baking overwrites hand edits. Tilesets are generated from PNG sheets plus JSON manifests that carry collision kind and terrain bits. Full instructions in `map_authoring.md`.

Earlier milestones, oldest first: creature system with abilities and growth (`dfc4741`), combat demo and battle scene (`cc2da51`), analog movement (`ab8d9b2`), tilemap integration (`5ddd3d2`), overworld strike ("Attack", `2274185`), shaders and VFX presets (`fc4a2ca`), UI theme and field menus (`9e8b0d5`, `1294144`).

## 3. Working state of the repository

- **Uncommitted:** the whole quest system (see 2.1). Commit it first.
- **Godot on this machine:** `/Applications/Godot.app/Contents/MacOS/Godot`, no `godot` symlink on `PATH`. The setup doc's `ln -s` step has not been run here. Tests were run with the full path.
- **gdtoolkit:** not installed here. Several UI scripts (`field_ui.gd`, `title_screen.gd`, `dialogue_panel.gd`, `save_slot_list.gd`, `creature_portrait.gd`, `creature_gallery.gd`) are written compactly (one-line `if`, inline lambdas) and `gdformat` will rewrite them. Do that as its own commit so history stays readable.
- **Git LFS:** not configured (no `.gitattributes`). Sprites are in plain Git. Fine so far; decide before large audio drops.
- **CI:** none.
- **`AGENTS.md`:** listed in `.gitignore` and absent. The README used to reference it. Agent conventions now live in `architecture.md` section 12. If a tracked agent file is wanted, un-ignore and add it.
- **`areas/test_01.tscn`:** legacy test room, not reachable in the game. Safe to delete along with `scripts/dev/test_01_generator.gd` and `bake_test_01.gd`, or keep as a scratch area.
- **Placeholders in play:** Cinderclaw, Rillfin and Gustpip have no art. NPCs other than the Knight are coloured boxes with labels. That is by design (Spec 23) and tests cover both paths.
- **Assets and licences:** `assets/creatures/*/SOURCE.md` and `assets/player/male_hero/SOURCE.md` record sources. The golem, demon and blood-monster packs have no licence recorded ("fill in before release"). The male hero pack is unused and non-commercial. The hero uses `assets/characters/character_13.png` (superretroworld). Fonts are OFL.

## 4. Known gaps and small bugs

Ordered by how likely they are to bite.

1. **A fifth move would be lost.** No replace-or-refuse choice and no relearn NPC exist; the engine skips the move with a message. Every shipped species has exactly four learnset moves, so this cannot trigger with current content, but the first species with five moves will hit it. `CreatureInstance.replace_move`, `forget_move`, `relearnable_moves` already exist.
2. **Journal BOUND is not persisted.** It reflects the current party only. Add `bound_species` to `GameState` next to `seen_species`, set it on bind and starter, save it.
3. **XP policy differs by path.** Battle: participants. Rout and quest rewards: whole party. Pick one for routs (lead only recommended) and change `GameState.award_defeat_rewards`.
4. **Level cap never rises.** Anything past level 20 needs a boss victory to write `GameState.level_cap`.
5. **Stun survives a switch-out** and fires on the creature's next action. Clear it in `BattleEngine._switch` if unwanted.
6. **Battle caption is hard-coded "WILD ENCOUNTER"** (`battle_scene.gd::_polish_chrome`). Make it follow `config.is_wild` when trainers arrive.
7. **Field HUD location label is hard-coded "THE VERDANT REACH"**; should come from the area.
8. **Party defeat heals in place** with no revival location or world reset.
9. **Deprecated GUT calls:** the run summary reports 14 deprecation warnings. Harmless; look at them when upgrading GUT.

## 5. Roadmap

Ordered so each step unlocks the next and keeps the game playable at every commit. Effort is a rough size for one developer.

### Now (finish the slice)

1. **Commit the quest system.** Small.
2. **Move replace-or-refuse and relearn NPC.** Battle-scene menu on `MOVE_LEARN_SKIPPED`, a field notice path for routs and quest XP, a `WorldActor` flag `relearns_moves` with a small picker page in `FieldUI`. Medium.
3. **`bound_species` in the journal and save.** Small.
4. **gdformat pass, `godot` symlink, CI workflow** (import + GUT on push). Small, do early.

### Next (the first area becomes a real area)

5. **Hostile Oathkeepers.** New `Oathkeeper extends WorldActor` with a roster (array of species+level), four-directional sight with wall blocking, approach, `BattleConfig.trainer()`, post-defeat dialogue, `defeated_trainers` set in `GameState` and the save. Engine and scene already handle multi-creature enemies and "can't run". Large.
6. **Area 1 boss and the first gate.** Boss = Oathkeeper with `is_boss`, up to 3 creatures, a boss AI profile in `BattleAI` (switching, configurable item use once items exist). Victory writes `level_cap = 30` and unlocks an exit. Add `defeated_bosses` and `unlocked_areas` to the save. Medium after 5.
7. **Items and inventory.** `ItemData` resource, `GameState.inventory` (id → count), inventory page, battle Item action (heal, revive, cure, buffs), scroll grades as items. Large.
8. **Shops and healing service UI.** Vendor `WorldActor` flag + stock list; buy/sell page; autosave after transactions. Medium after 7.
9. **Creature Hotel.** `GameState.hotel: Array[CreatureInstance]`, capacity 30, store/retrieve page, party-full flow after a bind, "cannot remove last Oathbound" guard. Medium.
10. **Experience Vessel.** Quest item; `GameState.vessel_xp += excess * 0.7` at cap; spend page. Small once items exist.
11. **Party defeat → revival location.** Record the last healer's area and position; on defeat travel there, reset creatures. Small.

### Later (content and the rest of the story)

12. **Opening sequence and player name.** Short scripted dialogue at the start; name entry; store `player_name`. Medium.
13. **Areas 2 and 3, bosses 2 and 3, ending and credits.** Content-heavy; the map pipeline is ready. Species count needs to grow from 6 toward 15+, moves from 10 toward 25+.
14. **Audio.** Music and SFX players, `DevLog.missing_asset("sfx"/"music", id)` for missing files, volume settings section. Medium.
15. **Control rebinding** in settings. Medium.
16. **Interactables:** chests (once-per-game, saved), signs, doors, switches. Medium.
17. **Remaining quest objective kinds:** retrieve item, deliver creature, escort. After 7 and 9.

## 6. Quick verification checklist for any change

```bash
cd game
godot --headless --path . --import
godot --headless -d --path . -s addons/gut/gut_cmdln.gd   # expect "All tests passed!"
gdformat --check scripts tests
gdlint scripts tests
```

Then launch, start a new journey, walk north through the gate, strike a Loambuck with F, win, talk to the Scout, save from Esc → Save journey, quit, Continue. That path touches every system that exists.
