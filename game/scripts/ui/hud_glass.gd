extends ColorRect
## A small, rounded screen-reading surface behind HUD content only.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if get_parent() is Container else Control.PRESET_FULL_RECT)
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://shaders/hud_glass.gdshader")
	material = glass
	resized.connect(_update_size)
	_update_size()
	if get_parent() is Container:
		get_parent().sort_children.connect(func(): _fit_parent.call_deferred())
		_fit_parent.call_deferred()

func _fit_parent() -> void:
	if not is_inside_tree() or get_parent() == null: return
	position = Vector2.ZERO
	size = get_parent().size

func _update_size() -> void:
	(material as ShaderMaterial).set_shader_parameter("panel_size", size)
