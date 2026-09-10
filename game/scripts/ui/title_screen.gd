extends Control
var entrance: Tween

func _ready() -> void:
	theme = OathTheme.make()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://assets/ui/verdant_sanctum.svg")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var motes := Control.new()
	motes.set_script(preload("res://scripts/ui/title_seal.gd"))
	add_child(motes)
	var content := VBoxContainer.new()
	content.position = Vector2(64, 44)
	content.size = Vector2(332, 450)
	content.add_theme_constant_override("separation", 4)
	add_child(content)
	content.add_child(OathTheme.label("◇    TALES OF THE VERDANT REACH", 10, OathTheme.GOLD))
	var title := OathTheme.heading("Oathbound", 78)
	content.add_child(title)
	content.add_child(OathTheme.rule())
	content.add_child(OathTheme.heading("Some bonds change everything.", 24))
	content.add_child(OathTheme.paragraph("Beyond the old roads, a wild world awaits.\nFind your companions. Forge your oath.", 12))
	content.add_child(OathTheme.spacer())
	var start := OathTheme.button("Begin your journey                         →", _enter_world, true)
	start.custom_minimum_size.y = 45
	content.add_child(start)
	var settings := OathTheme.button("Display settings", func(): $SettingsMenu.open())
	settings.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(settings)
	var quit := OathTheme.button("Leave the world", func(): get_tree().quit())
	quit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(quit)
	content.add_child(OathTheme.label("SESSION PLAY  /  Progress lasts until the game closes", 9, OathTheme.MUTED))
	start.grab_focus()
	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	caption.offset_left = -330
	caption.offset_top = -88
	caption.offset_right = -50
	caption.offset_bottom = -32
	add_child(caption)
	caption.add_child(OathTheme.label("I  /  THE VERDANT REACH", 10, OathTheme.GOLD))
	caption.add_child(OathTheme.heading("Where the wild remembers.", 24))
	$SettingsMenu.closed.connect(func(): start.grab_focus())
	content.modulate.a = 0
	entrance = create_tween().set_parallel(true)
	entrance.tween_property(content, "modulate:a", 1.0, 0.7)
	entrance.tween_property(content, "position:y", 44.0, 0.7).from(54.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _enter_world() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_settings") and $SettingsMenu.is_open():
		$SettingsMenu.close()
		get_viewport().set_input_as_handled()
