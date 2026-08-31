class_name DialoguePanel
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var dialogue_text: Label = $Panel/Margin/DialogueText


func _ready() -> void:
	panel.hide()


func show_line(line: String) -> void:
	dialogue_text.text = line
	panel.show()


func close() -> void:
	panel.hide()


func is_open() -> bool:
	return panel.visible
