class_name FieldUI
extends CanvasLayer
## Field HUD, journal navigation and transient rewards share one visual language.
signal changed
var root: Control
var overlay: PanelContainer
var body: VBoxContainer
var hud: HBoxContainer
var rewards: VBoxContainer
var status_panel: PanelContainer
var status_text: Label
var health_bar: ProgressBar
var status_hp: Label
var status_portrait: Control
var shade: ColorRect
var nav_buttons: Dictionary = {}
var page := ""
var journal_filter := ""
var journal_element := -1
var world: Node
var _page_tween: Tween
var _return_page := "party"
var _reward_queue: Array[Dictionary] = []
var _active_rewards := 0
var _lead: CreatureInstance
var _last_hp := -1
var _health_tween: Tween
var _location_shown := false
var _location_tween: Tween

func _ready() -> void:
	layer = 6
	world = get_parent()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = OathTheme.make()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(root)
	_build_hud()
	rewards = VBoxContainer.new()
	rewards.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	rewards.offset_left = -298
	rewards.offset_right = -20
	rewards.offset_top = 90
	root.add_child(rewards)
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.035, 0.04, 0.78)
	root.add_child(shade)
	shade.hide()
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 24
	overlay.offset_right = -24
	overlay.offset_top = 20
	overlay.offset_bottom = -20
	var shell := OathTheme.box(OathTheme.INK, OathTheme.LINE, 10, 18)
	shell.shadow_color = Color(0, 0, 0, 0.3)
	shell.shadow_size = 18
	overlay.add_theme_stylebox_override("panel", shell)
	root.add_child(overlay)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 22)
	overlay.add_child(layout)
	_build_sidebar(layout)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	overlay.hide()
	GameState.party_changed.connect(refresh_hud)
	GameState.experience_awarded.connect(show_xp)
	GameState.quest_changed.connect(_on_quest_changed)
	GameState.quest_objective_advanced.connect(_on_quest_objective_advanced)
	world.settings_menu.closed.connect(_restore_menu_focus)
	refresh_hud()

func _build_hud() -> void:
	hud = HBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 14
	hud.offset_right = -14
	hud.offset_top = 14
	root.add_child(hud)
	status_panel = PanelContainer.new()
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_panel.offset_left = 14
	status_panel.offset_top = -66
	status_panel.offset_right = 222
	status_panel.offset_bottom = -14
	status_panel.add_theme_stylebox_override("panel", _glass_frame(7))
	status_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	status_panel.tooltip_text = "Inspect your lead companion · Party: Tab / P"
	status_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _lead != null:
			_details(_lead))
	root.add_child(status_panel)

func refresh_hud() -> void:
	if _location_tween != null: _location_tween.kill()
	_clear(hud)
	hud.add_theme_constant_override("separation", 6)
	# The area title is an arrival cue, not a permanent opaque HUD block.
	if not _location_shown:
		_location_shown = true
		var location := OathTheme.label("THE VERDANT REACH", 10, OathTheme.PAPER)
		location.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		location.add_theme_constant_override("shadow_offset_y", 1)
		hud.add_child(location)
		_location_tween = create_tween()
		_location_tween.tween_interval(5.0)
		_location_tween.tween_property(location, "modulate:a", 0.0, 0.8)
		_location_tween.tween_callback(location.queue_free)
	hud.add_child(OathTheme.spacer(false))
	for item in [["party", "Party · Tab / P", "party"], ["journal", "Journal · J", "journal"], ["quests", "Quest log · L", "quests"], ["menu", "Menu · Esc", "menu"]]:
		var b := Button.new()
		b.name = String(item[0]).capitalize() + "Button"
		b.icon = load("res://assets/ui/icons/%s.svg" % item[2])
		b.tooltip_text = item[1]
		b.custom_minimum_size = Vector2(32, 32)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		b.add_theme_stylebox_override("normal", _glass_frame(5))
		b.add_theme_stylebox_override("hover", _glass_frame(5, true))
		b.add_theme_stylebox_override("pressed", _glass_frame(5, true))
		b.add_theme_stylebox_override("focus", OathTheme.box(Color.TRANSPARENT, OathTheme.GOLD, 8, 5))
		b.pressed.connect(open_page.bind(item[0]))
		hud.add_child(b)
		b.add_child(preload("res://scripts/ui/hud_glass.gd").new())
	_rebuild_status(GameState.lead_creature())

func _rebuild_status(creature: CreatureInstance) -> void:
	if _health_tween != null: _health_tween.kill()
	_clear(status_panel)
	status_panel.add_child(preload("res://scripts/ui/hud_glass.gd").new())
	_lead = creature
	_last_hp = -1
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(row)
	if creature != null:
		status_portrait = OathTheme.portrait(creature.species, 26)
		row.add_child(status_portrait)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	status_text = OathTheme.label("", 11)
	status_hp = OathTheme.label("", 9, OathTheme.PAPER)
	health_bar = OathTheme.bar(1)
	info.add_child(status_text)
	info.add_child(health_bar)
	info.add_child(status_hp)

func _process(_delta: float) -> void:
	hud.visible = not world.battle_scene.is_active() and not is_open()
	status_panel.visible = hud.visible and not world.dialogue_panel.is_open()
	var lead := GameState.lead_creature()
	if lead != _lead: _rebuild_status(lead)
	if lead == null:
		status_text.text = "Your party needs rest"
		status_hp.text = "Find a healer to recover"
		health_bar.value = 0
		return
	status_text.text = "%s  ·  Lv. %d" % [lead.display_name(), lead.level]
	status_hp.text = "%d / %d HP" % [lead.current_hp, lead.max_hp()]
	if _last_hp != lead.current_hp:
		if _health_tween != null: _health_tween.kill()
		if _last_hp < 0: health_bar.value = lead.hp_fraction() * 100
		else:
			_health_tween = create_tween()
			_health_tween.tween_property(health_bar, "value", lead.hp_fraction() * 100, 0.35)
		_last_hp = lead.current_hp

func _input(event: InputEvent) -> void:
	if world.settings_menu.is_open() or world.transition.is_busy(): return
	if world.battle_scene.is_active() or world.dialogue_panel.is_open(): return
	if event.is_action_pressed("open_settings"):
		if is_open(): _go_back()
		else: open_page("menu")
		get_viewport().set_input_as_handled()
		return
	# Text entry and keyboard focus traversal retain their normal behavior.
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or (event.keycode == KEY_TAB and not is_open()):
			if is_open(): close()
			else: open_page("party")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_J:
			if is_open() and page == "journal": close()
			else: open_page("journal")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_L:
			if is_open() and page == "quests": close()
			else: open_page("quests")
			get_viewport().set_input_as_handled()

func _build_sidebar(layout: HBoxContainer) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 140
	sidebar.add_theme_constant_override("separation", 6)
	layout.add_child(sidebar)
	sidebar.add_child(OathTheme.label("◇   O A T H B O U N D", 10, OathTheme.GOLD))
	sidebar.add_child(OathTheme.heading("Field companion", 22))
	sidebar.add_child(OathTheme.rule())
	for item in [["menu", "01    Journey"], ["party", "02    Companions"], ["journal", "03    Field journal"], ["quests", "04    Quest log"], ["saves", "05    Save journey"]]:
		var b := OathTheme.button(item[1], open_page.bind(item[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 43
		sidebar.add_child(b)
		nav_buttons[item[0]] = b
	sidebar.add_child(OathTheme.spacer())
	sidebar.add_child(OathTheme.label("THE VERDANT REACH", 9, OathTheme.MUTED))
	sidebar.add_child(OathTheme.heading("Every oath matters.", 21))
	sidebar.add_child(OathTheme.rule())
	sidebar.add_child(OathTheme.button("Return to field   Esc", close))

func _restore_menu_focus() -> void:
	if is_open():
		nav_buttons.get(_return_page if page == "details" else page, nav_buttons["party"]).grab_focus()

func is_open() -> bool:
	return overlay.visible

func close() -> void:
	if _page_tween != null: _page_tween.kill()
	overlay.hide()
	shade.hide()
	get_viewport().gui_release_focus()
	changed.emit()

func _go_back() -> void:
	if page == "details": open_page(_return_page)
	else: close()

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func open_page(next: String) -> void:
	if _page_tween != null: _page_tween.kill()
	page = next
	_clear(body)
	overlay.show()
	shade.show()
	for key: String in nav_buttons:
		var selected := key == next or (next == "details" and key == _return_page)
		var style := OathTheme.box(Color("283d37") if selected else Color.TRANSPARENT, OathTheme.GOLD if selected else Color.TRANSPARENT, 5, 10)
		nav_buttons[key].add_theme_stylebox_override("normal", style)
		nav_buttons[key].add_theme_color_override("font_color", OathTheme.GOLD if selected else OathTheme.MUTED)
	match page:
		"party": _party()
		"journal": _journal()
		"quests": _quests()
		"saves": _saves()
		"details": pass
		_: _menu()
	_restore_menu_focus()
	changed.emit()
	body.modulate.a = 0
	_page_tween = create_tween()
	_page_tween.tween_property(body, "modulate:a", 1.0, 0.18)

func _header(kicker: String, title: String, description: String = "") -> void:
	body.add_child(OathTheme.label(kicker, 9, OathTheme.GOLD))
	body.add_child(OathTheme.heading(title, 36))
	if not description.is_empty(): body.add_child(OathTheme.paragraph(description, 11))

func _menu() -> void:
	_header("01  /  YOUR JOURNEY", "A moment between adventures.")
	var hero := PanelContainer.new()
	hero.custom_minimum_size.y = 148
	hero.add_theme_stylebox_override("panel", OathTheme.box(Color.TRANSPARENT, OathTheme.LINE, 8, 0))
	hero.clip_contents = true
	body.add_child(hero)
	var picture := TextureRect.new()
	picture.texture = preload("res://assets/ui/verdant_sanctum.svg")
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.add_child(picture)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	hero.add_child(margin)
	var caption := VBoxContainer.new()
	margin.add_child(caption)
	caption.add_child(OathTheme.label("EXPLORING", 9, OathTheme.GOLD))
	caption.add_child(OathTheme.heading("The Verdant Reach", 29))
	caption.add_child(OathTheme.spacer())
	caption.add_child(OathTheme.label("The next bond is just beyond the path.", 11))
	var metrics := HBoxContainer.new()
	body.add_child(metrics)
	for item in [[str(GameState.currency), "COINS"], [str(GameState.binding_scrolls), "BINDING SCROLLS"], ["%d / %d" % [GameState.party.size(), GameState.PARTY_CAPACITY], "COMPANIONS"]]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metrics.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		panel.add_child(col)
		col.add_child(OathTheme.heading(item[0], 27))
		col.add_child(OathTheme.label(item[1], 9, OathTheme.MUTED))
	body.add_child(OathTheme.spacer())
	var actions := HBoxContainer.new()
	body.add_child(actions)
	var resume := OathTheme.button("Resume exploration   →", close, true)
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(resume)
	actions.add_child(OathTheme.button("Save journey", open_page.bind("saves")))
	actions.add_child(OathTheme.button("Settings", func(): world.settings_menu.open()))
	actions.add_child(OathTheme.button("Title screen", world.return_to_title))
	var saved := "not yet" if GameState.last_saved_at == 0 else SaveService.describe_time(GameState.last_saved_at)
	body.add_child(OathTheme.label("LAST SAVED %s  ·  Played %s  ·  The field autosaves as you travel" % [saved.to_upper(), SaveService.describe_duration(int(GameState.play_seconds))], 9, OathTheme.MUTED))

func _saves() -> void:
	_header("05  /  SAVE JOURNEY", "Keep this moment.", "Save to a slot, return to an earlier one, or clear one out. Loading leaves anything unsaved behind.")
	var list := SaveSlotList.new()
	list.can_save = true
	list.can_load = true
	list.can_erase = true
	list.confirm_load = true
	list.highlighted_slot = GameState.active_slot
	list.save_requested.connect(func(slot: int):
		if world.save_to_slot(slot):
			list.highlighted_slot = slot
		list.refresh()
		list.focus_first())
	list.load_requested.connect(func(slot: int): world.load_from_slot(slot))
	list.erase_requested.connect(func(slot: int):
		SaveService.erase(slot)
		list.refresh()
		list.focus_first())
	body.add_child(list)

func _party() -> void:
	_header("02  /  YOUR COMPANIONS", "Bound together.", "A shared path. A stronger bond. Choose a companion to see their story.")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for i in GameState.PARTY_CAPACITY:
		if i < GameState.party.size(): _party_card(row, GameState.party[i], i)
		else: _empty_card(row, i)
	body.add_child(OathTheme.label("%d / %d OATHS BOUND    ·    Your first healthy companion leads in the field." % [GameState.party.size(), GameState.PARTY_CAPACITY], 9, OathTheme.MUTED))

func _party_card(row: HBoxContainer, creature: CreatureInstance, index: int) -> void:
	var tint := OathTheme.element(creature.species)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1
	var style := OathTheme.box(Color("18282a"), tint.darkened(0.55), 8, 13)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	panel.add_child(card)
	var top := HBoxContainer.new()
	card.add_child(top)
	top.add_child(OathTheme.label("0%d" % (index + 1), 11, OathTheme.MUTED))
	top.add_child(OathTheme.spacer(false))
	top.add_child(OathTheme.label("LEAD" if creature == GameState.lead_creature() else "COMPANION", 9, tint))
	card.add_child(OathTheme.gallery(creature.species, 108))
	card.add_child(OathTheme.heading(creature.display_name(), 27))
	var badges := HBoxContainer.new()
	card.add_child(badges)
	badges.add_child(OathTheme.chip(creature.species.type_display_name(), tint))
	badges.add_child(OathTheme.label("Lv. %d" % creature.level, 12, OathTheme.MUTED))
	card.add_child(OathTheme.spacer())
	card.add_child(OathTheme.bar(creature.hp_fraction(), tint if not creature.is_fainted() else OathTheme.MUTED))
	card.add_child(OathTheme.label("%d / %d HP%s" % [creature.current_hp, creature.max_hp(), "  ·  Fainted" if creature.is_fainted() else ""], 10, OathTheme.MUTED))
	var inspect := OathTheme.button("View companion    →", _details.bind(creature))
	inspect.add_theme_font_size_override("font_size", 11)
	card.add_child(inspect)
	var highlight := func(active: bool):
		var tween := create_tween()
		tween.tween_property(style, "border_color", tint if active else tint.darkened(0.55), 0.15)
	inspect.mouse_entered.connect(highlight.bind(true))
	inspect.mouse_exited.connect(highlight.bind(false))
	inspect.focus_entered.connect(highlight.bind(true))
	inspect.focus_exited.connect(highlight.bind(false))

func _empty_card(row: HBoxContainer, index: int) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", OathTheme.box(Color("122124"), Color("2a3c3b"), 8, 13))
	row.add_child(panel)
	var card := VBoxContainer.new()
	panel.add_child(card)
	card.add_child(OathTheme.label("0%d  /  AN UNWRITTEN OATH" % (index + 1), 9, OathTheme.MUTED))
	card.add_child(OathTheme.spacer())
	var symbol := OathTheme.heading("◇", 54)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.modulate = Color(OathTheme.JADE, 0.4)
	card.add_child(symbol)
	var title := OathTheme.heading("A bond awaits", 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var hint := OathTheme.paragraph("Weaken a wild creature, then offer a Binding Scroll.", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(hint)
	card.add_child(OathTheme.spacer())
	card.add_child(OathTheme.label("ROOM FOR ONE MORE STORY", 8, OathTheme.MUTED))

func _details(creature: CreatureInstance, specimen: bool = false) -> void:
	_return_page = "journal" if specimen else "party"
	open_page("details")
	var top := HBoxContainer.new()
	body.add_child(top)
	var return_button := OathTheme.button("←  " + ("Field journal" if specimen else "Companions"), _go_back)
	top.add_child(return_button)
	return_button.grab_focus()
	top.add_child(OathTheme.spacer(false))
	top.add_child(OathTheme.label("SPECIES RECORD" if specimen else "COMPANION RECORD", 9, OathTheme.GOLD))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var identity := PanelContainer.new()
	identity.custom_minimum_size.x = 210
	columns.add_child(identity)
	var left := VBoxContainer.new()
	identity.add_child(left)
	left.add_child(OathTheme.gallery(creature.species, 163))
	left.add_child(OathTheme.heading(creature.display_name(), 30))
	var tint := OathTheme.element(creature.species)
	left.add_child(OathTheme.chip(creature.species.type_display_name().to_upper(), tint))
	left.add_child(OathTheme.spacer())
	if specimen:
		left.add_child(OathTheme.paragraph("Field-guide stats shown at level 1. Your companions grow stronger with experience.", 11))
	else:
		left.add_child(OathTheme.label("LEVEL %d   /   CAP %d" % [creature.level, GameState.level_cap], 10, OathTheme.GOLD))
		var span := creature.xp_into_current_level() + creature.xp_to_next_level()
		left.add_child(OathTheme.bar(float(creature.xp_into_current_level()) / maxi(1, span), OathTheme.GOLD))
		left.add_child(OathTheme.label("Level cap reached" if creature.level >= GameState.level_cap else "%d EXP to next level" % creature.xp_to_next_level(), 10, OathTheme.MUTED))
		var is_lead := GameState.lead_creature() == creature
		var lead := OathTheme.button("Leading the party" if is_lead else "Make lead companion", _set_lead.bind(creature), not is_lead)
		lead.disabled = creature.is_fainted() or is_lead
		lead.tooltip_text = "Heal this companion before selecting it as lead." if creature.is_fainted() else ""
		left.add_child(lead)
		if creature.can_evolve(): left.add_child(OathTheme.button("Evolve companion  →", _evolve.bind(creature), true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 10)
	scroll.add_child(info)
	info.add_child(OathTheme.label("VITALS", 9, OathTheme.GOLD))
	var stats := GridContainer.new()
	stats.columns = 2
	info.add_child(stats)
	for item in [["HEALTH", "%d / %d" % [creature.current_hp, creature.max_hp()]], ["ATTACK", str(creature.attack())], ["DEFENSE", str(creature.defense())], ["SPEED", str(creature.speed())]]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.SURFACE, OathTheme.LINE, 5, 8))
		stats.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		panel.add_child(col)
		col.add_child(OathTheme.label(item[0], 9, OathTheme.MUTED))
		col.add_child(OathTheme.heading(item[1], 26))
	if creature.ability != null:
		info.add_child(OathTheme.label("INNATE ABILITY", 9, OathTheme.GOLD))
		info.add_child(OathTheme.heading(creature.ability.display_name, 24))
		info.add_child(OathTheme.paragraph(creature.ability.description, 11))
	info.add_child(OathTheme.rule())
	info.add_child(OathTheme.label("MOVESET  /  %d EQUIPPED" % creature.moves.size(), 9, OathTheme.GOLD))
	for move: MoveData in creature.moves:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.SURFACE, OathTheme.LINE, 5, 10))
		info.add_child(panel)
		var move_box := VBoxContainer.new()
		panel.add_child(move_box)
		move_box.add_child(OathTheme.label(move.display_name, 13, OathTheme.ELEMENT_COLORS[move.type]))
		move_box.add_child(OathTheme.label("%s  ·  %s  ·  %d%% accuracy" % [Elements.display_name(move.type), "%d power" % move.power if move.power > 0 else "Status", move.accuracy], 9, OathTheme.MUTED))
		move_box.add_child(OathTheme.paragraph(move.description, 10))
		if move.cooldown_turns > 0: move_box.add_child(OathTheme.label("Cooldown: %d turns" % move.cooldown_turns, 9, OathTheme.MUTED))
	if specimen and creature.species.evolves_into != null:
		info.add_child(OathTheme.paragraph("Evolves into %s at level %d." % [creature.species.evolves_into.display_name, creature.species.evolution_level], 11, OathTheme.GOLD))

func _set_lead(creature: CreatureInstance) -> void:
	if not GameState.party.has(creature) or creature.is_fainted(): return
	GameState.party.erase(creature)
	GameState.party.push_front(creature)
	GameState.party_changed.emit()
	world.partner.refresh_lead()
	_details(creature)

func _evolve(creature: CreatureInstance) -> void:
	if not GameState.party.has(creature) or not creature.evolve(): return
	GameState.seen_species[creature.species_id()] = true
	GameState.party_changed.emit()
	world.partner.refresh_lead()
	_details(creature)

func _journal() -> void:
	var known := GameState.seen_species.size()
	_header("03  /  FIELD JOURNAL", "The wild, collected.", "%02d species encountered  /  %02d catalogued in this region" % [known, Content.all_species().size()])
	var search := LineEdit.new()
	search.placeholder_text = "Search by name or element…"
	search.text = journal_filter
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 34
	body.add_child(search)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	body.add_child(filters)
	var filter_buttons: Array[Button] = []
	for i in range(-1, 4):
		var b := OathTheme.button("All species" if i == -1 else Elements.display_name(i), func(): pass)
		b.custom_minimum_size.y = 28
		b.add_theme_font_size_override("font_size", 10)
		filters.add_child(b)
		filter_buttons.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(grid)
	var entries: Array[Dictionary] = []
	var index := 0
	for species: CreatureSpecies in Content.all_species():
		index += 1
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.SURFACE, OathTheme.LINE, 6, 10))
		grid.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		card.add_child(col)
		var bound := false
		for creature: CreatureInstance in GameState.party:
			if creature.species == species: bound = true
		var state := "BOUND" if bound else ("SEEN" if GameState.seen_species.has(species.id) else "UNSEEN")
		col.add_child(OathTheme.label("#%03d   ·   %s" % [index, state], 9, OathTheme.GOLD if bound else OathTheme.MUTED))
		col.add_child(OathTheme.gallery(species, 72))
		col.add_child(OathTheme.heading(species.display_name, 23))
		col.add_child(OathTheme.label(species.type_display_name(), 10, OathTheme.element(species)))
		var inspect := OathTheme.button("Open record   →", _species_details.bind(species))
		inspect.custom_minimum_size.y = 28
		inspect.add_theme_font_size_override("font_size", 10)
		col.add_child(inspect)
		entries.append({"card": card, "species": species})
	var empty := OathTheme.paragraph("No creatures match this search. Try another name or choose All species.", 13)
	empty.custom_minimum_size.y = 80
	stack.add_child(empty)
	var apply_filter := func():
		var count := 0
		for entry in entries:
			var species: CreatureSpecies = entry.species
			var matches_text := journal_filter.is_empty() or journal_filter.to_lower() in (species.display_name + " " + species.type_display_name()).to_lower()
			entry.card.visible = matches_text and (journal_element == -1 or species.types().has(journal_element))
			if entry.card.visible: count += 1
		empty.visible = count == 0
		for i in filter_buttons.size():
			filter_buttons[i].add_theme_color_override("font_color", OathTheme.GOLD if i - 1 == journal_element else OathTheme.MUTED)
	search.text_changed.connect(func(query: String): journal_filter = query; apply_filter.call())
	for i in filter_buttons.size():
		filter_buttons[i].pressed.connect(func(): journal_element = i - 1; apply_filter.call())
	apply_filter.call()

## The quest log (Specification 17.6): what is in progress, how far along
## each ask is, and what has been fulfilled. Objectives read as the quest
## words them, with a tally only where more than one is asked for.
func _quests() -> void:
	var active := GameState.quests.active_quests()
	var done := GameState.quests.completed_quests()
	_header("04  /  QUEST LOG", "Oaths to the living.", "%02d in progress  /  %02d fulfilled" % [active.size(), done.size()])
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.name = "QuestStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 10)
	scroll.add_child(stack)
	if active.is_empty() and done.is_empty():
		var empty := OathTheme.paragraph("No one has asked anything of you yet. The folk of the town have work for anyone willing to leave the walls.", 13)
		empty.custom_minimum_size.y = 80
		stack.add_child(empty)
		return
	if active.is_empty():
		stack.add_child(OathTheme.paragraph("Nothing in progress. Ask around; someone always needs a hand.", 12))
	for quest: QuestData in active:
		_quest_card(stack, quest, false)
	if not done.is_empty():
		stack.add_child(OathTheme.rule())
		stack.add_child(OathTheme.label("FULFILLED", 9, OathTheme.MUTED))
		for quest: QuestData in done:
			_quest_card(stack, quest, true)

func _quest_card(stack: VBoxContainer, quest: QuestData, fulfilled: bool) -> void:
	var tint := OathTheme.GOLD if quest.is_main() else OathTheme.JADE
	var ready := GameState.quests.is_ready(quest)
	var panel := PanelContainer.new()
	panel.name = String(quest.id)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", OathTheme.box(Color("122124") if fulfilled else OathTheme.SURFACE, OathTheme.LINE if fulfilled else tint.darkened(0.55), 6, 12))
	panel.modulate.a = 0.6 if fulfilled else 1.0
	stack.add_child(panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 5)
	panel.add_child(card)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	card.add_child(top)
	top.add_child(OathTheme.chip(quest.kind_display_name().to_upper(), tint))
	top.add_child(OathTheme.heading(quest.title, 22))
	top.add_child(OathTheme.spacer(false))
	if fulfilled: top.add_child(OathTheme.label("FULFILLED", 9, OathTheme.MUTED))
	elif ready: top.add_child(OathTheme.label("RETURN TO %s" % String(quest.giver).to_upper(), 9, tint))
	if not quest.summary.is_empty(): card.add_child(OathTheme.paragraph(quest.summary, 11))
	for index: int in quest.objectives.size():
		var objective: QuestObjective = quest.objectives[index]
		if objective == null: continue
		var met := fulfilled or GameState.quests.is_objective_done(quest, index)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		row.add_child(OathTheme.label("◆" if met else "◇", 11, tint if met else OathTheme.MUTED))
		var text := OathTheme.label(objective.description, 11, OathTheme.MUTED if met else OathTheme.PAPER)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if objective.required() > 1:
			var tally := objective.required() if fulfilled else mini(GameState.quests.progress(quest, index), objective.required())
			row.add_child(OathTheme.label("%d / %d" % [tally, objective.required()], 10, tint if met else OathTheme.MUTED))
	if quest.has_reward() and not fulfilled:
		var parts: PackedStringArray = []
		if quest.reward_currency > 0: parts.append("%d coins" % quest.reward_currency)
		if quest.reward_binding_scrolls > 0: parts.append("%d Binding Scroll%s" % [quest.reward_binding_scrolls, "" if quest.reward_binding_scrolls == 1 else "s"])
		if quest.reward_xp > 0: parts.append("%d EXP each" % quest.reward_xp)
		card.add_child(OathTheme.label("REWARD  ·  " + "  ·  ".join(parts), 9, OathTheme.MUTED))

func _on_quest_changed(quest: QuestData, status: QuestLog.Status) -> void:
	match status:
		QuestLog.Status.ACTIVE: show_notice("Quest accepted  ·  %s" % quest.title)
		QuestLog.Status.COMPLETED: show_notice("Quest complete  ·  %s" % quest.title)
		QuestLog.Status.ABANDONED: show_notice("Quest set aside  ·  %s" % quest.title)
	if is_open() and page == "quests": open_page("quests")

func _on_quest_objective_advanced(quest: QuestData, index: int, done: bool) -> void:
	var objective: QuestObjective = quest.objectives[index]
	if done:
		show_notice("◆  %s" % objective.description)
		if GameState.quests.is_ready(quest):
			show_notice("Return to the %s  ·  %s" % [String(quest.giver), quest.title])
	else:
		show_notice("◇  %s  ·  %d / %d" % [objective.description, GameState.quests.progress(quest, index), objective.required()])
	if is_open() and page == "quests": open_page("quests")

func _species_details(species: CreatureSpecies) -> void:
	_details(CreatureInstance.create(species, 1), true)

func show_xp(creature: CreatureInstance, before_xp: int, before_level: int, applied: int) -> void:
	# Snapshot every value; later rewards may arrive while this one is queued.
	_reward_queue.append({"species": creature.species, "name": creature.display_name(), "before_xp": before_xp, "before_level": before_level, "xp": creature.total_xp, "level": creature.level, "applied": applied})
	_drain_rewards()

func show_notice(text: String) -> void:
	_reward_queue.append({"notice": text})
	_drain_rewards()

func _drain_rewards() -> void:
	while _active_rewards < 3 and not _reward_queue.is_empty():
		_present_reward(_reward_queue.pop_front())

func _present_reward(data: Dictionary) -> void:
	_active_rewards += 1
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.INK, OathTheme.GOLD.darkened(0.5), 7, 12))
	rewards.add_child(panel)
	var tween := create_tween()
	panel.modulate.a = 0
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	if data.has("notice"):
		panel.add_child(OathTheme.paragraph(data.notice, 12, OathTheme.GOLD))
	else:
		var row := HBoxContainer.new()
		panel.add_child(row)
		row.add_child(OathTheme.portrait(data.species, 42))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)
		info.add_child(OathTheme.label(data.name, 13))
		var level_label := OathTheme.label("+%d EXP  ·  Level %d" % [data.applied, data.before_level], 10, OathTheme.GOLD)
		info.add_child(level_label)
		var bar := OathTheme.bar(0, OathTheme.GOLD)
		info.add_child(bar)
		var curve: GrowthCurve = data.species.growth_curve()
		for level in range(data.before_level, data.level + 1):
			var floor_xp := curve.total_xp_for_level(level)
			var ceiling := curve.total_xp_for_level(level + 1)
			var start := clampf(float(maxi(data.before_xp, floor_xp) - floor_xp) / maxi(1, ceiling - floor_xp), 0, 1)
			var end := 1.0 if level < data.level else float(data.xp - floor_xp) / maxi(1, ceiling - floor_xp)
			tween.tween_callback(func(): bar.value = start * 100; level_label.text = "+%d EXP  ·  Level %d" % [data.applied, level])
			tween.tween_property(bar, "value", end * 100, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if data.level > data.before_level:
			tween.tween_callback(func(): level_label.text = "LEVEL UP  ·  %d → %d" % [data.before_level, data.level])
		elif data.applied == 0:
			tween.tween_callback(func(): level_label.text = "Level cap reached" if data.level >= GameState.level_cap else "No EXP gained")
	tween.tween_interval(2.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		rewards.remove_child(panel)
		panel.queue_free()
		_active_rewards -= 1
		_drain_rewards())


func _glass_frame(padding: int, highlighted: bool = false) -> StyleBoxFlat:
	var frame := OathTheme.box(Color(1, 1, 1, 0.1 if highlighted else 0.015), Color(0.9, 1, 0.96, 0.44 if highlighted else 0.2), 8, padding)
	frame.shadow_color = Color(0, 0, 0, 0.12)
	frame.shadow_size = 3
	return frame
