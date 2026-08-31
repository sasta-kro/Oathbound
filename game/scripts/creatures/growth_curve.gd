class_name GrowthCurve
extends Resource
## Provisional stat-growth and XP-requirement curve for a creature species.
##
## Exact growth curves are TBD (Specification 28); every number here is a
## placeholder chosen to be playable and is meant to be retuned in the
## inspector without touching creature, battle or XP-award code.
##
## Stats:  value(level) = floor(base * (1 + per_level * (level - 1)))
## HP:     value(level) = floor(base * (1 + hp_per_level * (level - 1))) + flat
## XP:     total(level) = round(xp_base * pow(level - 1, xp_exponent))

@export var id: StringName = &"growth_standard"
@export var display_name: String = "Standard Growth"

@export_group("Experience")
## Scales the whole XP requirement curve.
@export var xp_base: float = 12.0
## Higher values make later levels disproportionately expensive.
@export var xp_exponent: float = 2.2

@export_group("Stat Growth")
## Fraction of the base stat gained per level for Attack, Defense and Speed.
@export var stat_growth_per_level: float = 0.06
## Fraction of the base HP gained per level.
@export var hp_growth_per_level: float = 0.09
## Flat HP added per level on top of the proportional growth.
@export var hp_flat_per_level: float = 2.0

static var _fallback: GrowthCurve


## Shared curve used when a species has no growth curve assigned, so missing
## content never breaks stat calculation.
static func fallback() -> GrowthCurve:
	if _fallback == null:
		_fallback = GrowthCurve.new()
		_fallback.id = &"growth_fallback"
		_fallback.display_name = "Fallback Growth"
	return _fallback


## Total accumulated XP needed to be at [param level].
func total_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(round(xp_base * pow(float(level - 1), xp_exponent)))


## XP needed to go from [param level] to the next level.
func xp_to_next_level(level: int) -> int:
	return total_xp_for_level(level + 1) - total_xp_for_level(level)


## Highest level reachable with [param total_xp], never above [param max_level].
func level_for_total_xp(total_xp: int, max_level: int) -> int:
	var level := 1
	while level < max_level and total_xp >= total_xp_for_level(level + 1):
		level += 1
	return level


func stat_at_level(base_stat: int, level: int) -> int:
	var clamped_level: int = maxi(1, level)
	return int(floor(float(base_stat) * (1.0 + stat_growth_per_level * float(clamped_level - 1))))


func hp_at_level(base_hp: int, level: int) -> int:
	var clamped_level: int = maxi(1, level)
	var scaled := float(base_hp) * (1.0 + hp_growth_per_level * float(clamped_level - 1))
	return int(floor(scaled + hp_flat_per_level * float(clamped_level - 1)))
