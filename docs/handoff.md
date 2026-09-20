# Handoff: Project Status and Roadmap

This file contains historical handoff details and can lag behind the current branch. See `docs/implementation_status.md` for the current verified feature and content status.

**Historical snapshot basis:** 12 September 2026, commit `71f7b25` ("added save system") plus the quest-system work later committed in `35f862e`.
**Current verification at commit `ea9ffe8`:** 203 / 203 GUT tests passing.

Read in this order: this file, then `Oathbound_Specification_v0.6.md`, then `architecture.md`. `spec_audit_2026-09-12.md` explains every divergence found when the spec was revised.

## 1. What the game is right now

A playable vertical slice of the overworld-and-battle loop in two hand-painted areas:

- **Town** (walled village, hub and starter settlement in one): Knight heals the party, Elder gives the first main quest, Merchant and Child give side quests.
- **Area One** (meadow, road, pond, ruins, altar): six spawn zones over six species, a hand-placed hostile Cinderclaw guarding the altar, a Scout NPC with the second main quest.
- Player starts with a level-7 Emberling and 5 Binding Scrolls. Roam, strike creatures on the field with F, fight 1v1 turn battles, bind creatures, level up, evolve Emberling at 16, complete twelve quests (the main chain teaches binding and support moves, then ramps the party to about level 15 for the boss), save to slots.

Roughly 10 to 15 minutes of content against a 40 to 60 minute target.

## 2. The last three pieces of work, and how they were built

These are the most recent implementations. The next developer will most likely touch them first.

### 2.0000000000 The tutorial read end to end: who speaks, who points, and who hands you on (21 September 2026)

**What:** a pass over everything the first hour actually shows the player, after playing it.

- **The dialogue box names the speaker.** It used to caption every line "BY THE ROADSIDE" and leave "Elder: " inside the words, so the name was both wrong and read twice. `DialoguePanel.split_speaker` now takes "Elder: Good morning." apart: the name goes in the caption, the words stand alone, and a line with no name (chests, the inn, battle narration) is shown as narration with no caption. A colon inside a sentence is not a name: the prefix has to be short and free of sentence punctuation, so "Listen: a healer can mend" is left whole. `DialoguePanel.body_of` is what tests compare against.
- **An arrow points at whoever is waiting.** `QuestCompass` answers two questions with no nodes and nothing instanced: who the tracked quest wants the player to reach (the turn-in actor once it is ready, the actor a TALK objective names, or the area a REACH objective names), and which way out of this area that is. Areas are read from their packed scenes through `SceneState`, so an actor two areas off still gets an arrow, pointed at the doorway that starts the route. `QuestArrow` (`scripts/ui/quest_arrow.gd`) draws the chevron; `FieldUI._aim_arrow` orbits it around the player each frame from `main.quest_arrow_point()`.
- **The main story cannot be handed back.** Talking to the giver of an active main quest used to offer "I don't think I can help anymore". It now repeats the step, and stages the lesson again if it is one. `QuestLog.abandon` refuses a main quest outright, so nothing else can drop one either. Side quests are unchanged (Specification 17.5 is about them).
- **The lesson battles explain the turn they were handed.** `OpeningLessonGuide` holds one line over the menus while the opening turn is chosen ("You swung first out in the grass, so this turn is yours"), and each lesson sets `config.opening_text` to say the same thing in the log. It narrows nothing; once that turn is spent the banner goes.
- **The strike lesson stopped nearly killing people.** Its Loambuck is level 2 rather than 4, opens at half health and carries -60% Attack. `tests/test_field_lessons.gd` plays both lesson battles out move by move and fails if the starter finishes under 60% health, so "easy" is measured rather than asserted.
- **Nobody is sent back across the map to report.** The Innkeeper gives the satchel errand (`01g`) instead of the Scout, the Apothecary gives `01h The Road Is Waiting`, and each is handed in where it ends. Every hand-off in the main chain is now a quest of its own: eight walking errands (`quest_main_02_to_the_ranger`, `02a_to_the_woodcutter`, `02b_to_the_warden`, `04_to_the_archivist`, `05_to_the_gravewright`, `06_to_the_bellkeeper`, `07_to_the_nurse`, `08_to_aldric`), each given by the person the player is standing in front of and taken in by the person they are sent to, so "go and see the Woodcutter" is tracked, arrowed and paid for rather than being a line at the end of a completion.

**Files:** new `scripts/quests/quest_compass.gd`, `scripts/ui/quest_arrow.gd`, `scripts/battle/opening_lesson_guide.gd`, `content/quests/quest_main_01h_the_road_is_waiting.tres` and the eight `quest_main_*_to_*.tres` errands, `tests/test_dialogue_panel.gd`, `tests/test_quest_compass.gd`; `scripts/dialogue_panel.gd` (speaker caption), `scripts/ui/field_ui.gd` (`_aim_arrow`), `scripts/main.gd` (`quest_arrow_point`, main quests repeat instead of dropping), `scripts/quests/quest_log.gd` (`abandon` refuses the story), `scripts/world/field_strike.gd` and `field_ambush.gd` (banner, opening text, softer quarry), `areas/{town,area_one,area_two}.tscn` and the dev layouts (who carries which quest), and the chain lists in `scripts/ui/title_screen.gd` and `tests/test_{quest_pacing,quest_system,boss_battle,support_moves,opening,items_and_shops}.gd`.

**Watch out for:** `SceneState.get_node_path` spells a path from the scene root ("./Actors/Scout"), which is why `QuestCompass.ACTORS_PATH` carries the "./". And the pacing test still holds: the walking errands are worth 10-15 XP each and ask for no kills, so the starter still reaches the Warden's boss offer at 15 and the king at 38.

### 2.000000000 Five more Scout lessons: the strike, the ambush, the rout, the bed and the counter (21 September 2026)

**What:** the Scout's teaching no longer stops at Field Mending. Five main quests sit between it and The Ruined Road, and the chain now runs `01b -> 01c -> 01d -> 01e -> 01f -> 01g -> 02`:

- **Strike First** (`quest_main_01c_strike_first`, `world/field_strike.gd`), **Caught in the Open** (`quest_main_01d_caught_in_the_open`, `world/field_ambush.gd`) and **No Battle At All** (`quest_main_01e_no_battle_at_all`, `world/field_rout.gd`) teach the three things the attack key does (Specification 7.3, extended): landing the first blow, taking one, and finishing something outright so no battle opens at all. They are guided the way the binding and mending lessons are, but the lesson happens in the world rather than on the battle screen: the Scout stages a creature and the player answers it with F, or by standing still while a hostile one closes. Each reports its own story event (`first_strike_landed`, `ambush_taken`) at the moment the blow lands, so the quest cannot get stuck on how the battle afterwards goes.
- The rout lesson stages a creature already worn down to a fifth of its health (`FieldRout.wear_down`), so the swing cannot fail to finish it whoever the player is leading with, and it is the one lesson whose blow is meant to open no battle: its record carries `needs_rout`, and a swing that leaves the creature standing does not count.
- **A Bed at the Hearthside** (`01f`) and **A Stocked Satchel** (`01g`) send the player back down to the town for the inn and the Apothecary's counter. Both are given by the Scout and handed in where they happen (`QuestData.turn_in` = `innkeeper`, `apothecary`), so nobody is walked back up the road to report a night's sleep. They reuse the events `GameState` already reported: `rested_at_inn` and `bought_item_herb_salve`.
- The two side quests that taught the same two things, `quest_side_a_proper_rest` (Old Man) and `quest_side_a_stocked_satchel` (Apothecary), were deleted; the main chain teaches them now.

**How the overworld lessons work:** `main._field_lesson` is a small dictionary holding the staged creature, the event to report, whether the lesson waits on the player's swing or the creature's, whether that swing has to rout, the battle the blow opens (empty for the rout lesson) and the instruction on screen (`FieldUI.show_prompt` / `hide_prompt`, a standing banner under the HUD that does not time out the way a notice does). `_strike` and `_on_creature_reached_player` check it, report the event and hand the matching `stage()` dictionary to `_start_wild_battle`, which now honours a `satchel` key so a lesson fought with the player's own party keeps its items. A creature staged after `_wire_area` ran has its `reached_player` connected by hand in `_spawn_lesson_creature`, without which a hostile one can strike the player forever and nothing happens. A staged creature is taken back when the lesson is staged again or the player leaves the area (`_abandon_field_lesson`), and a lesson whose creature was fought some other way quietly stops watching after the battle (`_settle_field_lesson`); the Scout stages it again next time he is spoken to.

**Files:** new `scripts/world/field_strike.gd`, `scripts/world/field_ambush.gd`, `scripts/world/field_rout.gd`, `content/quests/quest_main_01{c,d,e,f,g}_*.tres`, `tests/test_field_lessons.gd`; `scripts/main.gd` (`_field_lesson` and its helpers, `_play_field_strike`, `_play_field_ambush`, strike and ambush hooks, `satchel` key), `scripts/ui/field_ui.gd` (prompt banner), `content/quests/quest_main_01b` (complete line leads into the strike) and `quest_main_02` (requires `01f`), `areas/area_one.tscn` and `scripts/dev/layouts/area_one_layout.gd` (Scout carries eight quests), `areas/town.tscn` and `scripts/dev/layouts/town_layout.gd` (Old Man and Apothecary lose their side quests), `scripts/ui/title_screen.gd` and `tests/test_{quest_pacing,quest_system,boss_battle,support_moves,items_and_shops}.gd` (the longer chain).

**Watch out for:** the pacing test still wants the starter at about level 15 when the Warden offers the boss, so the five new quests are worth 60 XP between them and none of them asks for a kill.

### 2.00000000 Chests, havens, signed doorways, and Areas Two and Three (20 September 2026)

**What:** the two deep areas became places rather than corridors, and two rules the spec had been waiting on landed with them.

- **Chests.** `scenes/treasure_chest.tscn` / `scripts/world/treasure_chest.gd`. A chest blocks movement, glints while it is shut, and pays out coins, Binding Scrolls and items once. `GameState.opened_chests` is a set of ids saved with the journey, so a reload cannot empty the same chest twice; `main._open_chest` puts the rewards up as field notices and reports an `opened_<id>` quest event. Four chests in Area Two, three in Area Three.
- **Havens.** `GameState.record_haven` remembers the last inn bed or healer's table used (`main._talk_to` for anyone with `heals_party`, `_offer_rest` for an inn). A party routed in battle is carried there behind the battle's own wipe (`main._wake_at_haven`), or to the town when it has rested nowhere. Saved under `"haven"`.
- **Signed doorways.** `AreaExit` now signs itself in the game: a name plate, chevrons crawling towards the doorway, dull red and "(SEALED)" while a boss holds the way. Each doorway also carries an `AltarBeacon` portal; the beacon's glow material is now local to its scene, without which the last beacon to load set every other one's intensity.
- **Area Two.** `scripts/dev/populate_area_two.gd` grew from a cast-placer into the area's whole finishing pass: it seals every floor edge the plan bake left open (4505 cells - the player could walk off the map almost anywhere), fills the pits the plan drew inside the great hall, dresses the halls with crypts, urns, candles and wall torches, pitches the supply camp in the great hall (Quartermaster, Sealwright, and the Lamplighter who heals and keeps a bed), places the chests, and opens the stair down to Area Three behind the Kingsworn, who was moved into its mouth.
- **Area Three.** Rebuilt from the catacombs room it was into the dead wood of the swallowed kingdom, as a layout (`scripts/dev/layouts/area_three_layout.gd`) baked by `bake_area.gd`. It is deliberately small: one road from the stair to the barrow, a glade either side for the household knights, four spawn pockets, and the Skeleton Lord under the crowned relic at the top. The wood outside that hollow is planted solid and backed by merged collision runs (`AreaPainter.add_solid_cells`), with the king's blue braziers along the inside edge, so the map is a boss approach rather than a country to cross.
- **Art.** `tools/build_overworld_sheets.py` now also writes `undead_ground` (the pack's cracked dead earth, assembled into whole 32 px cells) and `undead_objects` (the crowned king, ribcages, ground cracks, a fallen log, the hanging dead, pale spirits, and the skull brazier recoloured to burn blue). Both are sources in `overworld.tres`; `AreaPainter.fill_dead_ground` paints the first.

**Watch out for:** `build_overworld_tileset.gd` used to drop the tileset uid on every run, which broke every scene that referred to `overworld.tres` by uid; it now writes the uid back. `ruins.png` is packed separately from the new landmarks on purpose - repacking it moves the atlas cells the town and Area One are painted with.

**Files:** `scripts/world/treasure_chest.gd`, `scenes/treasure_chest.tscn`, `scripts/world/area_exit.gd`, `scripts/world/altar_beacon.gd`, `scenes/altar_beacon.tscn`, `scripts/game_state.gd`, `scripts/main.gd`, `scripts/dev/area_painter.gd`, `scripts/dev/populate_area_two.gd`, `scripts/dev/layouts/area_three_layout.gd`, `scripts/dev/bake_area.gd`, `scripts/dev/build_overworld_tileset.gd`, `scripts/dev/overworld_tiles.gd`, `scripts/dev/snapshot_tool.gd`, `scenes/dev_tool_snapshot.tscn`, `tools/build_overworld_sheets.py`, `tests/test_chests_and_haven.gd`, `tests/test_areas.gd`.

### 2.0000000 Shop and inn side quests (19 September 2026)

- Side quests in `content/quests/quest_side_{ink_and_oath,field_medicine}.tres` use EVENT objectives that `GameState` reports itself: `bought_<item id>` in `buy_item`, `used_<item id>` in `use_item_in_field` and after a battle from `BattleEngine.items_used`, and `rested_at_inn` from `main._offer_rest`.
- `QuestData.reward_item` / `reward_item_count` pay an item on completion.
- A vendor or innkeeper with quest business still serves: an offer is followed by the counter once the reply is read, and an errand in progress opens the counter with the progress line as its greeting (`main._serves`, `_serve`).

### 2.000000 Items, vendors, the inn and townsfolk (19 September 2026)

- `ItemData` (`scripts/items/item_data.gd`) is item content loaded by `ContentRegistry` from `content/items/`. It owns the "who can this be used on" rule (`refusal`), shared by the field and the battle engine.
- `GameState.items` is the satchel (id -> count, saved under `"items"`). Binding Scrolls stay in `GameState.binding_scrolls`; buying one routes there through `add_item`.
- Battles get a copy of the satchel through `BattleConfig.items` / `item_catalog`; `BattleEngine._use_item` spends it and `main.gd` copies it back, the same pattern as scrolls. `BattleScene` has `Menu.ITEMS` and `Menu.ITEM_TARGET`.
- `WorldActor` gained `shop_stock`/`shop_title` (vendor), `runs_inn`, `chatter` (small talk that rotates each visit), `barks` (remarks over the head while on screen) and `wander_radius_cells` (strolling; paused through the `wandering_actors` group). `ShopMenu` (`scripts/ui/shop_menu.gd`) is the counter; `FieldUI` has a Satchel page (key I).
- Town layout adds the Innkeeper, Scribe, Apothecary and seven townsfolk (`_services`, `_townsfolk` in `town_layout.gd`). The layout used `Array[StringName]([...])`, which Godot 4.7.2 rejects in that script, so the bake had been failing silently; it now uses a `_ids()` helper.

### 2.00000 Scripted binding lesson, Scout turn-in (19 September 2026)

**What:** A Second Oath is now a guided battle like Field Mending (`world/field_binding.gd`, `battle/bind_tutorial_guide.gd`). Both lessons go through one path in `main.gd` (`_is_lesson`, `_play_lesson`, `_spawn_lesson_creature`, and a `_lesson` dictionary from each lesson's `stage()` carrying guide, success outcome, story event, lines and a `prepare` callable). `QuestData.turn_in` lets a quest be handed in to someone other than its giver; Beyond the Walls is handed in to the Scout. `WorldActor.current_quest`/`quest_marker` honour it, and `idle_line` makes a giver repeat their last done line. A turn-in chains straight into the same NPC's next offer. The Ruined Road's turn-in and done lines give directions to the Ranger. Field UI "Return to" text uses the turn-in actor.

### 2.0000 Area One pacing: four NPCs and five quests before the boss (19 September 2026)

**What:** between The Ruined Road and The Black Knight the player now works through Scalded Shallows (Ranger), Wings in the Wood (Woodcutter) and The Hollow Watch (Warden), with side quests Leech Shallows (Ranger) and Feathers on the Rise (Hermit). The Black Knight moved from the Scout to the Warden. Spawn levels climb along the path (den 4-6, pit 6-8, wood 8-9, graves 9-11, Guardian 10). `QuestData.recommended_level` + `caution_line` let a giver warn an under-levelled party on accept. On paper the main chain alone brings the Emberling to about 4300 XP (Lv 15; Lv 16 and evolution at 4637), so side quests or extra fights may evolve it just before the boss.

**Files:** `content/quests/quest_main_02a_scalded_shallows`, `02b_wings_in_the_wood`, `02c_the_hollow_watch`, `quest_side_leech_shallows`, `quest_side_feathers_on_the_rise`; `quest_main_02` (turn-in points to the Ranger, XP 40) and `quest_main_03` (giver Warden, requires 02c); `quest_data.gd` (pacing fields), `main.gd` (caution on accept); `areas/area_one.tscn` and `scripts/dev/layouts/area_one_layout.gd` (Ranger, Woodcutter, Hermit, Warden, zone levels, Guardian level, sealed line); `tests/test_quest_pacing.gd`.

**Art debt:** the new NPCs reuse existing sprites (Ranger = scout, Woodcutter = merchant, Hermit = elder, Warden = town knight).

### 2.000 Early-game rework: support moves and the Field Mending tutorial (19 September 2026)

**What:** the main chain no longer jumps from "find the Scout" to "kill three Emberlings". Two Scout quests sit between them: A Second Oath (bind a Loambuck) and Field Mending (a guided battle teaching support moves). Support moves are new: an ALLY-target move lets the user pick any conscious party member, benched or fighting. Loambuck now learns Mend (L1) and Bolster (L5). Binding is easier: a healthy creature binds at its species rate (~40%), rising linearly to 95% at 0 HP.

**Files:** `move_data.gd` (`Target`, `heal_percent`), `battle_action.gd` (`target_index`), `battle_engine.gd` (`_use_support_move`, `_heal`, `_apply_modifiers`, `config.enemy_modifiers`, `config.opening_text`), `battle_team.gd` (`can_target_ally`), `battle_rules.gd` (`heal_amount`, new `bind_chance`), `battle_ai.gd` (support scoring), `battle_event.gd` (`HEALED`), `battle_scene.gd` (TARGET menu, heal numbers, guide banner), new `battle_guide.gd` and `support_tutorial_guide.gd`, new `world/field_mending.gd`, `main.gd` (`_play_field_mending`, `_spawn_ambusher`, tutorial outcomes), `quest_objective.gd` (`EVENT`), `game_state.gd` (`accept_quest` counts party for BIND); content `move_mend_01`, `move_bolster_01`, `vfx_motes_mend`, `quest_main_01a_a_second_oath`, `quest_main_01b_field_mending`; `quest_main_02` now requires `01b`; Scout carries all four Scout quests; `tests/test_support_moves.gd`.

**Balance note:** the additive damage formula barely scales with level (a level-3 Emberling did 46 to a level-7 one), so the tutorial ambusher carries a battle-long -35% Attack modifier to keep the lesson unlosable in practice. Worth revisiting in the damage formula itself.

### 2.00 Seven-type chart (14 September 2026)

**Files:** `scripts/creatures/elements.gd` (appended `NATURE`, `ROT`, `STEEL`), `content/types/type_chart_mvp.tres` (28 rows), `scripts/ui/oath_theme.gd` and `scripts/visual/vfx_preset.gd` (colours and default VFX for the new types), spec bumped to v0.6 (section 10).

**How:** every type is weak to two, strong against two and resisted by two. Tests that relied on old matchups (Fire vs Earth neutral, Earth resisted by Wind) now use pairs that keep their original intent.

**Open:** no species or move uses Nature, Rot or Steel yet. Existing matchups changed: Earth now beats Fire, and Fire is resisted by Earth. The Oathbreaker (Earth/Fire) against an Emberling-led party was tuned on the old chart and needs re-simulating.

### 2.0 Monster roster and the Area 1 boss (14 September 2026)

**Files:** `tools/import_monster_sprites.py` (copies `assets/sprites/monster/*` into `game/assets/creatures/<name>/` and writes `content/sprites/<species>_battle.tres`); 17 new species (`creature_earth_03..06`, `fire_03..07`, `water_02..04`, `wind_02..06`), 10 new moves, 3 new abilities (`hellborn`, `bloodthirst`, `broken_oath`), `vfx_beam_fire`; Cinderclaw now uses the Demon_E art; `quest_main_03_the_black_knight`; `scripts/wild_creature.gd` (boss exports), `battle_config.gd` (`boss()`), `battle_engine.gd` (boss intro, bind reason, labels), `battle_scene.gd` (caption follows battle kind), `game_state.gd` (`defeated_bosses`, `record_boss_defeat`), `main.gd` (`_challenge_boss`, boss outcomes); `areas/area_one.tscn` and its layout (BlackKnight at the altar, Guardian moved down to the road's end, four new zones: SlagPit, LeechShallows, BatWood, SquireGraves); `tests/test_boss_battle.gd`.

**How:** the Oathbreaker (Black Knight_C art, level 14, Earth/Fire) stands in front of the altar. It only accepts a challenge while the Scout's third main quest is active. E interacts and opens the "Fight / Not yet" prompt. F normally performs an overworld strike, but bosses cannot be damaged or routed in the overworld, so an F strike against the Oathbreaker plays the lunge and then opens the same prompt. Normal wild creatures keep the full F behavior: a one-hit defeat skips battle, while a survivor enters battle wounded with player advantage. Losing to the boss restores it; winning raises the cap to 30 and it never returns. Boss stats were tuned with a headless simulation: a level 12-13 Emberling-led party of three wins roughly a quarter to half the time, a level-15 lead wins almost always.

**Deliberate departure:** Spec 19 describes bosses as Oathkeepers with up to three creatures. The Area 1 boss is a single creature by request; the spec section is tagged accordingly. Swapping it for an Oathkeeper later only touches `main.gd` and the scene.

**Element recolours:** the importer can rotate a red pack's colours to a Water (blue), Wind (green) or Earth (brown) palette; folders get a `_water`/`_wind`/`_earth` suffix. Rillfin (blue Lava Slime) and Gustpip (green Hellbat) lost their placeholders; Leechling, Mirelash, Dreadmere (blue) and Hexcaller (green) were recoloured to match their type; three new Water species use recolours: Brinehound (Hellhound), Mistwisp (Ghostfire, Water/Wind) and Deepcrag (Flame Golem, Water/Earth), plus the move Brine Fang. To add one, append a row to `MONSTERS` and rerun the script.

**Not placed yet:** Brinehound, Mistwisp, Deepcrag, Bulwark, Ironhorn, Cinderhulk, Ashhound, Wispflame, Hammerhorn, Mirelash, Dreadmere, Quillimp, Pyrewing, Gloomgaze and Hexcaller exist as content but spawn nowhere. They are meant for Areas 2 and 3 (or evolve from placed species).

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
- **Placeholders in play:** every species has art now. NPCs other than the Knight are coloured boxes with labels. That is by design (Spec 23) and tests cover both paths.
- **Assets and licences:** `assets/creatures/*/SOURCE.md` and `assets/player/male_hero/SOURCE.md` record sources. The golem, demon and blood-monster packs have no licence recorded ("fill in before release"). The male hero pack is unused and non-commercial. The hero uses `assets/characters/character_13.png` (superretroworld). Fonts are OFL.

## 4. Known gaps and small bugs

Ordered by how likely they are to bite.

1. **A fifth move would be lost.** No replace-or-refuse choice and no relearn NPC exist; the engine skips the move with a message. Every shipped species has exactly four learnset moves, so this cannot trigger with current content, but the first species with five moves will hit it. `CreatureInstance.replace_move`, `forget_move`, `relearnable_moves` already exist.
2. **Journal BOUND is not persisted.** It reflects the current party only. Add `bound_species` to `GameState` next to `seen_species`, set it on bind and starter, save it.
3. **XP policy differs by path.** Battle: participants. Rout and quest rewards: whole party. Pick one for routs (lead only recommended) and change `GameState.award_defeat_rewards`.
4. **Level cap stops at 30.** The Area 1 boss raises it; 40 waits for an Area 2 boss (add its id to `GameState.BOSS_LEVEL_CAPS`).
5. **Stun survives a switch-out** and fires on the creature's next action. Clear it in `BattleEngine._switch` if unwanted.
6. **Hand-placed Guardian respawns** each time Area One is re-entered; only bosses are persisted.
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

12. **Player name.** The opening exists (prologue plus the Elder at the well, Specification 4.5); name entry and a stored `player_name` do not. Small.
13. **Credits.** Areas 2 and 3, bosses 2 and 3, the full eighteen-quest main chain and the ending all ship (see `implementation_status.md`, "The story, end to end"). A credits roll after the epilogue's caption is the piece still missing. Small.
14. **Audio.** Done for the current content: `MusicService` (four CC0 tracks, see `assets/music/SOURCE.md`) and `SfxService` (CC0 hit, bind and faint sounds, see `assets/sfx/SOURCE.md`), music and effects sliders in settings. Remaining: UI sounds (menu move/confirm), move-specific sounds per element, footsteps. Small each.
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
