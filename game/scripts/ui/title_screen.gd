extends Control
var entrance: Tween
var content: VBoxContainer
var loader: VBoxContainer
var slot_list: SaveSlotList
var start: Button

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
	_build_menu(true)
	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	caption.offset_left = -330
	caption.offset_top = -88
	caption.offset_right = -50
	caption.offset_bottom = -32
	add_child(caption)
	caption.add_child(OathTheme.label("I  /  THE VERDANT REACH", 10, OathTheme.GOLD))
	caption.add_child(OathTheme.heading("Where the wild remembers.", 24))
	$SettingsMenu.closed.connect(func(): if start != null: start.grab_focus())

## The left column: the journey buttons, or the slot picker when loading.
func _build_menu(animate: bool) -> void:
	if content != null: content.queue_free()
	content = VBoxContainer.new()
	content.position = Vector2(64, 44)
	content.size = Vector2(332, 450)
	content.add_theme_constant_override("separation", 4)
	add_child(content)
	content.add_child(OathTheme.label("◇    TALES OF THE VERDANT REACH", 10, OathTheme.GOLD))
	content.add_child(OathTheme.heading("Oathbound", 78))
	content.add_child(OathTheme.rule())
	content.add_child(OathTheme.heading("Some bonds change everything.", 24))
	content.add_child(OathTheme.paragraph("Beyond the old roads, a wild world awaits.\nFind your companions. Forge your oath.", 12))
	content.add_child(OathTheme.spacer())
	var latest := SaveService.latest_slot()
	if latest == SaveService.NO_SLOT:
		start = OathTheme.button("Begin your journey                         →", _begin_anew, true)
		start.custom_minimum_size.y = 45
		content.add_child(start)
	else:
		start = OathTheme.button("Continue your journey                    →", func(): _load_slot(latest), true)
		start.custom_minimum_size.y = 45
		content.add_child(start)
		content.add_child(OathTheme.label("%s  ·  %s" % [SaveService.slot_title(latest).capitalize(), SaveSlotList.summary_line(SaveService.read(latest))], 9, OathTheme.MUTED))
		var load := OathTheme.button("Load a journey", _open_loader)
		load.alignment = HORIZONTAL_ALIGNMENT_LEFT
		content.add_child(load)
		var fresh := OathTheme.button("Begin anew", _begin_anew)
		fresh.alignment = HORIZONTAL_ALIGNMENT_LEFT
		content.add_child(fresh)
	var settings := OathTheme.button("Display settings", func(): $SettingsMenu.open())
	settings.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(settings)
	var quit := OathTheme.button("Leave the world", func(): get_tree().quit())
	quit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(quit)
	content.add_child(OathTheme.label("%d SAVE SLOTS  /  The field also autosaves as you travel" % SaveService.SLOT_COUNT, 9, OathTheme.MUTED))
	start.grab_focus()
	if not animate: return
	content.modulate.a = 0
	entrance = create_tween().set_parallel(true)
	entrance.tween_property(content, "modulate:a", 1.0, 0.7)
	entrance.tween_property(content, "position:y", 44.0, 0.7).from(54.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _open_loader() -> void:
	content.hide()
	loader = VBoxContainer.new()
	loader.position = Vector2(64, 28)
	loader.size = Vector2(540, 470)
	loader.add_theme_constant_override("separation", 6)
	add_child(loader)
	loader.add_child(OathTheme.label("◇    LOAD A JOURNEY", 10, OathTheme.GOLD))
	loader.add_child(OathTheme.heading("Pick up where you left off.", 34))
	loader.add_child(OathTheme.rule())
	slot_list = SaveSlotList.new()
	slot_list.can_save = false
	slot_list.can_load = true
	slot_list.can_erase = true
	slot_list.load_requested.connect(_load_slot)
	slot_list.erase_requested.connect(func(slot: int): SaveService.erase(slot); slot_list.refresh(); slot_list.focus_first())
	loader.add_child(slot_list)
	loader.add_child(OathTheme.spacer())
	var back := OathTheme.button("Back", _close_loader)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	loader.add_child(back)
	slot_list.focus_first()

func _close_loader() -> void:
	if loader != null: loader.queue_free()
	loader = null
	slot_list = null
	# Slots may have been erased, so the buttons are rebuilt to match.
	_build_menu(false)

func _load_slot(slot: int) -> void:
	if GameState.load_game(slot):
		_enter_world()
	else:
		# The file vanished or broke since the screen was built.
		_close_loader()

func _begin_anew() -> void:
	GameState.new_game()
	_enter_world()

func _enter_world() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("open_settings"): return
	if $SettingsMenu.is_open():
		$SettingsMenu.close()
		get_viewport().set_input_as_handled()
	elif loader != null:
		_close_loader()
		get_viewport().set_input_as_handled()
