# Implementation Status

**Date:** 21 September 2026

**Commit reviewed:** `17fb9f2`

**Automated verification:** 346 of 346 GUT tests passing

This document records current implemented behavior. `Oathbound_Specification_v0.6.md` remains the authority for intended gameplay. `architecture.md` explains system structure. `docs/audits/` holds dated point-in-time status audits; read the newest for the last full picture.

## Playable flow

The current build provides this playable sequence:

1. Start or continue a journey from the title screen.
2. Explore Town and Area One with continuous eight-direction movement.
3. Work through the taught first hour: binding, field mending, the overworld strike, the ambush, the rout, the inn and the satchel.
4. Approach a visible wild creature with E, or strike it with F.
5. Fight, bind, defeat, or escape from ordinary wild creatures; use satchel items in the field and in battle; buy from vendors and rest at the inn.
6. Complete the main quests, challenge the Area One boss, and raise the level cap.
7. Descend through Area Two (sealed stair, garrison camp, chests) and into Area Three.
8. Defeat the king in the barrow; the epilogue plays once and stays ended across saves.
9. Save manually or continue from an autosave; a routed party wakes at its last haven.

## Overworld input and encounters

- E is the interaction action. On a normal wild creature, E starts a neutral battle without overworld damage.
- F is the overworld strike action. The lead Oathbound attacks the nearest creature in the strike area.
- A normal creature defeated by the F strike is routed in the overworld. No battle scene opens. XP and currency are awarded, but no binding opportunity remains.
- A normal creature that survives the F strike enters battle with reduced HP. The player side acts first on turn one.
- A hostile creature can strike first after its windup. The battle then starts with the creature side acting first.
- A boss cannot be routed by the overworld strike. E starts the challenge prompt. F plays the strike lunge and then starts the same challenge prompt.

## Binding rules

Binding is enabled during an ordinary wild battle when all of these conditions are true:

- At least one Binding Scroll remains.
- The party has space for the new Oathbound.
- The target is not a boss.
- The target does not belong to an Oathkeeper.

Boss battles disable binding and running. Trainer battles disable binding. The Item command uses satchel items on any party member and is disabled when no held item would help.

## Implemented systems

- Four connected areas: Town, Area One, Area Two (the catacombs), Area Three (the dead wood and the barrow).
- Continuous analog movement with eight-direction facing.
- Visible neutral and hostile wild creatures.
- Dynamic spawn zones and timed respawning.
- Overworld companion and overworld strike with rout, wounded entry, and ambush openings.
- One-versus-one active-creature battles with parties of up to three.
- Moves, cooldowns, accuracy, priority with turn-order indicators, switching, support moves with ally targeting, item use, binding, running, XP, evolution, abilities, three status conditions, and a damage floor.
- Guided tutorial battles and scripted field lessons. The Scout's two party-page lessons (keeping and leading) are guided too: the player is held at the fire with only Tab answering, and the page names and highlights one button per step while the other actions stay locked. A key the Scout is teaching (F, Tab) goes through his lines, so pressing it mid-dialogue accepts the lesson and does what the key does.
- Thirty-two main quests and six side quests with acceptance, refusal, abandonment, progress, completion, rewards, turn-in to a non-giver, a field tracker, and a quest compass with HUD arrow.
- Boss gating with persistent defeat state, level-cap rewards, sealed doorways, and altar-beacon portals.
- Items, the satchel, vendors, the inn, chests, and haven-based defeat recovery.
- An epilogue that plays once and persists.
- Title screen, one autosave, three manual save slots, backup saves, and corruption fallback.
- Party, details, journal, quest, satchel, save, shop, inn, display, audio, and battle interfaces.
- Background music, battle music, binding sounds, hit sounds, faint sounds, and persisted audio settings.
- Procedural battle VFX, screen transitions, world atmosphere, and foliage animation.

## Content and art status

- Creature species: 61 (7 to 10 per primary type; 23 evolution lines).
- Moves: 36.
- Abilities: 15.
- Quests: 38 (32 main, 6 side).
- Items: 5.
- Types: 7 (fire, earth, water, wind, nature, rot, steel).
- Creature battle sprite resources: every shipped species has one.
- No shipped species currently has a separate overworld sprite. `CreatureVisual` reuses its battle sprite in the overworld, so shipped creatures do not use placeholder visuals.
- Town and area NPCs have character sprites; several newer NPCs reuse existing ones.
- Placeholder support remains available for future content with missing art.

## UI presentation status

The current interface is functional but its visual direction is temporary. It is built in code from Godot `Control` nodes, `Theme`, fonts, shaders, and `StyleBoxFlat` resources. It does not use CSS.

The current flat panels, thin borders, large typography, and web-like spacing do not fully match the pixel-art world. A later UI-art pass should replace or decorate this shell with custom pixel-art frames, buttons, cursors, icons, and battle panels. Gameplay code must remain independent from those visual assets.

A passage with blank lines in it is shown one box at a time: the interact key walks the boxes, the speaker's caption stands over all of them, and a question's replies appear on the last box, so the ask is read through before it can be answered. `DialoguePanel.pages_of` does the splitting and `read_through` walks to the end. The strike key cannot cancel a question part-way through it.

Escape opens the Field Companion menu. Q is the standard back action, with Escape retained as a secondary back binding. Arrow keys mirror WASD, and Enter mirrors E. The menu provides Journey, Companions, Field Journal, Quest Log, Save Journey, Settings, and Title Screen actions. The Settings action opens display and audio controls.

## Areas, chests and defeat (20 September 2026)

- Four areas ship: Town, Area One, Area Two (the catacombs) and Area Three (the dead wood and the barrow). Area Two leads back to Area One and on to Area Three; the stair down is sealed until the Kingsworn falls and Aldric has been told.
- Every doorway between areas carries a name plate, chevrons on the ground and an altar-beacon portal. A doorway waiting on a boss reads "(SEALED)" and its portal stays dark until that boss falls.
- A doorway can also wait on a quest (`AreaExit.required_quest`) on top of its boss, because a boss beaten in the field is not the same as a boss reported back to whoever sent the player. Both stairs between areas do: the one under the altar names `boss_area_01` and `quest_main_03_the_black_knight`, and the one down to the dead city names `boss_area_02` and `quest_main_09_the_kingsworn`. Beating the knight is not enough on its own; the way stays shut, with its own line (`unreported_line`) pointing the player back at the Warden or at Aldric, until they have heard it. The altar beacons still light on the boss alone, because the light is the knight falling rather than the way opening.
- Area Two has a supply camp in the great hall: two vendors and the Lamplighter, who heals the party and keeps a bed.
- Chests (`scenes/treasure_chest.tscn`) hold coins, Binding Scrolls and items. Opening one is remembered per journey, so a reload cannot empty it twice.
- A routed party wakes at the last inn bed or healer it used, and in the town when it has used neither. The coin penalty of Specification 20.1 is unchanged.

## The story, end to end (20 September 2026)

- The main chain runs thirty-two quests, Town to barrow, as one unbroken line of `requires`: nineteen through Town and Area One, eleven in Area Two, two in Area Three. Seven of them are the first hour's lessons (binding, mending, the overworld strike, the ambush, the rout, the inn, the counter) and eight are walking errands that carry the player from one quest giver to the next, so every hand-off is tracked and arrowed rather than being a parting line.
- **Area Two** is a garrison of champions who came down the stair, could not finish the rite and could not climb back. They guide, they resupply, and they hold the inside of the altar door. The Archivist gives the lore (a grieving king bargained with the god of the dead and can only be put to sleep, never killed), the Gravewright recovers seal-iron, the Bellkeeper holds the door, the Nurse clears the road to her bench, and Aldric sends them down past the Kingsworn.
- **Area Three** is the king's own ground, and it is deliberately short: two quests, the wood and the king. The Last Champion at the foot of the stair tells the player everything in one sitting and then keeps the stair. The two knights in the glades are likenesses the king made of the Oathbreaker and the Kingsworn, the only two people he could still trust; they are mute because he cannot imagine what either would say to him. The real pair are still standing where the player left them. They are field enemies rather than quest objectives, along with the road's Cinderhulks and gazers, so the last stretch is ground the player levels on rather than a guided climb: the chain alone reaches about level 33 against the king's recommended 38.
- The ending (`scripts/world/epilogue.gd`) plays in the wood rather than in a scene of its own: the spawn zones stop, everything the king had standing thins away without dying, the area's `Tint` warms from his cold grey to daylight, and a caption reads over it before the journey hands back to the title screen. `GameState.story_complete` is saved, so a reload never replays it.
- `BOSS_LEVEL_CAPS` cannot raise anything past the ceiling by the time the king falls, so `GameState.FINAL_BOSS_TEXT` announces him instead.
- The title screen carries a `Dev: the ending` shortcut: Area Three, a level-38 lead, the chain behind the player and the king still to fight.

## Main open gaps

- Hostile Oathkeeper encounters do not exist; the two Area Three elites are the king's own likenesses of the Oathbreaker and the Kingsworn, which is why both species are met twice.
- Selling items, key items, and Experience Vessel use do not exist. The paddock (`GameState.kept`) keeps whatever a full party cannot carry, and the party page sends Oathbound in and out of it. Buying, the satchel, battle and field item use, two town vendors, the camp vendors and the inn do.
- Move relearning does not exist. Move replacement does: a fifth move is queued on `GameState.pending_move_learns` and offered on `MoveLearnScreen` once the field is calm.
- Permanent ever-bound journal state is not saved.
- World reset after defeat does not exist; the party wakes at its haven and the world is left as it was.
- Control rebinding does not exist.
- Custom pixel-art UI assets do not exist.
