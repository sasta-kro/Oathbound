# Codebase status audit, 2026-09-21 (polish pass)

**Snapshot: the "Polish heavy v1" work on top of `d7add94`, 378 of 378 GUT tests passing on the working tree (was 203 of 203 at commit `ea9ffe8`).**

A point-in-time record, not a living document. It covers only the second pass over the first hour and the fixes that came with it; `codebase_audit_2026-09-21_02-11.md` holds the full picture as of 02:11 that morning. The living status document is `docs/implementation_status.md`. `Oathbound_Specification_v0.6.md` is the authority for intended gameplay, `architecture.md` for system structure.

## 1. The paddock, the lesson locks, and a menu that explains itself

**What:** a second pass over the first hour, after watching it played.

- **A crash, and the class of crash behind it.** Swinging at the ambush lesson's Emberling routed it outside any battle, so nothing ever settled the lesson and `_field_lesson.creature` was left holding a freed object; the next typed read of it took the game down. The record is now only ever unpacked through `main._staged_creature()`, which reads it untyped and hands back null once it is gone, and a staged creature's `defeated` signal settles the lesson as it dies.
- **The lessons hold the player's keys.** Each staged lesson carries a lock: the two swing lessons ([FieldStrike], [FieldRout]) stage their creature inside strike reach, turn the player to face it and leave only the attack key live; the ambush lesson ([FieldAmbush]) takes that away too, because the thing being taught is what happens to somebody standing still. `main._set_world_active` reads the lock, `_interact` and `FieldUI._input` stay shut while it holds, and `_clear_field_lesson` hands the keys back. A lesson can no longer be walked out of, swung out of, or crashed out of.
- **The paddock (Specification 9.3).** `GameState.kept` holds everyone bound but not walking, healed and saved with the journey; `take_in` puts a newly bound Oathbound in the party or in the paddock, so a full party is never a reason to refuse a scroll (`config.has_bind_destination` now asks the paddock too). `send_to_keeping` and `call_out_of_keeping` swap them, `set_lead` owns who walks in front, and the party page grew the buttons for all three plus a scrolling strip of what is kept.
- **Two more Scout lessons, and a renumbered prologue.** `01b Room for More` teaches the paddock right after the binding lesson, and `01d Who Walks in Front` teaches the lead swap after the mend; both are answered on the party page rather than in the field, through the events `kept_an_oathbound` and `changed_lead`. The prologue chain now reads `01 → 01a → 01b → 01c mend → 01d lead → 01e strike → 01f ambush → 01g rout → 01h bed → 01i satchel → 01j back to the Scout → 02`.
- **The menu.** The numbers are gone from the sidebar and the page headers, the Evolutions page is gone with them (evolution still reads on a companion's record), and two reference pages took its place: **Element chart**, a 7×7 grid built from `Content.type_chart` itself, and **Controls**, every key the game listens to plus the three field rules that are easy to miss. The journal's element filter now lists all seven elements rather than the first four.

## 2. Files touched

`scripts/game_state.gd` (`kept`, `take_in`, `send_to_keeping`, `call_out_of_keeping`, `set_lead`, save data), `scripts/main.gd` (lesson locks, `_staged_creature`, bind destination), `scripts/ui/field_ui.gd` (paddock strip, party buttons, element chart, controls, filters), `scripts/ui/oath_theme.gd` (`element_color`), `scripts/world/field_{strike,ambush,rout}.gd`, new `content/quests/quest_main_01b_room_for_more.tres` and `quest_main_01d_who_walks_in_front.tres` plus the renumbered prologue, new `tests/test_keeping.gd`, and `tests/test_{field_lessons,field_ui,quest_system,quest_pacing,support_moves,boss_battle,evolution}.gd`.

## 3. Watch out for

The field menu's pages size themselves to the canvas rather than scrolling, so wrapping the page column in a `ScrollContainer` silently collapses any page that sizes itself by expanding (it emptied the field journal). The paddock strip scrolls inside its own bounded height instead.

## 4. Also fixed

From the area-one commit `fd3b73b`: the stair to Area Two sat inside the decor collision at the altar's foot, so the player was pushed clear of a trigger that had been shrunk to one cell and could never step in; it is a cell lower and two cells deep now. And the new `TreasureChest2` had no `chest_id`, which no save could remember. Its parent `Chests` node is still hidden in the scene, which hides every chest in Area One - left alone in case that is deliberate.

