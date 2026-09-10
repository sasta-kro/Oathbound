class_name VfxPreview
extends Node2D
## Development scene for tuning spell effects.
##
## Plays every preset in `res://content/vfx` side by side on a loop, so a new
## effect can be judged against the ones already in the game without starting a
## battle. Nothing in the game depends on this; it is a workbench.

const PRESET_DIR := "res://content/vfx"
const COLUMNS := 5
const CELL := Vector2(185, 165)
const ORIGIN := Vector2(95, 105)
## Gap between one full pass of every effect and the next.
const REPLAY_PAUSE := 0.6
## Effects are drawn at battle size; the preview shows them smaller.
const PREVIEW_SCALE := 0.55

var _presets: Array[VfxPreset] = []
var _slots: Array[Node2D] = []


func _ready() -> void:
	_load_presets()
	_build_layout()
	_replay_forever()


func _load_presets() -> void:
	for file_name: String in DirAccess.get_files_at(PRESET_DIR):
		var resource_name := file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		var preset := ResourceLoader.load(PRESET_DIR.path_join(resource_name)) as VfxPreset
		if preset != null:
			_presets.append(preset)
	# Element fallbacks have no file, so show them too: they are what a move
	# with no preset actually plays.
	for type: int in Elements.all():
		_presets.append(VfxPreset.for_element(type))


func _build_layout() -> void:
	for index: int in _presets.size():
		var slot := Node2D.new()
		slot.position = ORIGIN + Vector2(
			float(index % COLUMNS) * CELL.x, float(index / COLUMNS) * CELL.y
		)
		# Effects are authored at battle scale, where creatures are five times
		# the size of their art. Shrink them so a whole set fits one screen.
		slot.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
		add_child(slot)
		_slots.append(slot)

		var label := Label.new()
		label.text = String(_presets[index].id)
		label.position = Vector2(-CELL.x * 0.5, CELL.y * 0.4) / PREVIEW_SCALE
		label.size = Vector2(CELL.x, 24) / PREVIEW_SCALE
		label.scale = Vector2.ONE / PREVIEW_SCALE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(label)


func _replay_forever() -> void:
	while is_inside_tree():
		for index: int in _presets.size():
			var slot: Node2D = _slots[index]
			# A travelling effect needs somewhere to travel to, so every slot
			# casts from its left edge towards its right.
			VfxPlayer.play(slot, _presets[index], Vector2(-70, 0), Vector2(50, 0))
		await get_tree().create_timer(_longest_preset() + REPLAY_PAUSE).timeout


func _longest_preset() -> float:
	var longest := 0.5
	for preset: VfxPreset in _presets:
		longest = maxf(longest, preset.play_seconds())
	return longest


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color(0.09, 0.10, 0.13))
