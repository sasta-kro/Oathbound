extends Control
## Sparse ambient motes. Deterministic, decorative, and independent of gameplay.
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	for i in 20:
		var x := fmod(i * 83.7 + sin(elapsed * 0.25 + i) * 12, 620.0) + 330.0
		var y := fposmod(i * 43.8 - elapsed * (3.0 + i % 3), 540.0)
		var alpha := (sin(elapsed * 0.6 + i) + 1.0) * 0.15
		draw_circle(Vector2(x, y), 1.1, Color(0.9, 0.81, 0.55, alpha))
