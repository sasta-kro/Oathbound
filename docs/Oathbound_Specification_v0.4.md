# Oathbound - Complete Game Specification v0.4

**Status:** Draft single source-of-truth specification for human developers and AI coding agents  
**Date:** 25 August 2026  
**Scope:** Game behavior, content rules, story, player experience, changeability requirements, placeholder policy, and agent interpretation guardrails. This is not an implementation or Godot architecture document.


**Tech Stack:** [[#Oathbound - Complete Game Specification v0.4#Tech Stack]]

## 1. Document Purpose and Authority

This document defines the intended behavior of **Oathbound**, a short 2D pixel-art creature-collecting RPG heavily inspired by Pokemon. It consolidates the project proposal and the three design Q&A rounds into one normalized specification.

This file is the **single shared source of truth** for both human developers and AI coding agents. There is no separate agent rules document. Human and AI contributors must interpret gameplay requirements, deferred features, placeholders, and changeability rules from this file.

The following rules apply when reading or implementing this specification:

- The latest decision in this document supersedes earlier drafts, proposal wording, examples, and discarded ideas.
- References to games such as Pokemon describe inspiration or intended player experience only. They do not authorize importing additional mechanics that are not explicitly specified here.
- A mechanic marked **MVP** is part of the current game scope.
- A rule marked **Provisional** is part of the MVP but its exact value or formula may be tuned without changing the surrounding mechanic.
- A rule marked **TBD** has not been finalized. Where necessary for a playable build, use a clearly identified sane placeholder rather than inventing additional systems.
- A feature marked **Deferred** or **Future** is not part of the MVP and must not be implemented unless a developer explicitly requests it.
- Game behavior should remain changeable where the design is intentionally unsettled. A change to a formula, content table, roster, objective, or balance value should not require redesigning unrelated gameplay systems.
- Final audiovisual assets are not required for the game to remain fully playable and testable.

## 2. High-Level Game Summary

**Oathbound** is a top-down, grid-based 2D RPG about exploring a fantasy region, forming magical oaths with creatures, building a party of up to three Oathbound, completing quests, and defeating hostile Oathkeepers who have destabilized remote communities.

The game is inspired by the pacing and structure of early creature-collecting RPGs, but it is intentionally smaller and faster. The core release is designed as a polished short experience rather than a long content-heavy RPG.

### 2.1 Target Play Length

- Main story, direct play: approximately **40 to 60 minutes**.
- Normal first playthrough with exploration: approximately **1 to 2 hours**.
- High-completion playthrough including most side quests and optional content: approximately **2 to 3 hours**.

### 2.2 Design Pillars

1. **Fast creature battles** - turn-based battles should resolve quickly and avoid unnecessary pauses.
2. **Small but lived-in world** - areas should contain roaming creatures, hostile and friendly NPCs, quests, shops, secrets, and environmental detail.
3. **Simple systems with room to tune** - mechanics should be understandable and content values should be easy to change during development.
4. **Creature collection without roster bloat** - the active party is intentionally small, with additional Oathbound handled through a dedicated storage service.
5. **Light adventure with serious moments** - the tone should feel upbeat, cool, and adventurous, with occasional semi-dark fantasy elements.
6. **Playable before art completion** - all gameplay must work with placeholders so programming and content work can proceed independently from asset collection.
7. **Designed for extension without speculative complexity** - systems should leave clear extension points for plausible future mechanics and content changes, so features can be added or replaced later without major refactors, while avoiding premature implementation of features that are not part of the current scope.

## 3. Terminology

| Term | Meaning |
|---|---|
| Creature | A wild magical creature that exists in the world. This remains the general species/entity term. |
| Oathbound | A creature that has formed a magical oath with a human. "Bound creature" or "contracted creature" may be used sparingly when first explaining the concept or for character flavor. |
| Oathkeeper | A person who commands or travels with Oathbound. This includes hostile trainers, friendly battlers, and many knights. |
| Binding | The gameplay process of forming an oath with a wild creature. |
| Binding Scroll | The physical consumable used to attempt a binding. Multiple grades exist. |
| Knight Order | The region's knight and law-enforcement organization. Formal organization name is currently generic and may be renamed. |
| Hub 1 | The central safe town/hub used by the MVP. Final in-world name is TBD. |
| Experience Vessel | Working name for the permanent item that stores a portion of XP earned above the current story-based level cap. Final in-world name is TBD. |

The game title **Oathbound** refers to the central concept of humans and creatures forming magical oaths.

## 4. World, Tone, and Story

### 4.1 World Premise

Humans and magical creatures have coexisted for a long time. Creatures are not inherently evil, including creatures with undead, demonic, or otherwise intimidating appearances. Most creatures have animal-like or pet-like intelligence, although rare lore-level exceptions may possess human-level intelligence. Such exceptional beings are not part of the normal playable creature roster in the MVP.

Forming oaths with creatures is a normal and accepted part of society. Oathbound are used for many purposes beyond combat. A gardener may work with plant-oriented creatures, while emergency workers may rely on water-oriented creatures. Combat-focused Oathkeepers are only one part of this culture.

The exact metaphysics of binding are intentionally left somewhat ambiguous. The game should not frame ordinary binding as slavery or forced magical domination. The cultural assumption is that a successful binding results in a stable magical partnership after the creature has been challenged and subdued.

### 4.2 Knight Order

The Knight Order acts as a medieval-fantasy law-enforcement and protective organization. Its members use Oathbound to defend settlements, protect travelers, and confront dangerous people or creatures.

The protagonist looks up to the knights and wants to become one. The country is poor, the Knight Order is stretched thin, and the MVP's regions are remote enough that serious local threats have not been resolved quickly.

### 4.3 Current Crisis

Three powerful hostile Oathkeepers operate independently across the three main areas. They are not a formal trio one does not control another. There may be relationships between them but that is not important for now and not decided yet. 

Their behavior includes abuse of creatures, trafficking, mistreatment, violent use of contracts, exploitation of local populations, and similar harmful acts. Their actions have made local wild creatures increasingly aggressive and distrustful of humans. The combined effect of these abuses is a region where creature encounters are more dangerous and normal life is being disrupted.

The villains are intentionally straightforward rather than psychologically complex. The game should spend its limited runtime on adventure and gameplay rather than extensive villain backstory.

### 4.4 Protagonist Motivation

The protagonist is a young squire or aspiring knight living in the starter settlement of Area 1. When the Knight Order calls for brave local volunteers, the protagonist chooses to help rather than being personally ordered on the mission.

The protagonist's immediate goal is to help restore safety to the region. Becoming a knight is an important personal ambition and a final reward, but it is not the only reason for the journey.

There is no required mentor character and no rival character in the MVP.

### 4.5 Opening Sequence

The opening should take approximately **1 to 2 minutes** before normal exploration begins.

Current sequence:

1. The player begins at their home in the Area 1 starter town.
2. The player meets a Knight Order representative or tutorial NPC.
3. The Knight Order explains the immediate local problem without a long lore dump.
4. The protagonist volunteers to help.
5. The protagonist receives one beginner creature as their starter Oathbound.
6. The protagonist receives **5 Binding Scrolls**.
7. A short tutorial introduces movement, interaction, and basic battle/binding concepts.
8. Area 1 becomes freely explorable after the tutorial.

Information about later villains is revealed progressively. The player should learn about Areas 2 and 3 piece by piece rather than through a large opening exposition sequence.

### 4.6 Boss Identities

- **Area 1 Boss:** Placeholder identity. A local gatekeeper/guardian-type hostile Oathkeeper who controls progress through the first region.
- **Area 2 Boss:** Placeholder identity. An independent hostile Oathkeeper operating in or around the catacomb region.
- **Area 3 Boss:** Placeholder identity with the nickname **Demon Knight**. The nickname reflects the character's cruelty and reputation, not the species or type of their creatures. This is the final antagonist of the current release.

Boss names, exact personalities, dialogue, and rosters remain content placeholders.

### 4.7 Ending

Defeating the Area 3 boss completes the current main story.

The ending should:

1. Show a short scene indicating that local creature aggression is beginning to settle.
2. Confirm that the immediate regional crisis has been resolved.
3. Recognize the protagonist's actions publicly.
4. Have the protagonist formally become a knight.
5. Roll credits.
6. Return the player to the playable world after the credits.

The local story should feel complete, while the wider world remains open enough for later expansion without requiring a major retcon.

## 5. World Structure and Progression

### 5.1 MVP World Layout

The MVP contains **four major world zones**:

1. **Hub 1** - central safe town and service location.
2. **Area 1** - outdoor green/ruins region and starter settlement.
3. **Area 2** - catacombs/dungeon-oriented region.
4. **Area 3** - undead/graveyard/wasteland-oriented final region.

Areas are physically connected. The player can walk between unlocked areas rather than selecting them from a world map.

The broad topology is:

`Hub 1 <-> Area 1 <-> Area 2 <-> Area 3`

Hub 1  also provide a direct connection to Area 2 where the map design allows it. There is no MVP direct connection from Hub 1 to Area 3.

Players may backtrack to previously unlocked regions.

### 5.2 Main Progression Gates

Main progression is structurally linear even if the internal layouts are exploratory.

- Game start: level cap 20, Area 1 accessible.
- Defeat Area 1 boss: permanently unlock Area 2 and raise player-Oathbound level cap to 30.
- Defeat Area 2 boss: permanently unlock Area 3 and raise player-Oathbound level cap to 40.
- Defeat Area 3 boss: complete current main story.

Physical gates, NPC blockades, locked passages, or similar in-world blockers should represent locked progression. Players cannot enter a later main area before its preceding boss has been defeated.

### 5.3 Provisional Required Pre-Boss Objectives

Each area's boss should require one or more objectives before the final encounter. These objectives are **MVP but content-swappable**. Changing the specific required objective should not change the generic concept of boss eligibility.

Current provisional defaults:

- **Area 1:** Complete the mandatory quest that grants the Experience Vessel and defeat at least one required hostile Oathkeeper controlling access to the boss route.
- **Area 2:** Activate two catacomb mechanisms or switches that unlock the boss route. At least one mechanism is placed behind a required hostile Oathkeeper encounter.
- **Area 3:** Defeat two mandatory elite hostile Oathkeepers guarding the final approach to the Demon Knight.

These are default content choices for early builds, not permanent lore commitments.

### 5.4 Area Content Targets

Each main area should feel comparable in overall content density.

Per area target:

- 4 to 5 ordinary hostile Oathkeepers.
- 1 boss Oathkeeper.
- Approximately 1 to 3 friendly dialogue/quest NPCs as a baseline, with room to add more.
- 2 to 5 side quests.
- Multiple visible creature spawn regions.
- At least one healing/revival location or accessible safe point.
- Chests, interactable objects, secrets, and simple environmental obstacles where appropriate.

Not every hostile Oathkeeper must be fought to progress. Level design should allow attentive players to avoid some trainers, while still making total avoidance difficult.

### 5.5 Creature Distribution

The creature roster is not fixed. The target is approximately **15 to 25 species**, with the final number depending on available art assets and development time.

Approximate distribution of distinct species introduced or primarily encountered:

- Area 1: about 40 percent.
- Area 2: about 35 percent.
- Area 3: about 25 percent.

Species may overlap between areas. Later areas should generally contain higher-level encounters even when species repeat.

## 6. Overworld Movement and Interaction

### 6.1 Player Movement

- Movement is grid-based.
- Movement uses four directions: up, down, left, right.
- The player can interact with NPCs and world objects from adjacent tiles.
- The player does not personally fight in combat.
- The player has a fixed visual identity but chooses their name.
- No player appearance or gender customization is required in the MVP.

### 6.2 NPC Movement

NPC behavior depends on role:

- Stationary service NPCs such as shopkeepers remain in place.
- Some friendly NPCs may follow simple bounded movement routes.
- Hostile Oathkeepers may stand still, patrol short routes, or approach the player after detection.
- NPC movement must remain bounded to valid terrain.

### 6.3 Interactable Objects

MVP world interactions may include:

- Doors.
- Signs.
- Treasure chests.
- Switches and pressure mechanisms.
- Fixed-loot objects.
- Quest objects.

Books are not a required interaction category.

Treasure chests contain fixed loot and may be opened only once per game (like pokemon)

### 6.4 Environmental Obstacles and Puzzles

Simple environmental gameplay is part of the MVP. Examples may include:

- Locked doors.
- Switches.
- Pressure plates.
- Short route puzzles.
- Secret paths.
- Terrain that changes movement behavior.

**Creature-specific overworld abilities are Deferred.** The MVP must not require Cut/Surf-style creature abilities to progress.

## 7. Visible Creature Encounters

### 7.1 Encounter Model

There are **no random grass/terrain encounters** in the current MVP.

All wild encounters originate from visible creatures in the overworld. Creature spawns may appear dynamically within valid spawn regions, including visible pop-ins.

### 7.2 Spawn Rules

- Spawn sets can differ between subregions of the same area.
- Encounter levels are appropriate to story progression and area difficulty.
- Spawned creatures must remain on valid terrain.
- Spawned creatures must not occupy invalid world geometry or the player's current tile.
- Creatures may respawn after leaving/re-entering an area, after sufficient time, and after using a healing/revival service.
- Hostile wild creatures return through normal respawn behavior after defeat.

### 7.3 Neutral and Hostile Creature Behavior

Visible creatures use one of two baseline dispositions:

**Neutral**

- Roam or idle within a bounded region.
- Do not automatically begin battle.
- The player may approach/interact to initiate an encounter.
- The player may avoid them by walking around them.

**Hostile**

- Detect the player within a configured proximity rather than requiring strict line of sight.
- Move toward the player after detection.
- Enter battle when they reach an adjacent tile, including diagonal adjacency where the encounter behavior supports it.

Exact detection distances and movement speeds are Provisional balance values.

### 7.4 Immediate Re-Encounter

If another valid hostile creature is already directly adjacent after a battle ends, a new encounter may begin immediately.

## 8. Hostile Oathkeeper Encounters

### 8.1 Line of Sight

Ordinary hostile Oathkeepers can initiate battles using Pokemon-style line-of-sight behavior, subject to the rules defined here rather than imported rules from another game.

- Detection is four-directional.
- Walls and solid objects block sight.
- Sight distance is a Provisional content value.
- When detection occurs, the hostile Oathkeeper approaches the player.
- The player retains movement control during the approach, but the detected Oathkeeper continues pursuing until the encounter begins or the world state invalidates the encounter.
- Players may also manually approach hostile Oathkeepers, including from behind, to challenge them.

If two hostile Oathkeepers detect the player at the same time, the one that reaches the player first begins the first battle. When a tie requires resolution, the faster configured trainer movement or a deterministic content order is used.

### 8.2 Defeat Persistence

Ordinary hostile Oathkeepers remain defeated after victory and after saving/loading. They do not automatically respawn.

After defeat, they remain in the world and use post-defeat dialogue instead of initiating another mandatory battle.

Repeatable trainer battles are **Deferred**.

## 9. Creature and Oathbound System

### 9.1 Species and Individual Consistency

Each creature species defines its baseline identity, including:

- Name.
- One or two elemental types.
- Base HP, Attack, Defense, and Speed.
- Growth behavior.
- Learnable moves.
- Evolution information where applicable.
- Base binding difficulty.
- Visual/audio references when assets exist.

Individual creatures of the same species do **not** have Pokemon-style IVs, natures, or hidden randomized stat variation in the MVP. Same-species individuals follow the same underlying species progression unless modified by level, moves, statuses, or temporary effects.

### 9.2 Active Party

- Maximum active party size: **3 Oathbound**.
- Duplicate species are allowed.
- The player may not unbind, sell, or otherwise remove their final remaining Oathbound.
- Attempting to remove the final party member must be blocked with an explanatory prompt.

### 9.3 Creature Hotel

Hub 1 contains a creature storage service, working name **Creature Hotel**.

Purpose:

- Store Oathbound outside the active party.
- Allow the player to collect creatures without being forced to permanently release current party members.
- Support capture-and-deliver quests and creature trading/selling gameplay.

MVP rules:

- Storage has a fixed but generous capacity.
- **Provisional capacity: 30 stored Oathbound.**
- Storing or retrieving an Oathbound may cost a small amount of currency. Exact price is TBD.
- Retrieval requires an empty active-party slot.
- Stored Oathbound preserve level, XP, stats, moves, and evolution state.

When a new binding succeeds while the active party is full, the player is offered valid choices such as:

1. Replace a party member and send the replaced Oathbound to the Hotel if capacity permits.
2. Send the new Oathbound directly to the Hotel if capacity permits.
3. Cancel the binding result if no transfer is desired.

If there is no valid destination for the new Oathbound, the game must warn the player before consuming a Binding Scroll or resolving an impossible binding action.

### 9.4 Leveling

- Oathbound gain XP and levels.
- Current global maximum level in the MVP is **40**.
- Player-owned Oathbound are subject to story-based progression caps.
- Enemy and wild creature levels are content-controlled and are not required to follow the player's cap.

Current player level caps:

| Story State | Player Oathbound Level Cap |
|---|---:|
| Before Area 1 boss victory | 20 |
| After Area 1 boss victory | 30 |
| After Area 2 boss victory | 40 |

The cap is tied to story progression, not the physical area the player currently occupies.

### 9.5 XP Distribution

Current MVP rule:

- Only Oathbound that actively participated in the defeated enemy's battle receive normal XP from that enemy.
- The exact distribution policy is intentionally changeable. A future whole-party XP rule must be possible without changing unrelated combat behavior.

XP is awarded when an individual enemy creature is defeated rather than waiting until the entire trainer battle ends.

An Oathbound may level up mid-battle. Stat increases, evolution checks, and move-learning events may occur immediately as part of that level-up sequence.

### 9.6 Experience Vessel

The **Experience Vessel** is a permanent progression item obtained through a mandatory Area 1 quest before the first boss.

Rules:

- It has unlimited XP storage capacity.
- When a player-owned Oathbound at the current story cap would gain XP, **70 percent** of that excess XP is added to the Experience Vessel and **30 percent** is lost.
- Stored XP can later be assigned to any Oathbound currently in the active party.
- It is used outside battle.
- The player may choose how much stored XP to spend.
- Spending may trigger multiple level-ups in sequence.
- Evolution and move-learning prompts are processed normally during those sequential level-ups.
- XP spending stops when the selected amount is exhausted, the stored pool is exhausted, or the target reaches the current story cap.

The working name and exact UI presentation are TBD.

### 9.7 Evolution

- Some species evolve and some do not.
- MVP evolution is level-based only.
- Evolution level is species-specific.
- The player may refuse an evolution.
- A species has at most one evolution path in the MVP.
- Evolution immediately updates the creature's relevant species-derived stats and identity.

Branching evolution is Deferred.

### 9.8 Move Learning

- An Oathbound may equip at most **4 moves**.
- Species define moves they can learn and the levels at which they become available.
- When learning a fifth move, the player chooses an existing move to forget or refuses the new move.
- Forgotten eligible moves can later be relearned through a dedicated service NPC in Hub 1.

## 10. Elemental Type System

### 10.1 MVP Types

The initial MVP uses four elemental types:

- Fire
- Earth
- Water
- Wind

Creatures may have one or two types. Moves have their own type independently of the user.

A creature's learnable move set is normally thematically compatible with its own type or types, but specific cross-type moves are allowed when explicitly defined by content.

### 10.2 Type Effectiveness Table

The current balanced type cycle is:

- Fire is strong against Wind and weak against Water.
- Water is strong against Fire and weak against Earth.
- Earth is strong against Water and weak against Wind.
- Wind is strong against Earth and weak against Fire.

| Attacking Type | Fire Defender | Earth Defender | Water Defender | Wind Defender |
|---|---:|---:|---:|---:|
| Fire | 1.0x | 1.0x | 0.5x | 2.0x |
| Earth | 1.0x | 1.0x | 2.0x | 0.5x |
| Water | 2.0x | 0.5x | 1.0x | 1.0x |
| Wind | 0.5x | 2.0x | 1.0x | 1.0x |

This table is intended to be easy to memorize and easy to rebalance later.

### 10.3 Dual Types

Against a dual-type creature, the attack multiplier is the product of the two defender-type interactions.

Examples:

- Fire against Water/Wind: 0.5 x 2.0 = 1.0x.
- Wind against Earth/Water: 2.0 x 1.0 = 2.0x.

With the current four-type table and no duplicate types, practical multipliers remain within 0.5x to 2.0x.

There are no type-based immunities in the MVP.

### 10.4 Same-Type Attack Bonus

If a move's type matches at least one of the user's types, apply a **Provisional 1.5x same-type attack bonus (STAB)**.

This value is tunable and should not be treated as inseparable from the rest of damage calculation.

## 11. Battle System

### 11.1 Battle Format

MVP battles are always **1 active creature versus 1 active creature**.

- Both sides may own multiple Oathbound.
- The player party maximum is 3.
- Bosses may use up to 3 Oathbound.
- Early ordinary trainers may use only one creature, while later trainers may use multiple.

2v2 and 3v3 battles are Deferred and must not be implemented in the MVP.

### 11.2 Player Battle Actions

The player may choose from five action categories when valid:

1. **Attack** - choose one of the active Oathbound's available moves.
2. **Switch** - switch to another non-fainted party Oathbound.
3. **Item** - use an eligible battle item.
4. **Capture/Bind** - attempt to bind a wild creature. Not available in trainer battles.
5. **Run** - attempt to escape a wild battle. Not available in mandatory trainer battles.

### 11.3 Turn Resolution

For each combat turn:

1. The player chooses an action.
2. The enemy chooses an action.
3. Action priority is compared.
4. If priority is equal, effective Speed is compared.
5. If both priority and Speed are tied, order is chosen randomly.
6. First action resolves.
7. Faint/status/battle-end conditions are checked.
8. If still valid, second action resolves.
9. End-of-turn effects and cooldown progression resolve.
10. The next turn begins if battle is still active.

### 11.4 Priority

Moves may have a priority value.

- Higher priority resolves before lower priority.
- Speed decides order only when priorities are equal.
- Switch and item priority values use sane provisional defaults and may be tuned later.

### 11.5 Voluntary and Forced Switching

**Voluntary switch:** consumes the player's action for the turn.

**Forced replacement after fainting:** does **not** consume the replacement creature's next normal combat turn.

When the active Oathbound faints and another usable party member exists, the player must choose a replacement before normal turn selection continues.

If the entire party has fainted, the player loses the battle.

### 11.6 Attack Accuracy

Moves may miss.

- Each move has a base Accuracy value.
- Accuracy may be changed by temporary stat modifiers, items, or move effects.
- Accuracy is one of the intended sources of combat randomness.

### 11.7 Damage Randomness

There is **no random damage roll** in the MVP. Given the same battle state, successful hit, and modifiers, the same move should produce the same damage.

### 11.8 Provisional Damage Formula

The exact final formula is not locked. The MVP may use the following sane placeholder formula during development:

`BaseDamage = max(0, MovePower + AttackerAttack - DefenderDefense)`

`LevelMultiplier = 1 + ((AttackerLevel - 1) / 50)`

`FinalDamage = floor(BaseDamage x LevelMultiplier x STAB x TypeMultiplier)`

Rules:

- Final damage cannot be negative.
- Zero damage is allowed in uncommon cases when defense or debuffs reduce the result to zero.
- There are no critical hits in the MVP.
- The formula is explicitly Provisional and may be replaced during balancing without changing battle flow, move selection, turn order, or UI contracts.

### 11.9 Stat Modifiers

Temporary battle stat modifiers are separate from status conditions.

MVP-modifiable combat stats may include:

- Attack
- Defense
- Speed
- Accuracy

A move or item may apply a percentage modifier to one or more stats for a defined duration or until battle ends.

Provisional rule:

- Percentage modifiers combine additively against the unmodified battle stat.
- Effective stat is clamped from 0 percent to 200 percent of its unmodified battle value.
- Exact modifier values are content-specific.
- All temporary battle stat modifiers are cleared when the battle ends.

### 11.10 Move Cooldowns

Moves use cooldowns instead of PP or mana.

- All moves begin battle ready unless explicitly specified otherwise.
- After use, a move becomes unavailable for its configured number of turns.
- Cooldowns are measured in turns.
- Switching does not reset cooldowns.
- Cooldowns continue progressing while an Oathbound is inactive.
- There is no PP, mana, or consumable move-use resource.

### 11.11 Move Content Target

The MVP targets approximately **25 to 40 total moves**.

A move may define:

- Name and stable ID.
- Type.
- Damage power, including zero for non-damaging moves.
- Accuracy.
- Cooldown.
- Priority.
- Optional status application.
- Optional temporary stat modifiers.
- Optional visual/audio presentation references.

A move may deal damage and apply an additional effect in the same use.

### 11.12 Battle Presentation and Pacing

Battles should be intentionally fast.

- Normal attack animations should generally use only a few frames.
- A typical simple attack presentation should be around **0.4 seconds** before control flow continues, subject to animation needs.
- Damage and animation may overlap rather than requiring long text pauses.
- Battle-speed controls and animation skipping are not part of the MVP unless playtesting later proves the battles too slow.

## 12. Status Conditions

The MVP includes three status conditions. They are intentionally simple and may be tuned later.

Multiple statuses may exist on the same creature at once.

### 12.1 Poison

- Default duration: 3 affected-creature turns.
- At the end of the affected creature's turn, deal **10 percent of maximum HP** as status damage.
- Status damage can cause fainting.
- Poison clears when its duration expires or when cured.

### 12.2 Burn

- Default duration: 3 affected-creature turns.
- At the end of the affected creature's turn, deal **5 percent of maximum HP** as status damage.
- While active, effective Attack is reduced by **25 percent**.
- Burn clears when its duration expires or when cured.

### 12.3 Stun

- Stun causes the affected creature to lose its next attempted action.
- Stun clears immediately after preventing that action.
- End-of-turn status/cooldown progression still occurs for that creature's turn.

### 12.4 General Status Rules

- Individual moves may configure different valid durations from approximately 1 to 5 turns where appropriate.
- Status application may depend on move accuracy or explicitly defined effect chance.
- Statuses do not persist after battle.
- Healing/revival services clear all statuses.
- A general cure-all item clears current curable statuses.
- Temporary stat modifiers are not statuses.
- The status set must be replaceable or extensible later without redefining the battle loop.

## 13. Battle Outcomes and Rewards

### 13.1 Fainting

An Oathbound faints when HP reaches 0.

- Status damage may cause fainting.
- A fainted creature cannot act.
- If the active creature faints and another party member is available, use the forced-replacement rule.
- If the player has no usable party members, the player loses the battle.
- If both sides are treated as fainting from the same resolved action/effect and the outcome is otherwise ambiguous, the player is treated as losing.

### 13.2 XP and Currency

- Defeating an enemy creature immediately awards applicable XP.
- Wild creature victories currently award currency directly as a Provisional rule.
- Trainer victories award currency directly.
- Exact reward amounts are content/balance values.

The wild-currency model may later be replaced with sellable materials without changing the concept of battle rewards.

## 14. Enemy Battle AI

Enemy decision-making should use interchangeable behavior profiles rather than assuming every opponent is identical.

### 14.1 Ordinary Trainer Baseline

An ordinary trainer AI should:

- Choose only currently valid moves.
- Avoid moves that are on cooldown.
- Prefer super-effective moves when available.
- Otherwise choose among sensible valid actions.
- Not normally switch creatures.
- Not normally use items.

### 14.2 Boss Baseline

Boss AI may additionally:

- Switch Oathbound.
- Use a developer-configured number and type of healing/buff items.
- Use a different decision profile from ordinary trainers.

### 14.3 AI Flexibility

Specific trainers or groups of trainers may be assigned different decision profiles later without changing battle rules.

Exact scoring/decision algorithms are Provisional. Bosses do not require a fundamentally separate battle system.

## 15. Binding and Capture System

### 15.1 Eligibility

Binding is available only during wild creature battles.

- Trainer-owned Oathbound cannot be captured.
- A fainted wild creature cannot be bound after the battle has already resolved as a defeat.
- Binding attempts have no per-battle attempt limit as long as the player has valid Binding Scrolls and a valid destination for the new Oathbound.

### 15.2 Binding Scrolls

- Binding Scrolls are consumable.
- Multiple grades exist.
- Better grades improve binding chance.
- A failed binding consumes the scroll.
- The player begins the game with 5 basic Binding Scrolls.

Exact grade names and multipliers are content placeholders.

### 15.3 Binding Chance

Binding chance depends primarily on:

- Species base binding difficulty.
- Target remaining HP, with lower HP improving success.
- Binding Scroll grade.
- Explicit item/effect modifiers where defined.

Creature level does not directly reduce binding chance in the MVP.

A Provisional placeholder formula may use:

`Chance = BaseBindChance x ScrollMultiplier x (0.25 + 0.75 x MissingHPFraction)`

Then clamp to a reasonable minimum/maximum such as 5 to 95 percent.

The exact formula is tunable and should remain separate from battle sequencing.

### 15.4 Full Party Handling

The game must not waste a Binding Scroll on an impossible result.

Before an attempt that cannot place a newly bound creature, the player receives a warning.

After a successful binding with a full party, valid transfer choices should be offered as described in the Creature Hotel section.

## 16. Items, Inventory, and Economy

### 16.1 Inventory Capacity

MVP inventory capacity is **unlimited** for ordinary items.

This is a current design choice, not a permanent assumption. A future finite-capacity policy may be introduced later without changing item identity or quest logic.

Quest/key items are tracked separately from sellable ordinary inventory behavior.

### 16.2 MVP Item Categories

The game supports:

- Healing items.
- Revival items.
- Buff items.
- Debuff items where appropriate.
- General status cure/cure-all items.
- Binding Scrolls.
- Quest/key items.
- Experience Vessel.

Player equipment is not part of the MVP.

### 16.3 Item Use

- Eligible consumables can be used in battle or outside battle as defined by the item.
- Using an item in battle consumes the player's action.
- Quest/key items cannot be sold.
- Ordinary sellable items may be sold.
- Ordinary items may be dropped/discarded when allowed.

### 16.4 Currency

The MVP uses one currency.

The player may earn currency through:

- Defeating wild creatures.
- Defeating hostile Oathkeepers.
- Quest rewards.
- Selling ordinary items.
- Transferring/selling an Oathbound contract through an appropriate vendor/service.

The exact in-world currency name is TBD.

### 16.5 Shops and Services

Different service NPCs may provide different functions rather than one universal shop.

Hub 1 should support at least:

- General consumables/healing-item shop.
- Binding Scroll vendor or binding-related service.
- Healing/revival service.
- Creature Hotel.
- Move relearning service.

Additional shops may exist in area safe zones.

Shops have unlimited stock in the MVP unless a specific quest or content rule says otherwise.

### 16.6 Healing and Defeat Costs

Normal healing/revival service is **free in the current MVP**, although a small fee remains a future tuning possibility.

Battle defeat removes a fixed amount of currency as a defeat penalty. Exact amount is Provisional.

A player with zero currency must never be prevented from recovering their party.

## 17. Quests

### 17.1 Quest Structure

The MVP includes:

- One main story quest line.
- Approximately 2 to 5 optional side quests per main area.
- Multiple simultaneously active quests.
- A quest log.

Quests cannot permanently fail. They remain pending, may be abandoned through natural dialogue, or may be reaccepted later.

### 17.2 Supported Quest Objective Types

MVP quest content may use:

- Defeat a specified enemy or number of enemies.
- Bind/capture a specified creature and deliver it.
- Retrieve a specified item.
- Talk to a specified NPC.
- Reach a specified location.
- Escort an NPC along a bounded route.

One player action may progress multiple compatible active quests.

Unless a quest explicitly says otherwise, objectives begin counting only after the quest has been accepted.

### 17.3 Quest Rewards

Quest rewards may include:

- Currency.
- Items.
- XP or XP-related rewards.
- Oathbound.
- Other explicitly defined content rewards.

Different quests should feel narratively distinct even when they reuse the same underlying objective type.

### 17.4 Capture-and-Deliver Quests

When a quest requires giving an Oathbound to an NPC:

- The delivered Oathbound permanently leaves the player's ownership.
- The quest should not allow the player to surrender their final usable Oathbound.
- The Creature Hotel exists partly to make these quests practical with a party limit of three.

### 17.5 Quest Abandonment and Reacceptance

A player may return to the quest giver and naturally tell them they can no longer complete the request.

The quest then returns to an available/reaccept-able state rather than a permanently failed state.

Reacceptance may use different dialogue, such as the NPC asking whether the player changed their mind.

### 17.6 Quest Markers and Log

- Quest markers appear on the map rather than constantly floating in the main world view.
- The quest log should be non-intrusive.
- Objective text should use natural descriptions rather than raw implementation counters where possible.

## 18. Dialogue and Choice

### 18.1 Dialogue Tone

Dialogue should support the game's light-adventure/semi-dark-fantasy tone.

Characters may be funny, warm, strange, serious, or occasionally threatening, but the overall game should not become grim or oppressive.

Avoid long lore dumps. Important information should be delivered in short exchanges and revealed progressively.

### 18.2 Player Choices

Player dialogue options are paraphrases or summaries rather than full voiced protagonist lines.

Choices primarily provide:

- Roleplaying flavor.
- Different NPC responses.
- Temporary or limited consequences.
- Quest acceptance/refusal/abandonment.
- Occasional reward differences.
- Occasional temporary shop-price changes.

The design intentionally uses a limited "illusion of choice" rather than branching storylines.

### 18.3 Choice Constraints

- There is one main story ending.
- There is no global morality system.
- There is no relationship/reputation system in the MVP.
- Refusing a side quest does not permanently lock it.
- Dialogue choices should not permanently lock the player out of required content.
- NPCs do not need to remember nice/rude choices permanently unless a specific quest requires temporary state.

### 18.4 Dialogue-Triggered Actions

Dialogue may trigger:

- Quest state changes.
- Item transactions.
- Shop/service opening.
- Optional sparring or hostile battles.
- Temporary price/reward modifiers.

Most battle-triggering dialogue should make the possibility of a fight clear. A small number of surprise battles are allowed.

Friendly NPCs may politely ask the player to spar, with an option to decline, so optional combat is not tied only to rude or aggressive dialogue choices.

Dialogue portraits are Deferred.

### 18.5 Example Dialogue Patterns

The following examples illustrate the intended style and scope of dialogue choices. They are examples only and should not be treated as fixed final dialogue.

#### Example: Refusing and Later Accepting a Side Quest

An elderly NPC asks the player to find her grandson, who has not returned home.

Possible choices:

- "I'll look for him."
- "I'm busy right now."

If the player agrees, the related side quest is accepted.

If the player refuses, the NPC may respond sadly but the quest remains available. When spoken to again, the dialogue can acknowledge the earlier refusal:

> "Have you changed your mind? I still haven't found him."

The player can then accept or refuse again.

This demonstrates that dialogue choices can affect immediate tone and state without permanently locking the player out of side content.

#### Example: Temporary Shop Consequence

A shopkeeper may react differently depending on how the player speaks to them.

A friendly response could result in something such as:

> "You're alright. I'll give you a discount on your next purchase."

A rude or dismissive response could result in:

> "Fine. Then your next purchase is going to cost you a little more."

The modifier should be temporary, such as applying only to the next transaction, rather than creating a permanent reputation system.

This demonstrates the intended "illusion of choice": the player's attitude can produce visible consequences without creating major branching systems.

#### Example: Friendly Optional Battle

A friendly Oathkeeper may ask:

> "Want to spar for a bit?"

Possible choices:

- Accept the battle.
- Politely decline.

Declining should not cause punishment or loss of content. This allows optional battles to exist without requiring the player to behave aggressively.

#### Example: Quest Abandonment

If the player has accepted a side quest but later wants to remove it from the active quest log, returning to the quest giver may provide an in-world dialogue option such as:

- "I'm still working on it."
- "I don't think I can help anymore."

Choosing to abandon the quest removes it from the active quest log. The NPC may react disappointedly, but speaking to them again later should allow the quest to be accepted again.

These examples define the intended behavioral pattern, not mandatory wording. Final dialogue may be rewritten to better fit individual characters, locations, and tone.

## 19. Boss Battles

Boss battles use the normal trainer battle rules with more difficult content.

MVP boss characteristics:

- Up to 3 Oathbound.
- Higher levels than nearby ordinary opponents.
- Configurable item usage, including healing.
- May switch creatures.
- May use a boss-specific AI profile.
- May use a different battle background, music, or presentation when assets exist, but unique audiovisual presentation is not required for core functionality.

Bosses do not require unique boss-only creatures in the MVP.

Defeated bosses do not respawn or become repeatable fights.

## 20. Defeat, Recovery, and Soft-Lock Prevention

### 20.1 Party Defeat

When all player Oathbound faint:

1. The player loses the battle.
2. A fixed currency penalty is applied, without taking the balance below zero.
3. The player returns to the last healing/revival location they visited.
4. All party Oathbound are restored to full HP.
5. Status conditions and temporary battle stat changes are cleared.
6. Roaming creatures and movable trainer positions may reset to represent time passing.
7. Opened chests and permanent progression remain unchanged.

The game does not reload an old save as the normal defeat behavior.

### 20.2 Last Revival Location

The active revival location is the most recently used healing/revival service.

Entering an area alone does not change the revival point.

### 20.3 Soft-Lock Prevention

The player must never be permanently unable to continue because of ordinary resource mistakes.

Required protections include:

- Revival remains available with zero currency.
- The player cannot sell/unbind their final Oathbound.
- Impossible binding attempts do not waste Binding Scrolls when no destination exists.
- Required quest items cannot be sold.
- Quest cancellation does not permanently remove required progression.

## 21. Save and Persistence

### 21.1 Save Model

- One player save slot.
- Autosave-based progression.
- No manual save command in the MVP.
- A Load/Continue interface may expose the single save slot without providing arbitrary manual save snapshots.
- One hidden backup copy of the save should be maintained for corruption recovery.

### 21.2 Autosave Triggers

Autosave occurs at meaningful state boundaries, including:

- Entering a main area.
- Before dangerous or irreversible encounters when practical.
- After battles.
- After successful bindings.
- After buying or selling.
- After quest acceptance, completion, cancellation, or reacceptance.
- After boss victories.
- On normal game quit.

When an event is dangerous, save before entering the event so a crash does not destroy prior progression.

### 21.3 Persisted State

The save must preserve at least:

- Player name and world location.
- Active revival location.
- Story/boss progression.
- Area unlocks.
- Player level-cap progression.
- Active party composition.
- Creature Hotel contents.
- Oathbound species, level, XP, HP, moves, evolution state, and relevant persistent data.
- Experience Vessel stored XP.
- Inventory and key items.
- Currency.
- Defeated ordinary trainers.
- Defeated bosses.
- Opened chests.
- Quest states and progress.
- Dialogue state where it has temporary/persistent gameplay consequences.
- Relevant roaming-creature/world state needed for coherent reload behavior.
- Settings that should persist between sessions.

The game remains playable after the ending and the completed state is saved.

## 22. User Interface and Controls

### 22.1 Input

MVP input supports:

- Keyboard.
- Mouse for menus and supported UI interaction.

Controller support is Deferred.

### 22.2 Rebinding

The settings screen must allow keyboard control rebinding for player-facing gameplay actions.

### 22.3 Display

- The game should support normal windowed and fullscreen behavior.
- The window must be minimizable.
- The game uses a fixed logical aspect ratio.
- **Provisional aspect ratio: 16:9.**
- Black bars/letterboxing are acceptable when the display aspect ratio differs.

Exact internal pixel resolution is an implementation decision and is not specified here.

### 22.4 Required Screens

The MVP includes:

- Main/continue screen.
- Pause menu.
- Party screen.
- Oathbound details screen.
- Inventory screen.
- Quest log.
- Bestiary/creature index.
- Settings screen.
- Save/load or Continue interface for the single autosave slot.
- Shop/service interfaces.
- Battle interface.

### 22.5 Battle Information

During battle, show:

- Player active Oathbound name.
- Player exact HP and HP bar.
- Enemy exact HP and HP bar.
- Player and enemy level.
- Player and enemy type(s).
- Player move names.
- Player move power.
- Player move accuracy.
- Player move cooldown state.
- Type-effectiveness hint before move selection in the current MVP.

Enemy move power does not need to be revealed.

The pre-selection effectiveness hint is a tunable presentation rule and may later be removed without changing type calculation.

### 22.6 Oathbound Details Screen

Show at least:

- Name/species.
- Level and XP.
- Current/max HP.
- Base/current combat stats as relevant.
- Type(s).
- Equipped moves.
- Move details.
- Evolution information when known/appropriate.

### 22.7 Bestiary

The bestiary is Pokemon-style in function but limited in scope.

MVP should track at least:

- Species identity.
- Whether the species has been seen.
- Whether the species has been bound/owned.
- Basic gameplay information such as type where appropriate.

Flavor/lore text is Deferred.

### 22.8 Audio Settings

The settings screen includes volume controls. At minimum, music and sound effects should be independently adjustable if both categories exist.

Accessibility-specific settings and mobile touch-screen UI are not required in the MVP.

## 23. Placeholder and Missing-Asset Requirements

### 23.1 Core Rule

**The entire game must remain playable and testable without final audiovisual assets. Missing assets must never prevent gameplay systems from functioning.**

Gameplay logic must not depend on the final sprite, animation, icon, sound, or music file being present.

### 23.2 Placeholder Visual Standard

When final visual assets are unavailable, use clear development placeholders.

Recommended default category colors:

| Category | Placeholder Color |
|---|---|
| Player | Blue |
| Friendly NPC | Green |
| Hostile Oathkeeper | Red |
| Boss | Orange |
| Creature/Oathbound | Purple |
| Interactable/quest object | Yellow |
| Generic UI/missing icon | Gray |

Color is only a debugging aid. Every placeholder must also contain readable text so it remains understandable without color.

### 23.3 Placeholder Labels

Static placeholder example:

`CREATURE_FIRE_01`

Animated placeholder example:

`PLAYER_WALK_UP [2/4]`

The label should identify:

- Entity/content ID where useful.
- Intended animation/state name.
- Current frame number and total frame count for animated placeholders.

Numbered frames must visibly cycle so timing and state transitions can be tested before real sprites exist.

### 23.4 Missing UI Art

Missing UI art uses functional temporary controls and labels. Missing decorative UI must never prevent menus from being usable.

### 23.5 Missing Audio

- Missing sound effect: remain silent and emit a development-visible missing-asset diagnostic.
- Missing music: remain silent and emit development-visible music start/stop diagnostics using the intended music ID.
- Diagnostics should be centrally suppressible/configurable so development messages are not inseparable from final game presentation.

## 24. Content Targets

These targets guide content production but must not be hard-coded into core gameplay assumptions.

| Content | MVP Target |
|---|---:|
| Main explorable areas | 3 |
| Central hub | 1 |
| Bosses | 3 |
| Ordinary hostile Oathkeepers | 4-5 per area |
| Friendly NPC baseline | 1-3 per area |
| Side quests | 2-5 per area |
| Creature species | Approx. 15-25 |
| Moves | Approx. 25-40 |
| Active party size | 3 |
| Oathbound move slots | 4 |
| Elemental types | 4 |
| MVP status conditions | 3 |
| Player level cap | 40, progression-gated |
| Creature Hotel capacity | Provisional 30 stored Oathbound |

## 25. Changeability and Modularity Requirements

This section describes required qualities of the game specification and future implementation without prescribing Godot classes, nodes, files, or concrete code architecture.

### 25.1 Content Independence

The following should be replaceable or expandable without rewriting unrelated core gameplay rules:

- Creature roster.
- Creature stats and growth values.
- Move roster and move values.
- Type-effectiveness table.
- Status definitions.
- Damage formula.
- Binding formula.
- XP distribution policy.
- Level-cap values.
- Inventory capacity policy.
- Enemy AI profiles.
- Trainer rosters.
- Boss rosters.
- Required pre-boss objectives.
- Encounter/spawn tables.
- Shops and prices.
- Quest content.
- Dialogue content.
- Final visual/audio assets.

### 25.2 Stable Content Identity

Reusable gameplay content should have stable internal IDs independent of display names.

Examples:

- `creature_fire_01`
- `move_ember_01`
- `item_binding_scroll_basic`
- `trainer_area1_03`
- `quest_area1_vessel`

Display names may change without invalidating saved or referenced content identity.

### 25.3 Generic Systems

Required behavioral expectations:

- Adding a new creature must not require changing battle rules.
- Adding a new move must not require changing creature-system rules unless the move explicitly introduces an approved new effect category.
- Adding a future Area 4 should not require modifying the content of Areas 1-3.
- Bosses should use the same fundamental trainer battle behavior as ordinary hostile Oathkeepers, with different configuration and AI profile rather than a separate incompatible combat model.
- The game should remain functional when a content category has zero optional entries, such as no side quests or no shop stock beyond required defaults.
- Optional content must not be a hidden dependency of main progression unless explicitly marked required.

### 25.4 Rules That Are Intentionally Easy to Change

The specification expects likely iteration on:

- Damage formula.
- Capture/binding formula.
- Type matchup values.
- STAB value.
- Status values and durations.
- XP distribution.
- Level caps.
- Shop prices.
- Trainer sight distance.
- AI heuristics.
- Inventory capacity.
- Healing cost.
- Battle-speed presentation.
- Type-effectiveness preview in UI.

Changes to these should alter their specific behavior without producing unrelated regressions.

## 26. Human and AI Interpretation Guardrails

This section defines how this specification must be interpreted during design and implementation. It applies especially to coding agents such as Codex and Claude, but human contributors should follow the same authority and change-control rules.

### 26.1 Specification Authority

- This specification is authoritative over examples, inspirations, earlier drafts, proposal wording, and implementation convenience.
- References to Pokemon or other games describe intended player experience only.
- Do not import mechanics simply because an inspiration has them.
- In particular, this specification does **not** implicitly authorize systems such as IVs, EVs, natures, PP, critical hits, held items, six-creature parties, breeding, random grass encounters, or any other unlisted borrowed mechanic.
- If a requested implementation conflicts with the current specification, flag the conflict rather than silently rewriting adjacent behavior.
- Do not modify this specification unless a developer explicitly requests a specification change.

### 26.2 Deferred and Future Features

Features marked **Deferred**, **Future**, **Optional**, explicitly **TBD**, or otherwise stated as not part of the MVP must not be implemented unless a developer specifically requests them.

The authoritative list of currently Deferred/Future features is in **Section 27**.

Do not build speculative systems merely because they might be useful later. Changeability requirements mean current systems should avoid unnecessary dead ends, not that every imagined future mechanic requires infrastructure now.

### 26.3 Ambiguity Policy

When the specification is incomplete or ambiguous:

1. For a minor ambiguity, choose the simplest reasonable interpretation that preserves current player-facing behavior and existing system boundaries.
2. Clearly report any non-trivial assumption made.
3. If the ambiguity would introduce a major mechanic, persistence rule, cross-system dependency, public interface assumption, broad refactor, or materially different player experience, stop and ask a developer.
4. Do not silently change a gameplay rule merely because a different rule would be easier to implement.

### 26.4 Preserve Existing Specified Behavior

- Existing behavior defined by this specification must be preserved unless a developer or a newer specification explicitly changes it.
- A change to one system must not silently alter unrelated gameplay.
- If implementation work reveals a contradiction, inconsistency, or missing major decision, report it for specification review rather than inventing a replacement rule.
- Developer instructions may explicitly override a current rule for a task, but the resulting specification mismatch should be identified so the source of truth can be updated deliberately.

### 26.5 Replaceable Content and Tunable Rules

The game is intentionally designed for iteration. Content and rules listed in **Section 25** are expected to change without forcing unrelated rewrites.

In particular:

- Do not bake current roster sizes, area counts, move counts, type counts, prices, level values, AI behavior, spawn values, or placeholder balance values into unrelated logic.
- Current targets such as approximately 15-25 creatures and three main areas are scope/content values, not universal technical limits.
- Hard player-facing rules that are explicitly specified, such as an MVP active party maximum of 3, remain authoritative until deliberately changed.
- Stable content IDs defined in **Section 25.2** must remain independent of display names and replaceable assets.

### 26.6 Sane Placeholder Values

When a numeric or content value is explicitly TBD or Provisional and a playable implementation cannot function without a value:

1. Prefer a placeholder already specified in this document.
2. Otherwise use a simple, sane value.
3. Clearly identify it as Provisional/TBD.
4. Do not redesign surrounding systems around the placeholder as though it were permanent.
5. Keep the value replaceable without changing unrelated behavior.

### 26.7 Missing Assets and Optional Content

The placeholder policy in **Section 23** is mandatory.

- Missing final art, animation, icons, sound, or music must never block functional gameplay.
- Use labeled visual placeholders and development diagnostics as specified.
- The game should continue functioning when optional content categories are empty.
- Examples include an area having no optional side quests yet, no optional friendly NPCs beyond required progression content, no optional shop additions, or incomplete final audiovisual content.
- Main progression may depend only on content explicitly marked required.

### 26.8 Task Completion Check for Coding Agents

Before reporting an implementation task as complete, an AI coding agent should verify conceptually that:

- The requested behavior matches this specification and the developer's latest explicit instruction.
- No Deferred/Future feature was added accidentally.
- No unlisted inspiration-derived mechanic was introduced.
- Missing content or assets still have a usable placeholder path.
- No variable content count was unnecessarily hard-coded as a universal limit.
- Existing unrelated behavior was not changed without instruction.
- Any non-trivial assumption, unresolved contradiction, or deliberate provisional value is reported to the developer.
- The agent did not edit the specification itself unless explicitly instructed.

## 27. Explicitly Deferred or Future Features

The following are **not part of the MVP**:

- 2v2 combat.
- 3v3 combat.
- Player charms or equipment that buff Oathbound.
- Special Attack / Special Defense stat split.
- Critical hits.
- Creature-specific overworld field abilities.
- Repeatable trainers/rematches.
- Dialogue portraits.
- Bestiary flavor/lore text.
- Fast travel/world-map travel selection.
- Controller support.
- Branching main-story endings.
- Permanent morality/reputation systems.
- Random grass/terrain encounters.
- PP/mana systems for moves.
- Branching evolution paths.
- Full player appearance customization.

The future existence of these ideas must not be treated as a requirement to build supporting systems now.

## 28. Current TBD and Provisional Content Register

The following may use sane placeholders in early builds:

- Region/kingdom name.
- Formal Knight Order name.
- Boss names and final dialogue.
- Final creature roster and exact roster size.
- Exact creature stats and growth curves.
- Exact evolution levels.
- Exact move roster and numeric values.
- Exact status effect balance values.
- Final damage formula.
- Final binding formula and species bind rates.
- Binding Scroll grade names/multipliers.
- Exact trainer sight distances.
- Exact spawn timers/densities.
- Exact economy prices and defeat penalty.
- Creature Hotel final name, capacity, and fee.
- Experience Vessel final name.
- Currency name.
- Final required pre-boss objectives.
- Exact boss AI profiles.
- Exact audiovisual asset set.
- Exact animation frame counts.
- Exact dialogue wording.
- Whether normal healing later gains a small cost.

TBD content should be represented with clear placeholders. It should not block the full gameplay loop.

## 29. MVP Player Loop Summary

The intended main loop is:

1. Explore the current unlocked area.
2. Talk to NPCs, accept quests, find items, and discover visible creatures.
3. Battle wild creatures and hostile Oathkeepers.
4. Bind selected wild creatures and manage a party of up to three Oathbound.
5. Heal, shop, manage Hotel storage, and adjust moves in safe areas/Hub 1.
6. Gain XP and levels up to the current story cap.
7. Complete required local objectives.
8. Defeat the area's boss.
9. Unlock the next area and higher level cap.
10. Repeat through Area 3.
11. Defeat the Demon Knight, resolve the local crisis, become a knight, view credits, and continue playing.

## 30. Specification Boundary

This document intentionally does **not** define:

- Godot scene trees.
- Node types.
- Script/class names.
- Resource formats.
- Autoloads/singletons.
- File/folder structure.
- Signals/events.
- Serialization format.
- Concrete database representation.
- Testing framework.
- Git workflow.
- Plugin/MCP setup.
- Detailed implementation tasks.

Those belong in later architecture and implementation documents after the team accepts this gameplay specification.




## Tech Stack

- **Engine:** **Godot 4.7.2 Stable, Standard build.** The engine version is pinned exactly across the team so scenes, resources, imports, APIs, tests, and agent-generated code behave consistently.
    
- **Language:** **Typed GDScript.** GDScript has direct Godot integration, while static typing improves editor feedback, agent-generated code quality, refactoring safety, and error detection.
    
- **Renderer:** **Compatibility.** Oathbound is an exclusively 2D pixel-art game and does not require the advanced 3D/GPU features of Forward+. Compatibility keeps rendering requirements simple and provides broad hardware support.
    
- **Version Control:** **Git.** All source code, scenes, resources, configuration, documentation, and other appropriate project files are version controlled.
    
- **Large Binary Assets:** **Git LFS.** Large binary source assets are kept out of normal Git object history where appropriate.
    
- **IDE:** **Developer choice.** VS Code, Cursor, JetBrains IDEs, or the built-in Godot editor may be used. The project must not depend on a particular IDE. VS Code/Cursor users may use the official Godot extension where useful.
    
- **Coding Agents:** **Filesystem/terminal-oriented agents with MCP support**, including Codex and Claude Code. Agents are expected to work primarily through repository files and terminal commands rather than relying exclusively on editor automation.
    
- **Godot Agent Bridge:** **`mkdevkit/godot-mcp`, pinned by the project.** MCP gives coding agents access to the running Godot editor for scene inspection, editor operations, runtime inspection, screenshots, and iterative playtest/debug loops. MCP is development tooling and must not become a runtime dependency of the game.
    
- **Testing:** **GUT 9.7.1 for Godot 4.7.x.** Automated tests are used for deterministic gameplay rules, state transitions, persistence behavior, and other systems that can be validated without manual playtesting.
    
- **Formatting and Linting:** **gdtoolkit 4.x.** `gdformat` and `gdlint` provide consistent GDScript formatting and automated static checks for both humans and coding agents. (pip install or brew install)
    
- **Validation:** **Godot 4.7.2 CLI.** The project must support headless imports, validation, tests, and other automated checks from the terminal so agents and CI can verify changes without depending on manual editor interaction.
    
- **CI:** **Headless Godot 4.7.2.** Continuous integration should run the same pinned engine version and automated validation used locally.
    
- **Scenes:** **Small, composable `.tscn` scenes.** Large monolithic scenes should be avoided so scene ownership, reuse, testing, review, and agent modification remain manageable.
    
- **Game Data:** **`.tres` Resources where appropriate.** Reusable content and configuration should be data-driven when this provides a clear benefit, especially for creatures, moves, items, trainers, encounters, and similar replaceable content.
    
- **Primary Agent-Editable Formats:** **`.gd`, `.tscn`, and `.tres`.** These text-based Godot formats allow coding agents to inspect and modify most of the project through normal filesystem tools. Complex visual editing may still be performed through Godot or MCP where safer.
    
- **Documentation Target:** **Godot 4.7 documentation.** Implementation decisions and generated code must target the project's pinned Godot version rather than assuming APIs from newer development releases.
    
- **Specification Authority:** **The Oathbound game specification in `docs/` is the gameplay source of truth.** Implementation and agent behavior must follow its defined mechanics, deferred features, placeholder requirements, and interpretation guardrails.