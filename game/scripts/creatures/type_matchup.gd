class_name TypeMatchup
extends Resource
## One attacking-type versus defending-type multiplier row of a [TypeChart].
##
## Only non-neutral matchups need an entry; anything unlisted is 1.0x.

@export var attacking: Elements.Type = Elements.Type.FIRE
@export var defending: Elements.Type = Elements.Type.FIRE
@export var multiplier: float = 1.0
