class_name BattleEngine
extends RefCounted
## Turn-based 1v1 battle resolver (Specification 11 to 15).
##
## Pure logic: no nodes, no timing, no input. The caller feeds it the player's
## chosen [BattleAction] once per turn and receives the ordered list of
## [BattleEvent]s that happened, which the battle scene then presents. Every
## random roll goes through [method roll] so a battle can be replayed from a
## seed or forced in tests.

enum Phase { NOT_STARTED, CHOOSING, REPLACING, ENDED }
enum Outcome { NONE, VICTORY, DEFEAT, ESCAPED, BOUND }

const BOSS_INTRO_TEXT := "%s bars your way!"

var config: BattleConfig
var player: BattleTeam
var enemy: BattleTeam
var ai: BattleAI
var rng := RandomNumberGenerator.new()
## When 0.0 or higher, every roll returns this instead of a random number.
## Tests use it to force hits, misses and binding outcomes.
var forced_roll: float = -1.0

var phase: Phase = Phase.NOT_STARTED
var outcome: Outcome = Outcome.NONE
var turn_number: int = 0
var binding_scrolls: int = 0
## Item id -> count left in the satchel. The caller copies it back after the
## battle, the same way as [member binding_scrolls].
var items: Dictionary = {}
## Ids of the items spent this battle, one entry per use, for the quest log.
var items_used: Array[StringName] = []
var run_attempts: int = 0
## The wild creature that joined the player after a successful binding.
var bound_creature: CreatureInstance
var currency_earned: int = 0
## XP that could not be applied because of the level cap. The Experience
## Vessel (Specification 9.6) is not implemented yet, so it is only reported.
var xp_over_cap: int = 0


func _init(battle_config: BattleConfig) -> void:
	config = battle_config
	ai = BattleAI.new()


# --- Lifecycle ---------------------------------------------------------------


## Sets up both teams and sends out the first creatures.
func start() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if phase != Phase.NOT_STARTED:
		return events
	player = BattleTeam.create(config.player_party, BattleTeam.Side.PLAYER)
	enemy = BattleTeam.create(config.enemy_party, BattleTeam.Side.ENEMY)
	binding_scrolls = config.binding_scrolls
	items = config.items.duplicate()
	if config.rng_seed >= 0:
		rng.seed = config.rng_seed
	else:
		rng.randomize()

	if player.is_wiped_out() or enemy.is_wiped_out():
		push_error("A battle needs at least one usable creature on each side.")
		phase = Phase.ENDED
		return events

	phase = Phase.CHOOSING
	for battler: Battler in enemy.battlers:
		for modifier: StatModifier in config.enemy_modifiers:
			if modifier != null:
				battler.add_modifier(modifier)
	var foe: Battler = enemy.active()
	foe.participated = true
	var intro: String = "A wild %s appeared!" % foe.display_name()
	if config.is_boss:
		intro = BOSS_INTRO_TEXT % foe.display_name()
	elif not config.is_wild:
		intro = "%s sent out %s!" % [config.enemy_name, foe.display_name()]
	events.append(BattleEvent.create(BattleEvent.Kind.SEND_OUT, BattleTeam.Side.ENEMY, intro))

	var own: Battler = player.active()
	own.participated = true
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.SEND_OUT, BattleTeam.Side.PLAYER, "Go, %s!" % own.display_name()
		)
	)
	_announce_opening(foe, events)
	return events


## Says why a side is already hurt when the battle opens (Specification 7.3,
## extended). The blow itself landed in the overworld, so there is nothing to
## resolve here: only the reason the HP bars start where they do.
func _announce_opening(foe: Battler, events: Array[BattleEvent]) -> void:
	if not config.opening_text.is_empty():
		events.append(BattleEvent.message(config.opening_text))
	match config.opening:
		BattleConfig.Opening.ADVANTAGE:
			events.append(
				BattleEvent.create(
					BattleEvent.Kind.MESSAGE,
					BattleTeam.Side.ENEMY,
					"You struck first! %s is still reeling." % _label(foe),
				)
			)
		BattleConfig.Opening.DISADVANTAGE:
			events.append(
				BattleEvent.create(
					BattleEvent.Kind.MESSAGE,
					BattleTeam.Side.PLAYER,
					"%s ambushed you! You were caught off guard." % _label(foe),
				)
			)


## What the player may currently do, with a player-facing reason for anything
## that is unavailable (Specification 11.2, 15.4).
func options() -> Dictionary:
	var bind_reason := ""
	if config.is_boss:
		bind_reason = "%s will never swear an oath to you." % enemy.active().display_name()
	elif not config.is_wild:
		bind_reason = "You can't bind another Oathkeeper's creature."
	elif binding_scrolls <= 0:
		bind_reason = "You have no Binding Scrolls left."
	elif not config.has_bind_destination:
		bind_reason = "Your party is full. A new Oathbound would have nowhere to go."
	var run_reason := "" if config.is_wild and config.can_run else "You can't run from this battle!"
	return {
		"can_switch": not player.usable_bench_indices().is_empty(),
		"switch_reason": "You have no other Oathbound able to fight.",
		"can_item": not usable_items().is_empty(),
		"item_reason": "You have no items that would help right now.",
		"can_bind": bind_reason.is_empty(),
		"bind_reason": bind_reason,
		"can_run": run_reason.is_empty(),
		"run_reason": run_reason,
	}


## Battle items the player holds at least one of and could use on someone
## right now, in catalog order.
func usable_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id: StringName in config.item_catalog:
		var item: ItemData = config.item_catalog[id]
		if int(items.get(id, 0)) <= 0 or not item.usable_in_battle:
			continue
		for index: int in player.battlers.size():
			if item_refusal(item, index).is_empty():
				out.append(item)
				break
	return out


func item_count(item: ItemData) -> int:
	return int(items.get(item.id, 0)) if item != null else 0


## Why [param item] cannot be used on party slot [param index], or an empty
## string when it can. Any slot, benched or fighting, may be chosen.
func item_refusal(item: ItemData, index: int) -> String:
	if item == null or item_count(item) <= 0:
		return "You have none left."
	if not item.usable_in_battle:
		return "%s can't be used in battle." % item.display_name
	if index < 0 or index >= player.battlers.size():
		return "There is nobody there."
	var battler: Battler = player.battlers[index]
	return item.refusal(battler.creature, battler.statuses)


## Type multiplier a move would have against the current enemy, for the
## pre-selection hint (Specification 22.5).
func effectiveness_against_enemy(move: MoveData) -> float:
	return BattleRules.type_multiplier(move.type, enemy.active().creature, config.type_chart)


## Which side's active creature is faster by effective Speed, for the battle
## screen's initiative indicator. A read-only comparison: it never rolls,
## chooses an action, changes the phase, or advances the turn. Returns
## [constant BattleEvent.NO_SIDE] when the speeds tie or no valid comparison
## exists yet.
func speed_leader() -> int:
	if player == null or enemy == null:
		return BattleEvent.NO_SIDE
	var own: Battler = player.active()
	var foe: Battler = enemy.active()
	if own == null or foe == null or own.is_fainted() or foe.is_fainted():
		return BattleEvent.NO_SIDE
	var own_speed: int = own.effective_speed()
	var foe_speed: int = foe.effective_speed()
	if own_speed > foe_speed:
		return BattleTeam.Side.PLAYER
	if foe_speed > own_speed:
		return BattleTeam.Side.ENEMY
	return BattleEvent.NO_SIDE


## The chance a Binding Scroll offered now takes on the enemy's active
## creature (Specification 15.3), or certainty in a lesson that guarantees it.
func bind_chance() -> float:
	if config.guaranteed_bind:
		return 1.0
	return BattleRules.bind_chance(enemy.active().creature, config.scroll_multiplier)


## Random number in [0, 1). See [member forced_roll].
func roll() -> float:
	if forced_roll >= 0.0:
		return forced_roll
	return rng.randf()


# --- Turns -------------------------------------------------------------------


## Resolves one full turn (Specification 11.3). An invalid action returns a
## single explanatory message and leaves the turn untouched.
func take_turn(action: BattleAction) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if phase != Phase.CHOOSING:
		return events
	var problem: String = _validate_player_action(action)
	if not problem.is_empty():
		events.append(BattleEvent.message(problem))
		return events

	turn_number += 1
	var enemy_action: BattleAction = ai.choose_action(self)
	var actions: Dictionary = {
		BattleTeam.Side.PLAYER: action,
		BattleTeam.Side.ENEMY: enemy_action,
	}
	for side: int in _turn_order(action, enemy_action):
		if phase == Phase.ENDED:
			break
		if _team(side).active().is_fainted():
			continue
		_resolve(side, actions[side], events)
		_check_battle_end(events)

	if phase != Phase.ENDED:
		_end_of_turn(events)
	if phase != Phase.ENDED:
		_replace_fainted_after_turn(events)
	return events


## Brings in the chosen party member after a faint (Specification 11.5). The
## replacement keeps its full turn: the next call to [method take_turn] starts
## a new turn.
func replace_fainted(party_index: int) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if phase != Phase.REPLACING:
		return events
	if not player.usable_bench_indices().has(party_index):
		events.append(BattleEvent.message("That Oathbound can't fight right now."))
		return events
	player.set_active(party_index)
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.SEND_OUT,
			BattleTeam.Side.PLAYER,
			"Go, %s!" % player.active().display_name(),
		)
	)
	phase = Phase.CHOOSING
	return events


func _validate_player_action(action: BattleAction) -> String:
	if action == null:
		return "Choose an action."
	var active: Battler = player.active()
	var available: Dictionary = options()
	match action.kind:
		BattleAction.Kind.MOVE:
			if action.move == null or not active.creature.knows_move(action.move):
				return "%s doesn't know that move." % active.display_name()
			if not active.is_move_ready(action.move):
				return (
					"%s is not ready for %d more turns."
					% [action.move.display_name, active.cooldown_remaining(action.move)]
				)
			if action.move.targets_ally() and not player.can_target_ally(action.target_index):
				return "%s can't reach that Oathbound." % action.move.display_name
		BattleAction.Kind.WAIT:
			if active.has_ready_move():
				return "%s still has a move ready." % active.display_name()
		BattleAction.Kind.SWITCH:
			if not player.usable_bench_indices().has(action.party_index):
				return String(available["switch_reason"])
		BattleAction.Kind.ITEM:
			return item_refusal(action.item, action.target_index)
		BattleAction.Kind.BIND:
			if not bool(available["can_bind"]):
				return String(available["bind_reason"])
		BattleAction.Kind.RUN:
			if not bool(available["can_run"]):
				return String(available["run_reason"])
	return ""


## Turn order (Specification 11.3, 11.4), with one exception: whoever landed
## the blow in the overworld also acts first on turn one, no matter how slow
## they are or what the other side chose. Priorities take over from turn two.
func _turn_order(player_action: BattleAction, enemy_action: BattleAction) -> Array[int]:
	if turn_number == 1:
		if config.opening == BattleConfig.Opening.ADVANTAGE:
			return [BattleTeam.Side.PLAYER, BattleTeam.Side.ENEMY]
		if config.opening == BattleConfig.Opening.DISADVANTAGE:
			return [BattleTeam.Side.ENEMY, BattleTeam.Side.PLAYER]
	var comparison: int = BattleRules.compare_order(
		player_action.priority(),
		player.active().effective_speed(),
		enemy_action.priority(),
		enemy.active().effective_speed(),
	)
	if comparison == 0:
		comparison = 1 if roll() < 0.5 else -1
	if comparison > 0:
		return [BattleTeam.Side.PLAYER, BattleTeam.Side.ENEMY]
	return [BattleTeam.Side.ENEMY, BattleTeam.Side.PLAYER]


func _resolve(side: int, action: BattleAction, events: Array[BattleEvent]) -> void:
	match action.kind:
		BattleAction.Kind.MOVE:
			_use_move(side, action.move, events, action.target_index)
		BattleAction.Kind.WAIT:
			events.append(
				BattleEvent.create(
					BattleEvent.Kind.MESSAGE,
					side,
					"%s has no move ready and waits." % _label(_team(side).active()),
				)
			)
		BattleAction.Kind.SWITCH:
			_switch(side, action.party_index, events)
		BattleAction.Kind.ITEM:
			_use_item(action.item, action.target_index, events)
		BattleAction.Kind.BIND:
			_attempt_bind(events)
		BattleAction.Kind.RUN:
			_attempt_run(events)


# --- Moves -------------------------------------------------------------------


## [param ally_index] is the party slot a support move lands on; see
## [member BattleAction.target_index].
func _use_move(side: int, move: MoveData, events: Array[BattleEvent], ally_index: int = -1) -> void:
	var user: Battler = _team(side).active()
	var target: Battler = _team(_other(side)).active()

	# Stun spends itself on the first action it prevents (Specification 12.3).
	if user.has_status(StatusIds.STUN):
		user.clear_status(StatusIds.STUN)
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.STUNNED, side, "%s is stunned and can't move!" % _label(user)
			)
		)
		return

	if not user.is_move_ready(move):
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.MESSAGE,
				side,
				"%s's %s isn't ready!" % [_label(user), move.display_name],
			)
		)
		return

	user.start_cooldown(move)
	if move.targets_ally():
		_use_support_move(side, user, move, ally_index, events)
		return
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.MOVE_USED,
			side,
			"%s used %s!" % [_label(user), move.display_name],
			{"move": move},
		)
	)

	if not _percent_roll_passes(BattleRules.hit_chance(move, user)):
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.MISSED, _other(side), "%s's attack missed!" % _label(user)
			)
		)
		return

	if move.is_damaging():
		var multiplier: float = BattleRules.type_multiplier(
			move.type, target.creature, config.type_chart
		)
		var amount: int = BattleRules.damage(move, user, target, config.type_chart)
		var text := "%s took %d damage." % [_label(target), amount]
		var hint: String = BattleRules.effectiveness_text(multiplier)
		if not hint.is_empty():
			text += " " + hint
		_deal_damage(target, amount, BattleEvent.Kind.HIT, text, {"multiplier": multiplier}, events)

	if move.applies_status() and not target.is_fainted():
		_try_apply_status(user, target, move, events)

	_apply_modifiers(move, user, target, events)


## A move that lands on the user's own side (Specification 11.11, extended):
## it never misses, and heals or buffs whichever conscious party member was
## chosen, benched or fighting. Modifiers aimed at the opponent still reach it.
func _use_support_move(
	side: int, user: Battler, move: MoveData, ally_index: int, events: Array[BattleEvent]
) -> void:
	var team: BattleTeam = _team(side)
	var index: int = team.active_index
	if ally_index != -1 and team.can_target_ally(ally_index):
		index = ally_index
	var ally: Battler = team.battlers[index]
	var text := "%s used %s!" % [_label(user), move.display_name]
	if ally != user:
		text = "%s used %s on %s!" % [_label(user), move.display_name, _label(ally)]
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.MOVE_USED, side, text, {"move": move, "target_index": index}
		)
	)
	if move.heals():
		_heal(team, index, move, events)
	_apply_modifiers(move, ally, _team(_other(side)).active(), events)


func _heal(team: BattleTeam, index: int, move: MoveData, events: Array[BattleEvent]) -> void:
	var ally: Battler = team.battlers[index]
	var creature: CreatureInstance = ally.creature
	var amount: int = BattleRules.heal_amount(move, creature)
	creature.set_hp(creature.current_hp + amount)
	var text: String = (
		"%s recovered %d HP." % [_label(ally), amount]
		if amount > 0
		else "%s is already at full health." % _label(ally)
	)
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.HEALED,
			team.side,
			text,
			{
				"target_index": index,
				"amount": amount,
				"hp": creature.current_hp,
				"max_hp": creature.max_hp(),
				"on_field": index == team.active_index,
			},
		)
	)


## Applies a move's stat modifiers. [param own] receives the SELF ones: the
## user for an ordinary move, the chosen ally for a support move.
func _apply_modifiers(
	move: MoveData, own: Battler, opponent: Battler, events: Array[BattleEvent]
) -> void:
	for modifier: StatModifier in move.stat_modifiers:
		if modifier == null:
			continue
		var recipient: Battler = own if modifier.target == StatModifier.Target.SELF else opponent
		if recipient.is_fainted():
			continue
		recipient.add_modifier(modifier)
		var direction := "rose" if modifier.percent > 0 else "fell"
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.STAT_CHANGED,
				recipient.side,
				"%s's %s %s!" % [_label(recipient), Stats.display_name(modifier.stat), direction],
				{"stat": modifier.stat, "percent": modifier.percent},
			)
		)


func _try_apply_status(
	user: Battler, target: Battler, move: MoveData, events: Array[BattleEvent]
) -> void:
	var status_name: String = StatusIds.display_name(move.status)
	if target.creature.ability != null and target.creature.ability.blocks_status(move.status):
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.STATUS_BLOCKED,
				target.side,
				"%s's %s prevents %s!" % [
					_label(target), target.creature.ability.display_name, status_name
				],
			)
		)
		return
	if target.has_status(move.status):
		return
	var chance: int = move.status_chance
	if user.creature.ability != null:
		chance += user.creature.ability.inflicted_status_chance_bonus
	if not _percent_roll_passes(chance):
		return
	target.apply_status(move.status, move.status_duration_turns)
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.STATUS_APPLIED,
			target.side,
			"%s was %s!" % [_label(target), StatusIds.applied_verb(move.status)],
			{"status": move.status},
		)
	)


func _deal_damage(
	target: Battler,
	amount: int,
	kind: BattleEvent.Kind,
	text: String,
	details: Dictionary,
	events: Array[BattleEvent]
) -> void:
	target.creature.set_hp(target.creature.current_hp - amount)
	details["damage"] = amount
	details["hp"] = target.creature.current_hp
	details["max_hp"] = target.creature.max_hp()
	events.append(BattleEvent.create(kind, target.side, text, details))
	if target.is_fainted():
		_handle_faint(target, events)


func _handle_faint(fainted: Battler, events: Array[BattleEvent]) -> void:
	fainted.clear_battle_state()
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.FAINTED, fainted.side, "%s fainted!" % _label(fainted)
		)
	)
	if fainted.side == BattleTeam.Side.ENEMY:
		_award_rewards(fainted.creature, events)


# --- Rewards (Specification 9.5, 13.2) ---------------------------------------


func _award_rewards(defeated: CreatureInstance, events: Array[BattleEvent]) -> void:
	currency_earned += BattleRules.currency_for_defeating(defeated)
	var xp: int = BattleRules.xp_for_defeating(defeated)
	for recipient: Battler in _xp_recipients():
		_award_xp(recipient, xp, events)


## Who shares in a defeated enemy's XP. Swapping this for a whole-party rule
## must not touch anything else (Specification 9.5).
func _xp_recipients() -> Array[Battler]:
	var out: Array[Battler] = []
	for battler: Battler in player.battlers:
		if battler.participated and not battler.is_fainted():
			out.append(battler)
	return out


func _award_xp(recipient: Battler, xp: int, events: Array[BattleEvent]) -> void:
	var creature: CreatureInstance = recipient.creature
	var before_xp := creature.total_xp
	var before_level := creature.level
	var result: XpResult = creature.gain_xp(xp, config.level_cap)
	xp_over_cap += result.excess
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.XP_GAINED,
			recipient.side,
			BattleRules.XP_GAINED_TEXT % [creature.display_name(), result.applied],
			{"xp": result.applied, "excess": result.excess, "creature": creature, "before_xp": before_xp, "before_level": before_level},
		)
	)
	if not result.leveled_up():
		return
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.LEVEL_UP,
			recipient.side,
			BattleRules.LEVEL_UP_TEXT % [creature.display_name(), result.new_level],
			{"level": result.new_level},
		)
	)
	var known_before: Array[MoveData] = creature.moves.duplicate()
	var needs_choice: Array[MoveData] = creature.resolve_new_moves(result)
	for move: MoveData in creature.moves:
		if not known_before.has(move):
			events.append(
				BattleEvent.create(
					BattleEvent.Kind.MOVE_LEARNED,
					recipient.side,
					BattleRules.MOVE_LEARNED_TEXT % [creature.display_name(), move.display_name],
					{"move": move},
				)
			)
	# The replace-or-refuse choice is a menu of its own (Specification 9.8);
	# until it exists the move is skipped and can be relearned in Hub 1.
	for move: MoveData in needs_choice:
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.MOVE_LEARN_SKIPPED,
				recipient.side,
				(
					BattleRules.MOVE_LEARN_SKIPPED_TEXT
					% [creature.display_name(), move.display_name]
				),
				{"move": move},
			)
		)
	if result.evolution_ready:
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.MESSAGE,
				recipient.side,
				BattleRules.EVOLUTION_READY_TEXT % creature.display_name(),
			)
		)


# --- Switching, binding, running ---------------------------------------------


func _switch(side: int, party_index: int, events: Array[BattleEvent]) -> void:
	var team: BattleTeam = _team(side)
	var leaving: Battler = team.active()
	team.set_active(party_index)
	var arriving: Battler = team.active()
	var text: String = (
		"%s, come back! Go, %s!" % [leaving.display_name(), arriving.display_name()]
		if side == BattleTeam.Side.PLAYER
		else "%s withdrew %s and sent out %s!" % [
			config.enemy_name, leaving.display_name(), arriving.display_name()
		]
	)
	events.append(BattleEvent.create(BattleEvent.Kind.SEND_OUT, side, text))


## Spends [param item] on party slot [param index]. Healing reuses the HEALED
## event a support move plays, so the screen shows it the same way.
func _use_item(item: ItemData, index: int, events: Array[BattleEvent]) -> void:
	var refusal: String = item_refusal(item, index)
	if not refusal.is_empty():
		events.append(BattleEvent.message(refusal))
		return
	items[item.id] = item_count(item) - 1
	items_used.append(item.id)
	var battler: Battler = player.battlers[index]
	var creature: CreatureInstance = battler.creature
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.MESSAGE,
			BattleTeam.Side.PLAYER,
			"You used a %s on %s." % [item.display_name, battler.display_name()],
		)
	)
	match item.effect:
		ItemData.Effect.HEAL, ItemData.Effect.REVIVE:
			var amount: int = item.heal_amount(creature)
			creature.set_hp(creature.current_hp + amount)
			var text: String = (
				"%s was revived with %d HP!" % [battler.display_name(), amount]
				if item.effect == ItemData.Effect.REVIVE
				else "%s recovered %d HP." % [_label(battler), amount]
			)
			events.append(
				BattleEvent.create(
					BattleEvent.Kind.HEALED,
					BattleTeam.Side.PLAYER,
					text,
					{
						"target_index": index,
						"amount": amount,
						"hp": creature.current_hp,
						"max_hp": creature.max_hp(),
						"on_field": index == player.active_index,
					},
				)
			)
		ItemData.Effect.CURE:
			battler.statuses.clear()
			events.append(
				BattleEvent.create(
					BattleEvent.Kind.MESSAGE,
					BattleTeam.Side.PLAYER,
					"%s feels clear-headed again." % _label(battler),
				)
			)


func _attempt_bind(events: Array[BattleEvent]) -> void:
	var target: Battler = enemy.active()
	binding_scrolls -= 1
	var chance: float = bind_chance()
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.BIND_ATTEMPT,
			BattleTeam.Side.ENEMY,
			"You offer a Binding Scroll to %s..." % _label(target),
			{"chance": chance},
		)
	)
	if roll() < chance:
		bound_creature = target.creature
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.BIND_SUCCESS,
				BattleTeam.Side.ENEMY,
				"The oath is sealed! %s is now your Oathbound!" % target.display_name(),
			)
		)
		_end(Outcome.BOUND, events)
		return
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.BIND_FAILED,
			BattleTeam.Side.ENEMY,
			"%s refused the oath! The scroll crumbles." % _label(target),
		)
	)


func _attempt_run(events: Array[BattleEvent]) -> void:
	var chance: float = BattleRules.run_chance(
		player.active().effective_speed(), enemy.active().effective_speed(), run_attempts
	)
	run_attempts += 1
	if roll() < chance:
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.RUN_SUCCESS, BattleTeam.Side.PLAYER, "You got away safely!"
			)
		)
		_end(Outcome.ESCAPED, events)
		return
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.RUN_FAILED, BattleTeam.Side.PLAYER, "You couldn't get away!"
		)
	)


# --- End of turn -------------------------------------------------------------


## Status damage, modifier durations and cooldowns (Specification 11.3 step 9).
func _end_of_turn(events: Array[BattleEvent]) -> void:
	for side: int in [BattleTeam.Side.PLAYER, BattleTeam.Side.ENEMY]:
		var battler: Battler = _team(side).active()
		if battler.is_fainted():
			continue
		_tick_statuses(battler, events)
		if phase == Phase.ENDED:
			return
		if not battler.is_fainted():
			battler.tick_modifiers()
	# Cooldowns keep counting for benched creatures (Specification 11.10).
	for team: BattleTeam in [player, enemy]:
		for battler: Battler in team.battlers:
			battler.tick_cooldowns()


func _tick_statuses(battler: Battler, events: Array[BattleEvent]) -> void:
	for status: StatusIds.Status in battler.damaging_statuses():
		var text := "%s is hurt by %s!" % [_label(battler), StatusIds.display_name(status)]
		_deal_damage(
			battler,
			battler.status_damage(status),
			BattleEvent.Kind.STATUS_DAMAGE,
			text,
			{"status": status},
			events,
		)
		if battler.is_fainted():
			_check_battle_end(events)
			return
		if battler.tick_status(status):
			events.append(
				BattleEvent.create(
					BattleEvent.Kind.STATUS_ENDED,
					battler.side,
					"%s's %s wore off." % [_label(battler), StatusIds.display_name(status)],
					{"status": status},
				)
			)


## Fainted actives are replaced once the turn is over (Specification 11.5).
func _replace_fainted_after_turn(events: Array[BattleEvent]) -> void:
	if enemy.active().is_fainted():
		var next_index: int = enemy.first_usable_index()
		enemy.set_active(next_index)
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.SEND_OUT,
				BattleTeam.Side.ENEMY,
				"%s sent out %s!" % [config.enemy_name, enemy.active().display_name()],
			)
		)
	if player.active().is_fainted():
		phase = Phase.REPLACING
		events.append(
			BattleEvent.create(
				BattleEvent.Kind.NEEDS_REPLACEMENT,
				BattleTeam.Side.PLAYER,
				"Choose your next Oathbound.",
			)
		)


## When both sides would be out at once the player loses (Specification 13.1).
func _check_battle_end(events: Array[BattleEvent]) -> void:
	if phase == Phase.ENDED:
		return
	if player.is_wiped_out():
		_end(Outcome.DEFEAT, events)
	elif enemy.is_wiped_out():
		_end(Outcome.VICTORY, events)


func _end(final_outcome: Outcome, events: Array[BattleEvent]) -> void:
	phase = Phase.ENDED
	outcome = final_outcome
	for team: BattleTeam in [player, enemy]:
		for battler: Battler in team.battlers:
			battler.clear_battle_state()
	var text := ""
	match final_outcome:
		Outcome.VICTORY:
			text = (
				"You defeated the wild %s!" % enemy.active().display_name()
				if config.is_wild and not config.is_boss
				else "You defeated %s!" % _enemy_title()
			)
			if currency_earned > 0:
				text += " You earned %d coins." % currency_earned
		Outcome.DEFEAT:
			text = "You have no Oathbound left able to fight..."
		Outcome.ESCAPED:
			text = "You fled the battle."
		Outcome.BOUND:
			text = "%s joined your party!" % bound_creature.display_name()
	events.append(
		BattleEvent.create(
			BattleEvent.Kind.BATTLE_ENDED, BattleEvent.NO_SIDE, text, {"outcome": final_outcome}
		)
	)


# --- Helpers -----------------------------------------------------------------


func _team(side: int) -> BattleTeam:
	return player if side == BattleTeam.Side.PLAYER else enemy


func _other(side: int) -> int:
	return BattleTeam.Side.ENEMY if side == BattleTeam.Side.PLAYER else BattleTeam.Side.PLAYER


## Percent chances roll against [method roll] so a forced roll of 0.0 always
## passes any non-zero chance and 0.99 only passes a sure thing.
func _percent_roll_passes(chance_percent: int) -> bool:
	if chance_percent <= 0:
		return false
	return roll() * 100.0 < float(chance_percent)


## How a creature is named in battle text.
func _label(battler: Battler) -> String:
	if battler.side == BattleTeam.Side.PLAYER:
		return battler.display_name()
	if config.is_boss:
		return battler.display_name()
	if config.is_wild:
		return "Wild %s" % battler.display_name()
	return "Foe %s" % battler.display_name()


## Who the player beat: the Oathkeeper, or the boss creature itself.
func _enemy_title() -> String:
	return enemy.active().display_name() if config.is_boss else config.enemy_name
