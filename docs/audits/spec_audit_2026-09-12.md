# Specification v0.4 vs. Implementation Audit

**Date:** 12 September 2026
**Basis:** `docs/archive/Oathbound_Specification_v0.4.md` (25 Aug 2026) against the working tree at commit `71f7b25` ("added save system") plus the uncommitted quest-system work.
**Test state at audit:** 14 GUT scripts, 192 tests, 192 passing (`godot --headless -d --path game -s addons/gut/gut_cmdln.gd`).

This document is the diff between what the spec says and what the code does. It fed the v0.5 spec revision. Read it once for context; the living documents are `Oathbound_Specification_v0.5.md`, `architecture.md` and `handoff.md`.

Three categories:

- **Superseded**: the code deliberately does something different from v0.4, and the v0.5 spec adopts the code's behavior.
- **Inconsistent**: the code diverges from the spec in a way that is not a design decision. Either the code or the spec should change. Each has a recommendation.
- **Addition**: implemented behavior the spec never described. v0.5 documents it.
- **Not implemented**: spec'd MVP features with no code yet. Listed at the end, grouped by area, so the roadmap in `handoff.md` has a source.

---

## 1. Superseded (code wins, spec v0.5 updated)

| Spec section | v0.4 said | Code does | Where |
|---|---|---|---|
| 21.1 Save model | One autosave slot, no manual save command | Three manual slots (`slot_1..3.json`) plus one autosave (`autosave.json`), each with a `.backup`; "Save journey" page in the field menu; title screen offers Continue / Load / Begin anew | `scripts/save/save_service.gd`, `scripts/ui/save_slot_list.gd`, `scripts/ui/title_screen.gd`. The docstring in `game_state.gd` records this as a deliberate departure made on request. |
| 7.3 Hostile creature contact | Hostile creature enters battle on reaching an adjacent tile | Hostile creature chases, stops at reach, **winds up for 0.45 s**, then lands an overworld strike. The blow does real damage (ambush, 0.6x, never below 1 HP) and the battle opens with the creature taking turn one. Stepping out of reach during the windup dodges it. | `scripts/wild_creature.gd` (`STRIKE_WINDUP_SECONDS`, `_land_strike`), `scripts/world/overworld_strike.gd`, `scripts/main.gd::_on_creature_reached_player` |
| 6.1 Interaction | "Interact from adjacent tiles" | Interaction reach is a radius of 1.5 cells from the player, any direction, because movement is analog | `scripts/main.gd::INTERACTION_REACH_IN_CELLS` |
| 11.3 Turn resolution | Priority, then Speed, then random | Same from turn two. **Turn one** is forced by how the encounter opened: a player strike gives the player the first action, an ambush gives it to the creature, regardless of priority or speed | `scripts/battle/battle_engine.gd::_turn_order` |
| 5.1 World layout | Hub 1 and Area 1 starter settlement are distinct zones | One `town.tscn` is both the hub (healer NPC) and the starter settlement; `area_one.tscn` is the meadow. Topology so far: `Town <-> Area One`. | `game/areas/`, `scripts/dev/layouts/` |
| 9.7 Evolution prompt | Evolution offered at level-up, player may refuse | Level-up only announces "ready to evolve". The player evolves from the companion record in the field menu whenever they choose. No prompt interrupts a battle. | `scripts/ui/field_ui.gd::_details`, `_evolve` |
| 4.5 Opening sequence | 1-2 minute opening, NPC gives starter and 5 scrolls | No opening. `GameState.ensure_starter()` grants a level-7 Emberling and 5 scrolls silently when the party is empty. The Elder's first quest is the de facto tutorial hook. | `scripts/game_state.gd` |
| 22.4 Pause menu | Separate pause menu | The field menu (Esc) is the pause menu: Journey / Companions / Field journal / Quest log / Save journey, plus Settings and Title screen buttons | `scripts/ui/field_ui.gd` |

## 2. Inconsistent (needs a decision)

| # | Spec section | Spec | Code | Recommendation |
|---|---|---|---|---|
| I-1 | 9.5 XP distribution | Only participants of the battle receive XP | In-battle: participants only (`Battler.participated`). **Overworld rout** (`GameState.award_defeat_rewards`) and **quest XP rewards** pay every non-fainted party member. Two different policies for the same reward. | Decide one policy. Simplest: routs pay the lead only (it threw the blow). Quest XP to whole party is reasonable and can stay. Documented as Provisional in v0.5. |
| I-2 | 22.7 Bestiary "bound" | Track whether a species has ever been bound | Journal shows BOUND only while a creature of that species is in the current party. `seen_species` is persisted; "ever bound" is not. Binding then losing (future Hotel/delivery quests) will regress the entry to SEEN. | Add `bound_species` to `GameState` next to `seen_species`, set on bind and on starter. Small change, save format gains one key. |
| I-3 | 9.8 Move learning | Fifth move: choose one to forget or refuse; forgotten moves relearnable at a Hub 1 NPC | Fifth move is **skipped** with a message (`MOVE_LEARN_SKIPPED`). No relearn NPC exists, so the move would be lost. `CreatureInstance.relearnable_moves()` exists and is ready for the NPC. | Implement the replace-or-refuse choice (battle scene menu + field notice) and the relearn service. Not reachable with shipped content: every species has exactly four learnset moves. Becomes real with the first five-move species. |
| I-4 | 20.1 Party defeat | Return to last revival location, world resets | Heal in place, deduct 50 coins, dialogue line. No revival location concept, no world reset. | Fine until a second healer exists. When Hub services land, record `last_revival_area`/position in `GameState` and travel there on defeat. |
| I-5 | 11.2 Item action | Five actions including Item | Item row exists but is always disabled ("You have no usable items."). No inventory. | Expected; items are unimplemented. Keep the row so the UI contract holds. |
| I-6 | 12.3 Stun | Clears after preventing one action | Correct for the active creature. A stunned creature that is switched out keeps its stun (stun is not ticked by time), and it fires on its next action, possibly many turns later. | Acceptable edge case for MVP; note it. If unwanted, clear stun on switch-out. |
| I-7 | Tech stack: Git LFS | Large binaries via LFS | No `.gitattributes` in the repo; `git lfs` not installed on the dev machine. All PNGs are in normal Git history. | Either add LFS now (rewrite history or accept from here on) or drop the LFS line from the setup doc. v0.5 marks it "not yet configured". |
| I-8 | Tech stack: gdformat/gdlint | All GDScript formatted and linted | Several UI scripts (`field_ui.gd`, `title_screen.gd`, `dialogue_panel.gd`, `save_slot_list.gd`, `creature_portrait.gd`) use one-line `if x: y` and lambda styles that `gdformat` rewrites. gdtoolkit is not installed on the dev machine. | Install gdtoolkit, run `gdformat scripts tests`, commit the reformat separately. Add `gdlint` to the validation checklist for real. |
| I-9 | Tech stack: CI | Headless CI runs tests | No CI configuration in the repo. | Add a GitHub Actions workflow running import + GUT (see `handoff.md`). |
| I-10 | README | "`game/main.tscn` Launch scene"; refers to an `AGENTS.md` | `project.godot` launches `scenes/title_screen.tscn`; `AGENTS.md` is listed in `.gitignore` and not present in the repo | README updated in this pass. Decide whether `AGENTS.md` should be tracked; if it stays local, remove the README reference (done) and put agent conventions in `docs/architecture.md` (done). |
| I-11 | 23.5 Missing audio diagnostics | Silent + logged diagnostic per missing sound/music id | There is no audio system at all; `DevLog.missing_asset` only ever receives "sprite". | Expected. When audio lands, route through `DevLog.missing_asset("sfx", id)` / `("music", id)`. |
| I-12 | 7.2 Respawn after healing | Creatures may respawn after a healing service | Respawn is timer-only (`respawn_seconds`, default 20 s) plus full refill on area load. Healing does not touch spawns. | Fine. Spec wording is "may". |
| I-13 | 22.5 Battle info | Show "player and enemy type(s)" and "type-effectiveness hint" | Both shown. The stage caption is hard-coded "WILD ENCOUNTER" even though `BattleConfig.trainer()` exists. | Make the caption follow `config.is_wild` when trainers land. |

## 3. Additions (in code, absent from v0.4, now in v0.5)

| Addition | Summary | Where |
|---|---|---|
| **Innate abilities (new spec 9.9)** | Every species has an `ability_pool`; each creature carries exactly one `AbilityData`. Abilities are declarative: passive stat modifiers, outgoing/incoming damage multipliers (optionally type-filtered), status immunities, inflicted-status chance bonus. Wild creatures roll one per encounter; placed creatures can pin one in the Inspector. Ability carries over evolution when the new species can have it. Code already cites "Specification 9.9" and "9.9.2-9.9.4", which did not exist. | `scripts/creatures/ability_data.gd`, `creature_species.gd`, `creature_instance.gd`, `battle_rules.gd`, `battler.gd`. 7 abilities in `content/abilities/`. |
| **Overworld strike (new spec 7.5)** | F key. The lead Oathbound (walking beside the player as `OverworldPartner`) throws its best damaging move at the nearest creature inside a 150-degree wedge, reach 2.4 cells, point-blank 1.25 cells, 0.45 s cooldown. Damage is exactly battle damage. A creature that survives enters battle wounded with the player acting first ("advantage"); one that drops is "routed" on the spot and pays the same XP and coins a battle would, minus the chance to bind. Creatures show a thin HP bar once hurt; overworld damage persists on the creature until it is defeated or respawned. | `scripts/player.gd`, `scripts/world/overworld_partner.gd`, `scripts/world/overworld_strike.gd`, `scripts/main.gd::_strike`, `_rout` |
| **Overworld partner** | The lead creature follows the player on a breadcrumb trail, snaps to the player after battles and area swaps, disappears when nobody can fight. | `scripts/world/overworld_partner.gd` |
| **Run/escape formula** | `chance = clamp(0.5 * runner_speed / chaser_speed + 0.15 * previous_attempts, 0.1, 0.95)` | `battle_rules.gd::run_chance` |
| **Reward formulas** | XP for a defeat = `round((base_hp+atk+def+spd) * level / 6)`, min 1. Coins = `10 + 5 * level`. Defeat penalty 50 coins. | `battle_rules.gd`, `game_state.gd` |
| **Growth curve resource** | `GrowthCurve` `.tres` per species: stats `floor(base * (1 + 0.06*(L-1)))`, HP `floor(base*(1+0.09*(L-1))) + 2*(L-1)`, XP total `round(12 * (L-1)^2.2)`. Two curves shipped (`growth_standard`, `growth_bulky`). | `scripts/creatures/growth_curve.gd`, `content/growth/` |
| **Cooldown semantics** | A move with cooldown N is unavailable for exactly the next N turns after use (stored as N+1, ticked at end of the turn it was used). Benched creatures tick too. | `battler.gd::start_cooldown` |
| **Wait action** | When every move is on cooldown the player (and AI) waits the turn. Not in spec's five actions. | `battle_action.gd::wait` |
| **VFX preset system** | All effects drawn by one procedural shader; `VfxPreset` resources choose pattern/colours/timing; moves reference a preset or fall back to an element default. `scenes/vfx_preview.tscn` is a workbench. | `scripts/visual/vfx_*.gd`, `shaders/vfx_shapes.gdshader`, `content/vfx/` |
| **Screen transition** | Tile-wipe shader between world and battle; battle covers itself on close. | `scripts/ui/screen_transition.gd`, `shaders/tile_wipe.gdshader` |
| **World atmosphere** | Full-screen colour grade, vignette, cloud shadows, pollen; foliage sway shader on the Foliage tile layer. | `scripts/world/world_atmosphere.gd`, `shaders/world_atmosphere.gdshader`, `shaders/foliage_sway.gdshader` |
| **Field journal filters** | Search by name/element, element filter chips, species record page with level-1 stats and evolution line. | `field_ui.gd::_journal` |
| **XP reward cards** | Non-blocking side cards animate XP bars and level-ups; at most three visible, rest queued. | `field_ui.gd::show_xp` |
| **Set lead companion** | Party record lets a healthy companion become party lead (reorders `GameState.party`). | `field_ui.gd::_set_lead` |
| **Quest system details** | Statuses NEW/REFUSED/ACTIVE/ABANDONED/COMPLETED; `requires` chain; per-actor `quest_ids` with priority ready > active > offerable; eight dialogue lines per quest with defaults; talk/reach/defeat/bind objectives; rewards coins/scrolls/XP; quest log page and notices. | `scripts/quests/`, `content/quests/`, `main.gd::_talk_to` |
| **Dialogue choices** | `DialoguePanel.ask(line, options)` returns the chosen index; W/S to choose, E to confirm, mouse works. | `scripts/dialogue_panel.gd` |
| **Display service** | Window scale multiples of 960x540, borderless fullscreen (F11 / Alt+Enter), settings persisted to `user://settings.cfg`. | `scripts/display/display_service.gd` |
| **Content registry + validation** | Autoload `Content` indexes species/moves/abilities/quests by `id`; `validate()` reports dangling references. Tests call it. | `scripts/content/content_registry.gd` |
| **Map pipeline** | Layout scripts + `AreaPainter` bake `.tscn` areas; tileset builder from JSON manifests; snapshot tool. Documented in `map_authoring.md`. | `scripts/dev/` |
| **Play time + save metadata** | `play_seconds`, `saved_at`, `format_version` in the save. | `game_state.gd`, `save_service.gd` |
| **Dev diagnostics toggle** | `oathbound/dev/verbose_diagnostics` project setting (defaults to debug builds). | `scripts/dev/dev_log.gd` |

## 4. Verified matches (no action)

Type chart and STAB 1.5 (10.2-10.4), damage formula and level multiplier (11.8), no damage roll (11.7), stat modifier stacking and 0-200 % clamp (11.9), cooldowns replace PP (11.10), poison 10 % / burn 5 % + -25 % attack / stun (12), forced replacement keeps its turn (11.5), switch/bind/run priorities (11.4), binding formula and 5-95 % clamp (15.3), bind blocked with no destination or scrolls or in trainer battles (15.1, 15.4), party cap 3 (9.2), 4 move slots (9.8), global cap 40 and story cap 20 (9.4), XP awarded per defeated enemy mid-battle (9.5), currency on wild victory (13.2), player loses when wiped (13.1), ordinary AI never switches or uses items and prefers effective moves (14.1), 16:9 960x540 logical viewport with letterboxing (22.3), placeholder colours and frame counters (23.2-23.3), stable content ids (25.2), no deferred feature implemented (27).

## 5. Not implemented (MVP scope still open)

Grouped by spec area. Nothing here is started unless noted.

**World and story (4, 5)**
- Areas 2 and 3, bosses, progression gates, level-cap raises (cap is stuck at 20 with no code path to raise it).
- Opening sequence, player name entry, ending and credits.
- Only 6 species and 10 moves against targets of 15-25 and 25-40.

**Overworld (6, 8)**
- Hostile Oathkeepers / trainers: no NPC type, no line-of-sight, no defeat persistence. `BattleConfig.trainer()` and multi-creature enemy parties already work in the engine, so the gap is overworld-side.
- Doors, signs, chests, switches, pressure plates, secrets, NPC patrol routes.

**Creatures (9)**
- Creature Hotel (binding with a full party is simply refused before the scroll is spent).
- Experience Vessel (over-cap XP is counted in `BattleEngine.xp_over_cap` and `XpResult.excess`, then discarded).
- Move replace-or-refuse choice and the relearn NPC (see I-3).
- "Cannot remove final Oathbound" rule has nothing to guard yet.

**Items and economy (16)**
- Inventory, item categories, shops, selling, scroll grades (only the basic 1.0x multiplier exists), healing cost. Currency and scroll counts exist and are saved.

**Quests (17)**
- Retrieve-item and escort objective kinds; item and Oathbound rewards; capture-and-deliver handover; quest markers on a map.

**Dialogue (18)**
- Only quest dialogue branches. Sparring offers, shop price modifiers, temporary NPC state are absent.

**Battle (11, 14)**
- Trainer battles from the overworld, boss AI profile, item use in battle.

**UI (22)**
- Control rebinding, audio settings (no audio at all), inventory screen, shop screens. Party, details, journal, quest log, settings (display only), save/load and battle screens exist.

**Persistence (21)**
- Defeated trainers, bosses, opened chests, area unlocks, revival location, hotel, vessel, inventory: no state yet to save. Save format is versioned (`format_version: 1`) so these can be added.

**Tooling**
- Git LFS, CI, gdformat/gdlint enforcement (I-7 to I-9).
