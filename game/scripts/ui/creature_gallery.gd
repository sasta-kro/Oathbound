extends Control
var tint := Color("a1cdb5")
var portrait: Control

func setup(species: CreatureSpecies) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint = OathTheme.element(species)
	portrait = OathTheme.portrait(species, 0)
	add_child(portrait)
	resized.connect(_layout)

func _ready() -> void:
	_layout()

func _layout() -> void:
	var side := minf(size.x * 0.64, size.y * 0.76)
	portrait.position = (size - Vector2.ONE * side) * 0.5
	portrait.size = Vector2.ONE * side
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	draw_circle(center, radius, Color(tint, 0.045))
	draw_arc(center, radius, 0, TAU, 64, Color(tint, 0.16), 1.0, true)
	draw_arc(center, radius * 0.83, 0.3, 2.7, 40, Color(tint, 0.3), 1.0, true)
	draw_arc(center, radius * 0.83, 3.45, 5.85, 40, Color(tint, 0.3), 1.0, true)
	for i in 4:
		var point := center + Vector2.from_angle(i * PI * 0.5) * radius
		draw_circle(point, 2, tint)
	for x in range(8, int(size.x), 14):
		draw_circle(Vector2(x, size.y - 4), 0.5, Color(tint, 0.2))
