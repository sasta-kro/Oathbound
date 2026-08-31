class_name StatusIds
extends RefCounted
## Stable identifiers for the MVP status conditions (Specification 12).
##
## Statuses are referenced by id rather than by enum so the status set can be
## extended or replaced without redefining move content or the battle loop.
## Status behaviour itself is owned by the battle system, not by this module.

const POISON := &"status_poison"
const BURN := &"status_burn"
const STUN := &"status_stun"
const NONE := &""

const ALL := [POISON, BURN, STUN]


static func is_known(id: StringName) -> bool:
	return ALL.has(id)
