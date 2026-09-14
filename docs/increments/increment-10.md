# Increment 10: Battle turn-order indicators

## Status

Implemented. Pending independent review.

## Accepted baseline

- Accepted repository commit: `e76732f`
- Expected starting branch: `main`
- Increment 10 planning file: `docs/increments/increment-10.md`
- The planning file is an intentional uncommitted change that must be preserved and included in the implementation commit.

The checkout also contains unrelated work that predates Increment 10. Preserve it exactly. Do not stage, discard, restore, format, or include it in the Increment 10 commit.

Expected unrelated changes at planning time:

```text
 M game/content/creatures/creature_earth_03.tres
 M game/content/creatures/creature_earth_05.tres
 M game/content/creatures/creature_fire_02.tres
 M game/content/creatures/creature_fire_03.tres
 M game/content/creatures/creature_fire_04.tres
 M game/content/creatures/creature_water_01.tres
 M game/content/creatures/creature_water_02.tres
 M game/content/creatures/creature_wind_01.tres
 M game/content/creatures/creature_wind_02.tres
 M game/content/moves/move_dread_gaze_01.tres
 M game/content/moves/move_oath_sunder_01.tres
 M game/content/moves/move_war_cry_01.tres
 M game/content/sprites/creature_earth_03_battle.tres
 M game/content/sprites/creature_earth_05_battle.tres
 M game/content/sprites/creature_fire_02_battle.tres
 M game/content/sprites/creature_fire_03_battle.tres
 M game/content/sprites/creature_fire_04_battle.tres
 M game/content/sprites/creature_water_01_battle.tres
 M game/content/sprites/creature_water_02_battle.tres
 M game/content/sprites/creature_wind_01_battle.tres
 M game/content/sprites/creature_wind_02_battle.tres
 M game/content/sprites/npc_child.tres
 M game/content/sprites/npc_elder.tres
 M game/content/sprites/npc_merchant.tres
 M game/content/sprites/npc_scout.tres
 M game/main.tscn
```

Stop and report the conflict if another process changes an Increment 10 target during implementation.

## Objective

Make battle action order easier to understand before a turn resolves.

The battle screen must show which active creature has the default Speed advantage. The first battle turn must instead show the existing forced overworld-opening advantage. Move hints must explain non-zero move priority so a priority action does not look like an unexplained contradiction.

This increment is presentation and read-only rules exposure. It must not change battle resolution.

## Confirmed gameplay rules

The existing rules remain unchanged:

1. An overworld player strike damages a normal wild creature before battle.
2. A surviving creature enters battle with that reduced HP.
3. `BattleConfig.Opening.ADVANTAGE` forces the player side to act first during battle turn one, regardless of Speed or action priority.
4. A hostile-creature ambush damages the player lead before battle.
5. `BattleConfig.Opening.DISADVANTAGE` forces the enemy side to act first during battle turn one, regardless of Speed or action priority.
6. The forced opening applies only to battle turn one.
7. After the opening turn, higher action priority resolves first.
8. When action priorities are equal, higher effective Speed resolves first.
9. Equal priority and equal effective Speed produce a random order.
10. Effective Speed includes species progression, innate-ability modifiers, and temporary battle modifiers.

Do not remove or weaken the existing opening advantage. Do not change `_turn_order`, priority values, AI selection, Speed formulas, damage, or encounter flow.

## User-facing indicator states

Only one side badge can be visible at a time.

### Forced player opening

Condition:

- `engine.turn_number == 0`
- `engine.config.opening == BattleConfig.Opening.ADVANTAGE`
- Battle phase is choosing an action

Display:

- Player badge: `FIRST STRIKE`
- Enemy badge: hidden
- Center tie label: hidden

### Forced enemy opening

Condition:

- `engine.turn_number == 0`
- `engine.config.opening == BattleConfig.Opening.DISADVANTAGE`
- Battle phase is choosing an action

Display:

- Player badge: hidden
- Enemy badge: `AMBUSHES FIRST`
- Center tie label: hidden

### Normal Speed advantage

Condition:

- No forced opening applies to the upcoming turn
- Active effective Speeds are unequal
- Battle phase is choosing an action

Display:

- Faster side badge: `GOES FIRST`
- Slower side badge: hidden
- Center tie label: hidden

`GOES FIRST` communicates the default order when action priority is equal. It is not a guarantee after a higher-priority opposing action is selected.

### Speed tie

Condition:

- No forced opening applies to the upcoming turn
- Active effective Speeds are equal
- Battle phase is choosing an action

Display:

- Player badge: hidden
- Enemy badge: hidden
- Center tie label: `SPEED TIE`

Do not choose or preview a random tie winner. The engine must keep ownership of the random decision when the turn resolves.

### Non-choosing states

- Hide all initiative indicators before an engine exists.
- Hide all initiative indicators while a forced replacement must be selected.
- Hide all initiative indicators when the battle ends or closes.
- During an action presentation, keep the indicators for the turn currently being presented. Do not recompute them in the middle of event playback.
- Recompute the indicators when the battle returns to the command-selection phase.

This update timing prevents the first-turn label from changing to a Speed label while first-turn animations are still playing.

## Placement and presentation

The selected position is inside each creature status panel, directly below the level and above the HP bar. This is the blank area at the right end of each `TypeRow` in `battle_scene.tscn`.

Expected scene structure for each side:

```text
TypeRow
├── Types
├── Statuses
├── flexible spacer
└── InitiativeBadge
```

Recommended node names:

- `PlayerInitiativeBadge`
- `EnemyInitiativeBadge`

Both labels must use `unique_name_in_owner = true` for direct test access.

Badge requirements:

- One compact badge, not two stacked badges.
- No separate `SPEED` heading.
- No numeric `1` or `2` markers.
- Uppercase copy exactly as specified.
- Right-aligned inside the status-panel content.
- Small enough to preserve type and status badges at the 960 by 540 logical viewport.
- Readable without animation.
- Current code-built UI only. No new raster art, SVG, generated art, or permanent UI-art direction.
- Reuse the current `OathTheme` palette and `StyleBoxFlat` approach.
- Prefer a subtle dark surface with gold text and a thin gold or muted-gold border.
- Use approximately 9 to 11 px logical font size and compact horizontal padding.

The `SPEED TIE` label belongs below the centered encounter caption because the tie belongs to the matchup rather than one side. It must not overlap the status panels or creature stage.

The current battle caption is created by `BattleScene._polish_chrome()`. A code-created tie label beside that setup is acceptable. It must be retained as a field so tests and refresh logic can access it.

Avoid continuous pulsing, bouncing, or attention-seeking animation. A static indicator is sufficient. A short initial fade is optional but must not delay command input or tests.

## Move-priority explanation

`BattleScene._move_hint()` currently shows type, power, accuracy, cooldown, and effectiveness. Extend that existing hint. Do not bulk-edit move resources.

For a move with positive priority, append clear text that includes its value and limitation. Suitable wording:

```text
Priority +1: resolves before lower-priority actions.
```

For a move with negative priority, use corresponding wording:

```text
Priority -1: resolves after higher-priority actions.
```

For priority zero, add no priority text.

Do not use `ALWAYS GOES FIRST` unless a future mechanic actually guarantees precedence over every possible action. Current move priority does not provide that guarantee.

Do not reveal the enemy's selected move. Do not preselect an enemy action during the command menu. Do not move the `GOES FIRST` badge while a move is highlighted.

## Architecture guidance

Battle rules must remain outside `BattleScene`.

Add a small read-only query to `BattleEngine` for the current effective-Speed leader. Suggested contract:

```gdscript
func speed_leader() -> int:
```

Return values:

- `BattleTeam.Side.PLAYER` when the active player battler has higher effective Speed.
- `BattleTeam.Side.ENEMY` when the active enemy battler has higher effective Speed.
- `BattleEvent.NO_SIDE` when the active effective Speeds are equal or a valid comparison is not available.

The method must not consume RNG, choose enemy actions, change phase, increment the turn, or mutate battle state.

`BattleScene` owns presentation copy and decides when the opening labels override the Speed result. A small focused refresh method is expected, such as:

```gdscript
func _refresh_initiative_indicators() -> void:
```

Call it at command-phase boundaries, not from every panel refresh during event playback.

Reuse current fields and helpers where practical. Do not introduce a new service, resource type, autoload, event kind, or generic UI framework for this feature.

## Likely implementation files

Expected targets:

- `docs/increments/increment-10.md`
- `game/scenes/battle_scene.tscn`
- `game/scripts/battle/battle_engine.gd`
- `game/scripts/battle/battle_scene.gd`
- `game/tests/test_battle_engine.gd`
- `game/tests/test_battle_scene.gd`

`game/tests/test_overworld_strike.gd` should change only if a focused assertion is required to preserve the existing first-turn opening contract. The existing opening tests already cover forced order and should remain valid.

Do not modify `game/main.tscn` or the unrelated content resources listed in the baseline section.

## Required focused tests

### BattleEngine tests

Add focused tests proving:

1. `speed_leader()` returns the player side when the active player battler has higher effective Speed.
2. `speed_leader()` returns the enemy side when the active enemy battler has higher effective Speed.
3. `speed_leader()` returns `BattleEvent.NO_SIDE` for equal effective Speed.
4. The query uses effective Speed rather than only species base Speed. A temporary Speed modifier or ability modifier must be represented in at least one case.
5. Calling the query does not consume a random roll or change `turn_number` or `phase`.

### BattleScene tests

Add focused tests proving:

1. A neutral opening shows `GOES FIRST` only on the faster active creature.
2. Equal effective Speed hides both side badges and shows `SPEED TIE` below the battle caption.
3. Player advantage on the upcoming first battle turn shows only `FIRST STRIKE`, even when the player creature is slower.
4. Enemy disadvantage on the upcoming first battle turn shows only `AMBUSHES FIRST`, even when the enemy creature is slower.
5. After the forced first turn completes, the next command phase replaces the opening label with the correct Speed state.
6. A switch or forced replacement refreshes the indicator for the new active creature.
7. Positive-priority move hints state that the move resolves before lower-priority actions.
8. Priority-zero move hints contain no priority claim.
9. Closing or ending battle hides all initiative labels.

Tests may expose badge labels through public `@onready` fields, consistent with the existing `player_level`, `enemy_level`, and status-label test access.

Avoid tests based on exact pixel screenshots, animation timing, private theme-resource identity, or exact color values. Those checks are part of independent visual review.

## Focused verification

Run only the checks needed for this increment:

```bash
cd game
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/test_battle_engine.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/test_battle_scene.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/test_overworld_strike.gd -gexit
gdformat --check scripts/battle/battle_engine.gd scripts/battle/battle_scene.gd tests/test_battle_engine.gd tests/test_battle_scene.gd
gdlint scripts/battle/battle_engine.gd scripts/battle/battle_scene.gd tests/test_battle_engine.gd tests/test_battle_scene.gd
cd ..
git diff --check
```

The overworld-strike test is a regression check for the existing opening rule. Do not add broad tests there unless the implementation changes its public query surface.

The repository has known formatting and lint debt. Do not run a bulk formatter. If a focused check reports pre-existing issues in a touched file, report them separately and keep new code clean. Do not perform unrelated cleanup.

Do not run the full 203-test suite unless a focused failure indicates wider battle-system risk. Independent review owns broader runtime and visual acceptance.

## Acceptance criteria

Increment 10 is ready for independent review when all of these are true:

1. Exactly one side badge or the center tie label is visible during command selection.
2. The side badge occupies the selected blank space below the level and above the HP bar.
3. Neutral openings and later turns show `GOES FIRST` on the effective-Speed leader.
4. Equal effective Speed shows `SPEED TIE` and no side badge.
5. Player opening advantage shows `FIRST STRIKE` for the upcoming first turn.
6. Enemy opening advantage shows `AMBUSHES FIRST` for the upcoming first turn.
7. The opening badge changes to the normal Speed state only after the first turn finishes.
8. Switching, forced replacement, Speed changes, and battle closure do not leave stale labels.
9. Positive and negative move priorities are explained without claiming an unconditional first action.
10. Existing battle order behavior remains unchanged.
11. Focused tests pass.
12. Unrelated worktree changes remain unmodified and unstaged.
13. One coherent implementation commit includes this brief, code, scene, and focused tests.

## Explicit non-goals

- No battle-order timeline.
- No numeric `1` and `2` markers.
- No enemy-intent or enemy-move preview.
- No action preselection during menu navigation.
- No change to priority or Speed formulas.
- No change to the forced first-turn opening rule.
- No change to overworld strike or ambush damage.
- No change to battle AI.
- No change to binding, running, switching, cooldowns, status rules, or rewards.
- No custom UI artwork.
- No image generation.
- No redesign of the status panels, command menu, message panel, or battle background.
- No broad formatting, lint cleanup, documentation rewrite, or unrelated refactor.
- No push, publication, deployment, or acceptance claim.

## Commit requirements

Create one implementation commit after `e76732f` with a lowercase past-tense message. Suggested message:

```text
added battle turn-order indicators
```

The commit must include only:

- This Increment 10 brief.
- Increment 10 production changes.
- Increment 10 focused tests.

Stage Increment 10 paths explicitly. Do not use `git add -A` or another broad staging command. Do not include the unrelated dirty files listed in the baseline section. Do not push the commit.

Complete the work directly in the implementation session. Do not delegate the increment to subagents.

## Required implementation handoff

Stop after the commit and report:

1. Commit hash and message.
2. Files changed.
3. Implemented indicator behavior for every state.
4. BattleEngine query added or reused.
5. Move-priority hint wording.
6. Focused commands run and their results.
7. Any failed checks, warnings, or pre-existing debt encountered.
8. Confirmation that battle resolution rules did not change.
9. Confirmation that unrelated working-tree changes remain unstaged and unmodified.
10. Any point that needs independent visual review.

Keep Increment 10 in planned or implemented-pending-review state. Do not claim acceptance. The independent reviewer will use the diff, focused tests, and Godot MCP runtime inspection to accept the increment or request a correction commit.
