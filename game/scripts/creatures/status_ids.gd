class_name StatusIds
extends RefCounted
## The MVP status conditions (Specification 12).
##
## Content selects a status from the [enum Status] dropdown; saved resources
## store the integer value, so existing entries must never be reordered or
## removed. [constant IDS] gives each status a stable string id for save data
## and logs. Status behaviour itself is owned by the battle system.

## Append-only. [constant NONE] marks "no status" on moves.
enum Status { NONE, POISON, BURN, STUN }

const NONE := Status.NONE
const POISON := Status.POISON
const BURN := Status.BURN
const STUN := Status.STUN

## Every real status, in a stable order for presentation.
const ALL := [Status.POISON, Status.BURN, Status.STUN]

const IDS: Dictionary = {
	Status.POISON: &"status_poison",
	Status.BURN: &"status_burn",
	Status.STUN: &"status_stun",
}

const DISPLAY_NAMES: Dictionary = {
	Status.POISON: "poison",
	Status.BURN: "burn",
	Status.STUN: "stun",
}

const APPLIED_VERBS: Dictionary = {
	Status.POISON: "poisoned",
	Status.BURN: "burned",
	Status.STUN: "stunned",
}


static func is_known(status: int) -> bool:
	return IDS.has(status)


static func id(status: Status) -> StringName:
	return StringName(IDS.get(status, &""))


static func display_name(status: Status) -> String:
	return String(DISPLAY_NAMES.get(status, "unknown"))


static func applied_verb(status: Status) -> String:
	return String(APPLIED_VERBS.get(status, "afflicted"))
