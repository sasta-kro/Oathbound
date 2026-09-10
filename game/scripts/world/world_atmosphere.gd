class_name WorldAtmosphere
extends CanvasLayer
## The overworld's atmosphere pass: colour grading, vignette, cloud shadows and
## pollen, drawn over the map and under the HUD.
##
## All the look lives in `world_atmosphere.gdshader` and is tuned on this
## node's material. The script only tells the shader where the camera is, so
## world-anchored effects such as cloud shadows stay over the same ground
## instead of sliding with the view.

## Turns the whole pass off, for a screenshot or a low-end machine.
@export var enabled: bool = true:
	set(value):
		enabled = value
		if screen != null:
			screen.visible = value

@onready var screen: ColorRect = $Screen

var _material: ShaderMaterial


func _ready() -> void:
	_material = screen.material as ShaderMaterial
	screen.visible = enabled
	if _material == null:
		push_warning("WorldAtmosphere has no shader material; the pass will do nothing.")
		set_process(false)
		return
	get_viewport().size_changed.connect(_push_viewport_size)
	_push_viewport_size()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	_material.set_shader_parameter("world_offset", camera.get_screen_center_position())


func _push_viewport_size() -> void:
	_material.set_shader_parameter("viewport_size", Vector2(get_viewport().get_visible_rect().size))
