# Architecture

How the Godot project under `game/` is put together. This is the implementation companion to the gameplay specification; where they disagree, the spec is the rule and this file describes what the code does today.

Engine: Godot 4.7.2, Compatibility renderer, typed GDScript, GUT 9.7.1. Open `game/` as the project.

## 1. Runtime shape

```text
project.godot main scene ──► scenes/title_screen.tscn ──► main.tscn (the field)
                                                              │
                          ┌───────────────────────────────────┤
                          │ Area (WorldArea, swapped at runtime from areas/*.tscn)
                          │ Player (CharacterBody2D) + Camera2D
                          │ OverworldPartner (lead creature following the player)
                          │ WorldAtmosphere (post-process CanvasLayer)
                          │ FieldUI (built in code by main.gd; HUD, menus, notices)
                          │ DialoguePanel
                          │ SettingsMenu
                          │ BattleScene (CanvasLayer, hidden until a battle)
                          │ ScreenTransition (wipe between world and battle)
                          └───────────────────────────────────┘
```

Autoloads (`project.godot` order matters; later ones may read earlier ones in `_ready`):

| Autoload | Script | Owns |
|---|---|---|
| `MCPRuntimeBridge`, `MCPInputBridge`, `MCPScreenshotBridge` | `addons/godot_mcp/services/` | Dev tooling only. Must never be referenced by game code. |
| `DisplayService` | `scripts/display/display_service.gd` | Window scale, fullscreen, `user://settings.cfg`. |
| `Content` | `scripts/content/content_registry.gd` | Loads every `.tres` under `content/` and indexes it by `id`. `validate()` reports broken references. |
| `SaveService` | `scripts/save/save_service.gd` | Slot files on disk. Knows nothing about what a save contains. |
| `GameState` | `scripts/game_state.gd` | The player's journey: party, scrolls, coins, level cap, quest log, seen species, location, play time. `to_dict()`/`from_dict()` **are** the save format. |

## 2. Layers

Dependencies point downward. A lower layer never imports a higher one.

```text
scenes / UI        main.gd, battle_scene.gd, field_ui.gd, title_screen.gd, dialogue_panel.gd
world              player.gd, wild_creature.gd, world_actor.gd, spawn_zone.gd, area_exit.gd,
                   world_area.gd, overworld_partner.gd, overworld_strike.gd
state              game_state.gd, quest_log.gd, save_service.gd
rules (pure)       battle_engine.gd, battle_rules.gd, battle_ai.gd, battler.gd, battle_team.gd,
                   creature_instance.gd, growth_curve.gd, type_chart.gd, overworld_strike.gd
content (data)     creature_species.gd, move_data.gd, ability_data.gd, quest_data.gd,
                   quest_objective.gd, stat_modifier.gd, vfx_preset.gd, elements.gd, status_ids.gd
```

The rules layer is `RefCounted` with no nodes, no timers, no input, and no autoload access. That is what makes it testable headless and is the property to protect when adding mechanics.

## 3. Content

Everything replaceable lives as `.tres` under `game/content/`, indexed by the `id` field inside the resource (never by filename).

| Directory | Resource script | Count | Notes |
|---|---|---:|---|
| `content/creatures/` | `CreatureSpecies` | 6 | Types, base stats, growth curve, learnset, evolution, ability pool, bind chance, sprites. |
| `content/moves/` | `MoveData` | 10 | Power, accuracy, cooldown, priority, status, stat modifiers, VFX preset. |
| `content/abilities/` | `AbilityData` | 7 | Declarative passives (Spec 9.9). |
| `content/quests/` | `QuestData` + `QuestObjective` | 4 | Giver actor id, `requires`, objectives, rewards, eight dialogue lines. |
| `content/growth/` | `GrowthCurve` | 2 | XP and stat curves. |
| `content/types/` | `TypeChart` + `TypeMatchup` | 1 | Only non-neutral matchups listed. |
| `content/vfx/` | `VfxPreset` | 12 | Shape, colours, timing for the one effect shader. |
| `content/sprites/` | `SpriteFrames` | 5 | Player hero, knight, three creature battle sheets. |

Adding a species or move is a new file, no code. Adding a quest is a new file plus the giver's `quest_ids` in the area scene. `Content.validate()` is called by the tests and will name dangling references.

Enums that content stores as integers (`Elements.Type`, `StatusIds.Status`, `VfxPreset.Pattern`) are append-only.

## 4. The creature model

- `CreatureSpecies` (resource): the baseline. Stats are a pure function of species, growth curve and level; there are no IVs.
- `CreatureInstance` (RefCounted): one live creature. Level, total XP, current HP, equipped moves, ability. `gain_xp(amount, cap)` returns an `XpResult` (applied, excess, learnable moves, evolution ready); it never drives follow-up flow itself.
- `Battler` (RefCounted): battle-only state layered over an instance: cooldowns, statuses, stat modifiers, `participated`. Discarded when the battle ends.
- `BattleTeam`: one side's battlers and the active index.

Level cap is passed in by whoever awards XP (`GameState.level_cap`), so the creature model does not know about story progression.

## 5. Battle

`BattleConfig` (parties, wild/trainer, can run, scrolls, bind destination, level cap, opening, type chart, seed) goes into `BattleEngine`. The engine exposes:

- `start()` → events
- `options()` → what the player may do and why not
- `take_turn(BattleAction)` → events for the whole turn
- `replace_fainted(index)` → events
- `phase` (`CHOOSING`, `REPLACING`, `ENDED`) and `outcome` (`VICTORY`, `DEFEAT`, `ESCAPED`, `BOUND`)

Every random roll goes through `engine.roll()`; tests set `forced_roll` or a seed. All numbers (damage, hit chance, bind chance, run chance, XP, coins, turn order) are static functions in `BattleRules`, so balance edits touch one file.

`BattleScene` is presentation only: it renders the engine's `BattleEvent` list one beat at a time (`_present`), builds the command/moves/party menus from `engine.options()`, and emits `battle_finished(engine)` after covering the screen with the transition. `skip_presentation = true` makes it synchronous for tests.

`main.gd::_on_battle_finished` applies the outcome to `GameState` (scrolls, coins, bound creature, defeat penalty), reports quest events, autosaves, and plays the creature's rout or back-off.

## 6. Overworld

`main.gd` is the field driver. It knows no specific map: areas announce themselves via groups and signals.

- `WorldArea` (area root): `ground` TileMapLayer defines bounds and spawnable cells; `PlayerStart`; `Entrances/<Name>` markers.
- `AreaExit` (Area2D): `target_area_path` + `target_entrance`. `main.travel_to` swaps the `Area` node behind a wipe, keeping it at the same tree index.
- `WorldActor` (NPC): `display_name`, `dialogue_line`, `heals_party`, `quest_ids`. `actor_id()` is the node name lower-cased; quests refer to actors by it.
- `WildCreature extends WorldActor`: state machine IDLE / WANDER / CHASE / WINDUP / RECOVER. Holds one `CreatureInstance` for its whole life (`encounter_instance()`), so overworld damage persists. Emits `reached_player` when its strike lands and `defeated` when it leaves the map.
- `SpawnZone`: fills a circle with `WildCreature`s on free ground cells, respawns after a delay, relays `creature_reached_player`.
- `OverworldPartner`: the lead creature following a breadcrumb trail; `strike_toward(point)` plays the lunge.
- `OverworldStrike` (pure): damage of a strike or ambush, best move selection, rout check. Wraps `BattleRules.damage` so overworld and battle damage can never drift.

Input routing in the field: `main._unhandled_input` handles Esc (settings), F (strike) and E (interact) unless a menu, dialogue, battle or transition owns the screen. `FieldUI._input` handles Esc (field menu), Tab/P, J, L. `DialoguePanel._unhandled_input` swallows W/S/E while a question is open. `_refresh_world_activity()` is the single place that freezes or resumes the player, partner and every creature.

## 7. Quests

- `QuestData` / `QuestObjective`: content.
- `QuestLog` (RefCounted, in `GameState.quests`): status per quest id, progress tallies, `report(kind, target)` advances every active quest that matches, `to_dict()`/`from_dict()`.
- `GameState.accept_quest / refuse_quest / abandon_quest / complete_quest / report_quest_event` wrap the log and emit `quest_changed` and `quest_objective_advanced`.
- `main._talk_to(actor)`: reports TALK, then asks the actor for `current_quest()` (ready > active > offerable) and runs the right dialogue branch with `DialoguePanel.ask`.
- Event sources: `_report_area_reached` (REACH), `_rout` and `_on_battle_finished` VICTORY (DEFEAT), BOUND (BIND), `_talk_to` (TALK).
- `FieldUI._quests` renders the log; `_on_quest_changed` / `_on_quest_objective_advanced` show notices.

## 8. Saving

`GameState.to_dict()` is the whole save; `SaveService.write(slot, dict)` adds `format_version` and writes temp → rotate previous to `.backup` → rename. `read(slot)` falls back to the backup on parse failure. Slots: 0 = autosave, 1..3 manual, under `user://saves/`.

Save keys today: `saved_at`, `play_seconds`, `party[]` (species, level, total_xp, current_hp, moves[], ability), `seen_species[]`, `binding_scrolls`, `currency`, `level_cap`, `quests{}`, `location{area,x,y,facing_x,facing_y}`, `format_version`.

Adding state: put it on `GameState`, add it to both dict functions with a default in `from_dict`, bump `SaveService.FORMAT_VERSION` only if old files could not be read.

Boundary autosaves are called from `main.gd` (`_autosave`). The field also records the player's position before every save.

## 9. Presentation systems

- `CreatureVisual`: the only place that decides between real `SpriteFrames` and `PlaceholderVisual`. States `idle`, `walk`, `attack`, `hurt`, `death`; one-shots return to idle and emit `state_finished`. `prepare_dissolve()` arms the dissolve shader for real art.
- `VfxPlayer` + `VfxPreset` + `shaders/vfx_shapes.gdshader`: every effect. `VfxPlayer.play_move` picks the move's preset or an element default.
- `ScreenTransition` + `shaders/tile_wipe.gdshader`: `cover()` then `reveal()`; the battle scene covers itself on close.
- `WorldAtmosphere` + `shaders/world_atmosphere.gdshader`, `shaders/foliage_sway.gdshader`: look of the overworld. Toggle `enabled` for screenshots.
- `OathTheme`: palette, fonts, styleboxes and small builders (`label`, `heading`, `button`, `chip`, `bar`, `portrait`, `gallery`) used by every screen. Design sizes assume the 960x540 canvas.
- `FieldUI`: HUD (top-right glass icons, bottom-left lead status), the overlay pages (menu, party, details, journal, quests, saves) and the reward/notice cards.

## 10. Maps

See `docs/map_authoring.md`. Short version: `areas/*.tscn` are hand-editable scenes; `scripts/dev/layouts/*_layout.gd` plus `scripts/dev/bake_area.gd` generated their first versions; `scripts/dev/build_overworld_tileset.gd` builds `assets/tilesets/*.tres` from sheets and JSON manifests; `scripts/dev/snapshot_area.gd` renders a whole map to PNG.

## 11. Tests

`game/tests/`, run with:

```bash
cd game
godot --headless --path . --import
godot --headless -d --path . -s addons/gut/gut_cmdln.gd
```

`tests/gut_pre_run.gd` points `SaveService.save_dir` at a scratch directory so tests never touch real saves.

| Script | Covers |
|---|---|
| `test_battle_rules.gd` | Formulas: damage, hit chance, bind, run, rewards, turn order. |
| `test_battle_engine.gd` | Turn flow, statuses, cooldowns, switching, binding, running, XP, openings. |
| `test_battle_scene.gd` | Menus, panels, badges, transition hand-off (synchronous). |
| `test_overworld_strike.gd` | Strike geometry, damage parity with battle, routs, ambush, windup, partner. |
| `test_wild_creature_combat.gd` | Chase, contact, freezing, respawn. |
| `test_spawn_zone.gd` | Filling, spacing, respawn timer, shipped zones. |
| `test_areas.gd` | Every area has ground and a start; exits lead to entrances; town and Area One link. |
| `test_quest_system.gd` | Log rules, dialogue branches, rewards, save round-trip, shipped quests validate. |
| `test_save_system.gd` | Slots, backups, corruption fallback, round-trip, title Continue. |
| `test_field_ui.gd` | Party/journal/details pages, focus, reward cards. |
| `test_main_smoke.gd` | Scene instantiates, movement, input map, interaction reach, dialogue freeze. |
| `test_creature_visual.gd` | Placeholder vs art, state transitions, sprite scale. |
| `test_settings_menu.gd`, `test_screen_transition.gd` | Display options, wipe. |

Conventions: test names are sentences (`test_a_failed_binding_consumes_the_scroll...`); engine tests use `forced_roll`; scene tests set `skip_presentation` / `instant`.

## 12. Conventions for contributors and agents

- The spec in `docs/` is the rule. Code comments cite it as "Specification 11.9". If code and spec disagree, flag it; do not silently rewrite either.
- Stable ids (`creature_fire_01`, `move_ember_01`, `quest_side_leaf_hat`, `ability_swiftfoot`, `vfx_burst_fire`) are content identity; display names are free to change.
- Balance numbers live in `BattleRules`, `OverworldStrike`, `GrowthCurve` resources and Inspector exports, never inline in flow code. Mark them Provisional in a comment.
- New mechanics go in the rules layer first with a test, then get presentation.
- Missing art must degrade to a labelled placeholder, never to an error.
- Keep `addons/godot_mcp` a dev dependency: nothing under `scripts/` may reference it.
- Run the import and GUT commands above before committing. `gdformat scripts tests` and `gdlint scripts tests` are the intended formatters (see `handoff.md` for the current state of that).
- Scene files are text; small scenes, one responsibility each. Areas are separate scenes precisely so map edits do not collide with code.
