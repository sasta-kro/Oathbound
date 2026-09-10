class_name OathTheme
extends RefCounted
## Shared palette, typography and components. Sizes are in the 960×540 canvas.
const INK = Color("101d21")
const SURFACE = Color("18292c")
const PAPER = Color("f0ead9")
const MUTED = Color("93a8a5")
const JADE = Color("a1cdb5")
const GOLD = Color("d9bb80")
const LINE = Color("354647")
const SERIF = preload("res://assets/ui/fonts/display_font.tres")
const SANS = preload("res://assets/ui/fonts/interface_font.tres")
const ELEMENT_COLORS = [Color("e9a078"), Color("c6c38a"), Color("83c5dc"), Color("a9d8c2")]

static func box(color: Color, border: Color = LINE, radius: int = 8, padding: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(1)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font = SANS
	t.default_font_size = 13
	t.set_color("font_color", "Label", PAPER)
	for type in ["Button", "OptionButton", "LineEdit"]:
		t.set_stylebox("normal", type, box(SURFACE, LINE, 6, 10))
		t.set_stylebox("hover", type, box(Color("253c3b"), JADE, 6, 10))
		t.set_stylebox("pressed", type, box(Color("314840"), GOLD, 6, 10))
		t.set_stylebox("disabled", type, box(Color("132225"), Color("253536"), 6, 10))
		t.set_stylebox("focus", type, box(Color.TRANSPARENT, GOLD, 6, 10))
		t.set_color("font_color", type, PAPER)
		t.set_color("font_hover_color", type, PAPER)
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_disabled_color", type, MUTED.darkened(0.25))
		t.set_font_size("font_size", type, 13)
	t.set_stylebox("panel", "PanelContainer", box(INK))
	t.set_stylebox("panel", "PopupMenu", box(INK))
	t.set_stylebox("panel", "TooltipPanel", box(SURFACE))
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)
	t.set_stylebox("separator", "HSeparator", box(LINE, Color.TRANSPARENT, 0, 0))
	var scroll := box(LINE, Color.TRANSPARENT, 3, 0)
	scroll.content_margin_left = 3
	scroll.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", scroll)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(JADE, Color.TRANSPARENT, 3, 0))
	return t

static func label(text: String, font_size: int = 13, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

static func heading(text: String, font_size: int = 36) -> Label:
	var l := label(text, font_size)
	l.add_theme_font_override("font", SERIF)
	return l

static func paragraph(text: String, font_size: int = 12, color: Color = MUTED) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 36
	b.pressed.connect(action)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		b.add_theme_stylebox_override("normal", box(JADE, JADE, 6, 10))
		b.add_theme_stylebox_override("hover", box(PAPER, PAPER, 6, 10))
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_focus_color", INK)
	return b

static func chip(text: String, tint: Color = JADE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := box(Color(tint, 0.08), Color(tint, 0.26), 4, 5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label(text, 10, tint))
	return panel

static func element(species: CreatureSpecies) -> Color:
	return ELEMENT_COLORS[clampi(int(species.primary_type), 0, 3)]

static func portrait(species: CreatureSpecies, side: float = 90) -> Control:
	var view := preload("res://scripts/ui/creature_portrait.gd").new()
	view.custom_minimum_size = Vector2(side, side)
	view.setup(species)
	return view

static func gallery(species: CreatureSpecies, height: float = 140) -> Control:
	var view := preload("res://scripts/ui/creature_gallery.gd").new()
	view.custom_minimum_size.y = height
	view.setup(species)
	return view

static func bar(value: float, tint: Color = JADE) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size.y = 5
	b.show_percentage = false
	b.value = value * 100.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("fill", box(tint, Color.TRANSPARENT, 3, 0))
	b.add_theme_stylebox_override("background", box(Color("2c3d3e"), Color.TRANSPARENT, 3, 0))
	return b

static func spacer(vertical: bool = true) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical: s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else: s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

static func rule() -> HSeparator:
	var r := HSeparator.new()
	r.custom_minimum_size.y = 1
	return r
