class_name BattleConfig
extends RefCounted
## Everything a [BattleEngine] needs to run one battle.
##
## Built by whoever starts the encounter (the overworld, a trainer script, a
## test) so the engine itself never reaches into global state.

var player_party: Array[CreatureInstance] = []
var enemy_party: Array[CreatureInstance] = []
## Wild battles allow binding and running (Specification 11.2, 15.1).
var is_wild: bool = true
## False for mandatory Oathkeeper battles (Specification 11.2).
var can_run: bool = true
## Shown for trainer battles. Empty for wild encounters.
var enemy_name: String = ""
var binding_scrolls: int = 0
var scroll_multiplier: float = BattleRules.BASIC_SCROLL_MULTIPLIER
## False when a newly bound creature would have nowhere to go, in which case
## no scroll may be spent (Specification 15.4).
var has_bind_destination: bool = true
## Story-based level cap for player creatures (Specification 9.4).
var level_cap: int = CreatureRules.GLOBAL_MAX_LEVEL
var type_chart: TypeChart
## Seed for the battle's random rolls. Negative picks a random seed.
var rng_seed: int = -1


static func wild(
	party: Array[CreatureInstance], wild_creature: CreatureInstance, chart: TypeChart
) -> BattleConfig:
	var config := BattleConfig.new()
	config.player_party = party
	config.enemy_party = [wild_creature]
	config.is_wild = true
	config.can_run = true
	config.type_chart = chart
	return config


static func trainer(
	party: Array[CreatureInstance],
	opponents: Array[CreatureInstance],
	trainer_name: String,
	chart: TypeChart,
	escapable: bool = false
) -> BattleConfig:
	var config := BattleConfig.new()
	config.player_party = party
	config.enemy_party = opponents
	config.is_wild = false
	config.can_run = escapable
	config.enemy_name = trainer_name
	config.type_chart = chart
	return config
