class_name DialoguePanel
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var dialogue_text: Label = $Panel/Margin/DialogueText
var _entrance: Tween

func _ready() -> void:
	panel.theme = OathTheme.make()
	panel.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.INK, OathTheme.GOLD.darkened(0.5), 8, 0))
	dialogue_text.add_theme_font_size_override("font_size", 16)
	var margin: MarginContainer = $Panel/Margin
	margin.remove_child(dialogue_text)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var caption := HBoxContainer.new()
	content.add_child(caption)
	caption.add_child(OathTheme.label("BY THE ROADSIDE", 9, OathTheme.GOLD))
	caption.add_child(OathTheme.spacer(false))
	caption.add_child(OathTheme.label("E  /  CONTINUE", 9, OathTheme.MUTED))
	content.add_child(dialogue_text)
	panel.hide()

func show_line(line: String) -> void:
	dialogue_text.text = line
	panel.show()
	if _entrance != null: _entrance.kill()
	panel.modulate.a = 0
	_entrance = create_tween()
	_entrance.tween_property(panel, "modulate:a", 1.0, 0.15)

func close() -> void:
	panel.hide()

func is_open() -> bool:
	return panel.visible
