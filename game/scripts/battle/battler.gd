class_name Battler
extends RefCounted
## Battle-only state layered over a [CreatureInstance]: move cooldowns, status
## conditions and temporary stat modifiers (Specification 11.9, 11.10, 12).
##
## The creature itself only knows its HP. Everything here is discarded when
## the battle ends, which is why it is not stored on the creature.


## A stat modifier that is currently in effect.
class ActiveModifier:
	extends RefCounted
	var stat: Stats.Stat = Stats.Stat.ATTACK
	var percent: int = 0
	## 0 means "until the battle ends".
	var turns_remaining: int = 0


## Effective stats are clamped to this range of their unmodified value
## (Specification 11.9).
const STAT_FLOOR_PERCENT := 0
const STAT_CEILING_PERCENT := 200
## Burn lowers effective Attack while active (Specification 12.2).
const BURN_ATTACK_PENALTY_PERCENT := -25
## End-of-turn damage as a fraction of max HP (Specification 12.1, 12.2).
const STATUS_DAMAGE_FRACTIONS: Dictionary = {
	StatusIds.POISON: 0.10,
	StatusIds.BURN: 0.05,
}

var creature: CreatureInstance
## A [enum BattleTeam.Side] value, stored as int to keep the scripts acyclic.
var side: int = 0
## Move -> turns until it is ready again. Absent means ready.
var cooldowns: Dictionary = {}
## Status id -> turns remaining. Stun is cleared by use, not by time.
var statuses: Dictionary = {}
var modifiers: Array[ActiveModifier] = []
## True once this creature has fought in the current battle, which is what
## earns it XP (Specification 9.5).
var participated: bool = false


static func wrap(instance: CreatureInstance, for_side: int) -> Battler:
	var battler := Battler.new()
	battler.creature = instance
	battler.side = for_side
	return battler


func display_name() -> String:
	return creature.display_name() if creature != null else "???"


func is_fainted() -> bool:
	return creature == null or creature.is_fainted()


# --- Stats -------------------------------------------------------------------


func effective_attack() -> int:
	return _scaled(creature.attack(), Stats.Stat.ATTACK)


func effective_defense() -> int:
	return _scaled(creature.defense(), Stats.Stat.DEFENSE)


func effective_speed() -> int:
	return _scaled(creature.speed(), Stats.Stat.SPEED)


## Accuracy has no base stat; 100 means moves hit at their listed accuracy.
func accuracy_percent() -> int:
	return stat_percent(Stats.Stat.ACCURACY)


## Percentage of the unmodified stat currently in effect. Ability passives,
## temporary modifiers and the burn penalty combine additively and the total is
## clamped (Specification 11.9).
func stat_percent(stat: Stats.Stat) -> int:
	var percent := 100
	if creature != null and creature.ability != null:
		for passive: StatModifier in creature.ability.passive_stat_modifiers:
			if passive != null and passive.stat == stat and passive.target == StatModifier.Target.SELF:
				percent += passive.percent
	for modifier: ActiveModifier in modifiers:
		if modifier.stat == stat:
			percent += modifier.percent
	if stat == Stats.Stat.ATTACK and has_status(StatusIds.BURN):
		percent += BURN_ATTACK_PENALTY_PERCENT
	return clampi(percent, STAT_FLOOR_PERCENT, STAT_CEILING_PERCENT)


func _scaled(base_value: int, stat: Stats.Stat) -> int:
	return int(floor(float(base_value) * float(stat_percent(stat)) / 100.0))


# --- Cooldowns (Specification 11.10) ------------------------------------------


func is_move_ready(move: MoveData) -> bool:
	return move != null and cooldown_remaining(move) <= 0


## Turns the move stays unavailable, counting the current one.
func cooldown_remaining(move: MoveData) -> int:
	return int(cooldowns.get(move, 0))


func has_ready_move() -> bool:
	for move: MoveData in creature.moves:
		if is_move_ready(move):
			return true
	return false


func ready_moves() -> Array[MoveData]:
	var out: Array[MoveData] = []
	for move: MoveData in creature.moves:
		if is_move_ready(move):
			out.append(move)
	return out


## The extra turn covers the one the move was used on, so a cooldown of 2
## makes the move unavailable for exactly the next two turns.
func start_cooldown(move: MoveData) -> void:
	if move.cooldown_turns > 0:
		cooldowns[move] = move.cooldown_turns + 1


## Called at the end of every turn, whether or not this creature is active.
func tick_cooldowns() -> void:
	for move: Variant in cooldowns.keys():
		cooldowns[move] = int(cooldowns[move]) - 1
		if int(cooldowns[move]) <= 0:
			cooldowns.erase(move)


# --- Stat modifiers (Specification 11.9) --------------------------------------


func add_modifier(modifier: StatModifier) -> void:
	var active := ActiveModifier.new()
	active.stat = modifier.stat
	active.percent = modifier.percent
	active.turns_remaining = modifier.duration_turns
	modifiers.append(active)


func has_modifier_for(stat: Stats.Stat) -> bool:
	for modifier: ActiveModifier in modifiers:
		if modifier.stat == stat:
			return true
	return false


## Called at the end of this creature's turn. Battle-long modifiers stay.
func tick_modifiers() -> void:
	for modifier: ActiveModifier in modifiers.duplicate():
		if modifier.turns_remaining <= 0:
			continue
		modifier.turns_remaining -= 1
		if modifier.turns_remaining == 0:
			modifiers.erase(modifier)


# --- Statuses (Specification 12) ---------------------------------------------


func has_status(status_id: StringName) -> bool:
	return statuses.has(status_id)


func apply_status(status_id: StringName, duration_turns: int) -> void:
	statuses[status_id] = maxi(1, duration_turns)


func clear_status(status_id: StringName) -> void:
	statuses.erase(status_id)


## Statuses that deal damage at the end of the creature's turn, in a stable
## order so presentation is repeatable.
func damaging_statuses() -> Array[StringName]:
	var out: Array[StringName] = []
	for status_id: StringName in StatusIds.ALL:
		if has_status(status_id) and STATUS_DAMAGE_FRACTIONS.has(status_id):
			out.append(status_id)
	return out


func status_damage(status_id: StringName) -> int:
	var fraction: float = float(STATUS_DAMAGE_FRACTIONS.get(status_id, 0.0))
	return maxi(1, int(floor(float(creature.max_hp()) * fraction)))


## Counts down one turn and reports whether the status has just expired.
func tick_status(status_id: StringName) -> bool:
	if not has_status(status_id):
		return false
	statuses[status_id] = int(statuses[status_id]) - 1
	if int(statuses[status_id]) <= 0:
		statuses.erase(status_id)
		return true
	return false


## Statuses and modifiers never outlive the battle (Specification 11.9, 12.4).
func clear_battle_state() -> void:
	cooldowns.clear()
	statuses.clear()
	modifiers.clear()
