# Implementation Status

**Date:** 20 September 2026

**Commit reviewed:** `ea9ffe8`

**Automated verification:** 203 of 203 GUT tests passing

This document records current implemented behavior. `Oathbound_Specification_v0.6.md` remains the authority for intended gameplay. `architecture.md` explains system structure.

## Playable flow

The current build provides this playable sequence:

1. Start or continue a journey from the title screen.
2. Explore Town and Area One with continuous eight-direction movement.
3. Talk to NPCs and accept quests.
4. Approach a visible wild creature with E, or strike it with F.
5. Fight, bind, defeat, or escape from ordinary wild creatures.
6. Complete the third main quest and challenge the Area One boss.
7. Defeat the boss to raise the level cap from 20 to 30.
8. Save manually or continue from an autosave.

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

- Two connected areas: Town and Area One.
- Continuous analog movement with eight-direction facing.
- Visible neutral and hostile wild creatures.
- Dynamic spawn zones and timed respawning.
- Overworld companion and overworld strike.
- One-versus-one active-creature battles with parties of up to three.
- Moves, cooldowns, accuracy, priority, switching, binding, running, XP, evolution, abilities, and three status conditions.
- Five quests with acceptance, refusal, abandonment, progress, completion, rewards, and a field tracker.
- One Area One boss with quest gating, persistent defeat state, and a level-cap reward.
- Title screen, one autosave, three manual save slots, backup saves, and corruption fallback.
- Party, details, journal, quest, save, display, audio, and battle interfaces.
- Background music, battle music, binding sounds, hit sounds, faint sounds, and persisted audio settings.
- Procedural battle VFX, screen transitions, world atmosphere, and foliage animation.

## Content and art status

- Creature species: 26.
- Moves: 21.
- Abilities: 10.
- Quests: 5.
- Creature battle sprite resources: 26.
- Every shipped creature species has a battle sprite.
- No shipped species currently has a separate overworld sprite. `CreatureVisual` reuses its battle sprite in the overworld, so shipped creatures do not use placeholder visuals.
- Town NPCs and the Area One Scout have character sprites.
- Placeholder support remains available for future content with missing art.

## UI presentation status

The current interface is functional but its visual direction is temporary. It is built in code from Godot `Control` nodes, `Theme`, fonts, shaders, and `StyleBoxFlat` resources. It does not use CSS.

The current flat panels, thin borders, large typography, and web-like spacing do not fully match the pixel-art world. A later UI-art pass should replace or decorate this shell with custom pixel-art frames, buttons, cursors, icons, and battle panels. Gameplay code must remain independent from those visual assets.

Escape opens the Field Companion menu. That menu provides Journey, Companions, Field Journal, Quest Log, Save Journey, Settings, and Title Screen actions. The Settings action opens display and audio controls.

## Areas, chests and defeat (20 September 2026)

- Four areas ship: Town, Area One, Area Two (the catacombs) and Area Three (the dead wood and the barrow). Area Two leads back to Area One and on to Area Three; the stair down is sealed until the Kingsworn falls.
- Every doorway between areas carries a name plate, chevrons on the ground and an altar-beacon portal. A doorway waiting on a boss reads "(SEALED)" and its portal stays dark until that boss falls.
- Area Two has a supply camp in the great hall: two vendors and the Lamplighter, who heals the party and keeps a bed.
- Chests (`scenes/treasure_chest.tscn`) hold coins, Binding Scrolls and items. Opening one is remembered per journey, so a reload cannot empty it twice.
- A routed party wakes at the last inn bed or healer it used, and in the town when it has used neither. The coin penalty of Specification 20.1 is unchanged.

## The story, end to end (20 September 2026)

- The main chain runs thirty-two quests, Town to barrow, as one unbroken line of `requires`: seventeen through Town and Area One, eleven in Area Two, four in Area Three. Seven of them are the first hour's lessons (binding, mending, the overworld strike, the ambush, the rout, the inn, the counter) and eight are walking errands that carry the player from one quest giver to the next, so every hand-off is tracked and arrowed rather than being a parting line.
- **Area Two** is a garrison of champions who came down the stair, could not finish the rite and could not climb back. They guide, they resupply, and they hold the inside of the altar door. The Archivist gives the lore (a grieving king bargained with the god of the dead and can only be put to sleep, never killed), the Gravewright recovers seal-iron, the Bellkeeper holds the door, the Nurse outfits the player, and Aldric sends them down past the Kingsworn.
- **Area Three** is the king's own ground. The two knights in the glades are likenesses the king made of the Oathbreaker and the Kingsworn, the only two people he could still trust; they are mute because he cannot imagine what either would say to him. The real pair are still standing where the player left them.
- The ending (`scripts/world/epilogue.gd`) plays in the wood rather than in a scene of its own: the spawn zones stop, everything the king had standing thins away without dying, the area's `Tint` warms from his cold grey to daylight, and a caption reads over it before the journey hands back to the title screen. `GameState.story_complete` is saved, so a reload never replays it.
- `BOSS_LEVEL_CAPS` cannot raise anything past the ceiling by the time the king falls, so `GameState.FINAL_BOSS_TEXT` announces him instead.
- The title screen carries a `Dev: the ending` shortcut: Area Three, a level-38 lead, the chain behind the player and the king still to fight.

## Main open gaps

- Hostile Oathkeeper encounters do not exist; the two Area Three elites are the king's own likenesses of the Oathbreaker and the Kingsworn, which is why both species are met twice.
- Selling items, key items, Creature Hotel, and Experience Vessel use do not exist. Buying, the satchel, battle and field item use, two town vendors, the camp vendors and the inn do.
- Move replacement and move relearning do not exist.
- Permanent ever-bound journal state is not saved.
- World reset after defeat does not exist; the party wakes at its haven and the world is left as it was.
- Control rebinding does not exist.
- Custom pixel-art UI assets do not exist.
