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
	world.settings_menu.closed.connect(_restore_menu_focus)
	refresh_hud()

func _build_hud() -> void:
	hud = HBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 20
	hud.offset_right = -20
	hud.offset_top = 18
	root.add_child(hud)
	status_panel = PanelContainer.new()
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_panel.offset_left = 20
	status_panel.offset_top = -94
	status_panel.offset_right = 298
	status_panel.offset_bottom = -18
	status_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	status_panel.tooltip_text = "Inspect your lead companion"
	status_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _lead != null:
			_details(_lead))
	root.add_child(status_panel)

func refresh_hud() -> void:
	_clear(hud)
	var location := PanelContainer.new()
	var compact := OathTheme.box(Color(OathTheme.INK, 0.94), OathTheme.LINE, 6, 10)
	location.add_theme_stylebox_override("panel", compact)
	hud.add_child(location)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	location.add_child(info)
	info.add_child(OathTheme.label("◇  THE VERDANT REACH", 11, OathTheme.PAPER))
	info.add_child(OathTheme.label("WASD  Move   ·   E  Interact   ·   F  Strike", 9, OathTheme.MUTED))
	hud.add_child(OathTheme.spacer(false))
	for item in [["party", "Party   ⇥"], ["journal", "Journal   J"], ["menu", "Menu   Esc"]]:
		var b := OathTheme.button(item[1], open_page.bind(item[0]))
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		hud.add_child(b)
	_rebuild_status(GameState.lead_creature())

func _rebuild_status(creature: CreatureInstance) -> void:
	_clear(status_panel)
	_lead = creature
	_last_hp = -1
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(row)
	if creature != null:
		status_portrait = OathTheme.portrait(creature.species, 40)
		row.add_child(status_portrait)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	status_text = OathTheme.label("", 12)
	status_hp = OathTheme.label("", 10, OathTheme.MUTED)
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
	status_hp.text = "%d / %d HP   ·   LEAD COMPANION" % [lead.current_hp, lead.max_hp()]
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

func _build_sidebar(layout: HBoxContainer) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 140
	sidebar.add_theme_constant_override("separation", 6)
	layout.add_child(sidebar)
	sidebar.add_child(OathTheme.label("◇   O A T H B O U N D", 10, OathTheme.GOLD))
	sidebar.add_child(OathTheme.heading("Field companion", 22))
	sidebar.add_child(OathTheme.rule())
	for item in [["menu", "01    Journey"], ["party", "02    Companions"], ["journal", "03    Field journal"]]:
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
	if is_open(): nav_buttons.get(page, nav_buttons["party"]).grab_focus()

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
	actions.add_child(OathTheme.button("Settings", func(): world.settings_menu.open()))
	actions.add_child(OathTheme.button("Title screen", func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn")))
	body.add_child(OathTheme.label("SESSION PLAY  ·  Closing the game resets this journey.", 9, OathTheme.MUTED))

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
	top.add_child(OathTheme.button("←  " + ("Field journal" if specimen else "Companions"), _go_back))
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
			var matches_text := journal_filter.to_lower() in (species.display_name + " " + species.type_display_name()).to_lower()
			entry.card.visible = matches_text and (journal_element == -1 or species.types().has(journal_element))
			if entry.card.visible: count += 1
		empty.visible = count == 0
		for i in filter_buttons.size():
			filter_buttons[i].add_theme_color_override("font_color", OathTheme.GOLD if i - 1 == journal_element else OathTheme.MUTED)
	search.text_changed.connect(func(query: String): journal_filter = query; apply_filter.call())
	for i in filter_buttons.size():
		filter_buttons[i].pressed.connect(func(): journal_element = i - 1; apply_filter.call())
	apply_filter.call()

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
