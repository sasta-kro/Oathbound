class_name Elements
extends RefCounted
## Elemental type identity for creatures and moves (Specification 10.1).
##
## Types are an append-only enum: saved resources store the integer value, so
## existing entries must never be reordered or removed. Adding a fifth type
## means appending it here and adding its rows to the [TypeChart] resource.

enum Type { FIRE, EARTH, WATER, WIND }

const DISPLAY_NAMES: Dictionary = {
	Type.FIRE: "Fire",
	Type.EARTH: "Earth",
	Type.WATER: "Water",
	Type.WIND: "Wind",
}

const IDS: Dictionary = {
	Type.FIRE: &"fire",
	Type.EARTH: &"earth",
	Type.WATER: &"water",
	Type.WIND: &"wind",
}


static func display_name(type: Type) -> String:
	return String(DISPLAY_NAMES.get(type, "Unknown"))


static func id(type: Type) -> StringName:
	return StringName(IDS.get(type, &"unknown"))


static func is_valid(type: int) -> bool:
	return DISPLAY_NAMES.has(type)


static func all() -> Array[int]:
	var out: Array[int] = []
	for type: int in DISPLAY_NAMES.keys():
		out.append(type)
	return out
