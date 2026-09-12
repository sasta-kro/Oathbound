extends Node
## Save slots on disk.
##
## Autoloaded as [code]SaveService[/code]. It knows nothing about what a save
## contains: [GameState] builds and reads the dictionary, this node only gets
## it safely onto disk and back. There are [constant SLOT_COUNT] manual slots
## the player writes on purpose, and one autosave slot the field writes at
## state boundaries, kept apart so an autosave never overwrites a save the
## player chose to keep.
##
## Two rules keep an interrupted write from costing the player a slot:
##
## - A save is written to a temporary file first and swapped into place only
##   once it is complete, so a crash mid-write leaves the previous file intact.
## - The previous contents of the slot are kept as a hidden backup. A slot
##   that fails to parse falls back to it on load.

## Emitted after a save reached disk.
signal saved(slot: int)
## Emitted after a slot has been erased.
signal erased(slot: int)

## Manual slots are numbered 1..SLOT_COUNT; the autosave is slot 0.
const SLOT_COUNT: int = 3
const AUTOSAVE_SLOT: int = 0
const NO_SLOT: int = -1

const DEFAULT_SAVE_DIR := "user://saves"
const AUTOSAVE_FILE := "autosave.json"
const SLOT_FILE := "slot_%d.json"
const BACKUP_SUFFIX := ".backup"
const TEMP_SUFFIX := ".tmp"
## Bumped whenever the layout of the save dictionary changes shape in a way
## older code could not read. Older files are still loaded; the version is
## there so a future migration has something to key on.
const FORMAT_VERSION: int = 1
const VERSION_KEY := "format_version"
const SAVED_AT_KEY := "saved_at"

## Where the slots live. Tests point this at a scratch directory.
var save_dir: String = DEFAULT_SAVE_DIR


## Every slot id, autosave first.
static func all_slots() -> PackedInt32Array:
	var slots: PackedInt32Array = [AUTOSAVE_SLOT]
	for slot: int in range(1, SLOT_COUNT + 1):
		slots.append(slot)
	return slots


static func is_valid_slot(slot: int) -> bool:
	return slot >= AUTOSAVE_SLOT and slot <= SLOT_COUNT


static func is_manual_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


static func slot_title(slot: int) -> String:
	return "AUTOSAVE" if slot == AUTOSAVE_SLOT else "SLOT %d" % slot


func slot_path(slot: int) -> String:
	var file_name: String = AUTOSAVE_FILE if slot == AUTOSAVE_SLOT else SLOT_FILE % slot
	return save_dir.path_join(file_name)


func backup_path(slot: int) -> String:
	return slot_path(slot) + BACKUP_SUFFIX


## Whether [param slot] can be loaded: either its file or its backup exists.
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(backup_path(slot))


func has_any_save() -> bool:
	for slot: int in all_slots():
		if has_save(slot):
			return true
	return false


## The slot saved most recently, or [constant NO_SLOT] when every slot is
## empty. This is what "Continue" picks.
func latest_slot() -> int:
	var best: int = NO_SLOT
	var best_time: int = -1
	for slot: int in all_slots():
		var data: Dictionary = read(slot)
		if data.is_empty():
			continue
		var stamp: int = int(data.get(SAVED_AT_KEY, 0))
		if stamp > best_time:
			best = slot
			best_time = stamp
	return best


## Writes [param data] to [param slot]. Returns false when the disk refused
## it, in which case the slot's previous contents are untouched.
func write(slot: int, data: Dictionary) -> bool:
	if not is_valid_slot(slot):
		push_warning("No such save slot: %d" % slot)
		return false
	DirAccess.make_dir_recursive_absolute(save_dir)
	var payload: Dictionary = data.duplicate()
	payload[VERSION_KEY] = FORMAT_VERSION
	var path: String = slot_path(slot)
	var temp_path: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning(
			"Could not write the save at '%s': %s" % [temp_path, error_string(FileAccess.get_open_error())]
		)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	if FileAccess.file_exists(path):
		var rotate_error: Error = DirAccess.rename_absolute(path, backup_path(slot))
		if rotate_error != OK:
			push_warning("Could not keep a backup of the previous save: %s" % error_string(rotate_error))
	var swap_error: Error = DirAccess.rename_absolute(temp_path, path)
	if swap_error != OK:
		push_warning("Could not move the new save into place: %s" % error_string(swap_error))
		return false
	saved.emit(slot)
	return true


## The dictionary saved in [param slot], or an empty one when the slot is
## empty. A file that cannot be parsed is skipped in favour of its backup.
func read(slot: int) -> Dictionary:
	if not is_valid_slot(slot):
		return {}
	for path: String in [slot_path(slot), backup_path(slot)]:
		var data: Dictionary = _read_file(path)
		if not data.is_empty():
			return data
	return {}


## Removes [param slot] and its backup.
func erase(slot: int) -> void:
	if not is_valid_slot(slot):
		return
	var path: String = slot_path(slot)
	for candidate: String in [path, backup_path(slot), path + TEMP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
	erased.emit(slot)


func erase_all() -> void:
	for slot: int in all_slots():
		erase(slot)


## A local wall-clock description of [param unix_time], for slot cards.
func describe_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "never"
	var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time + bias_seconds)
	const MONTHS := [
		"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	]
	return (
		"%d %s %d, %02d:%02d"
		% [local.day, MONTHS[int(local.month) - 1], local.year, local.hour, local.minute]
	)


## "1h 24m" style play time.
func describe_duration(seconds: int) -> String:
	var minutes: int = maxi(0, seconds) / 60
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %02dm" % [minutes / 60, minutes % 60]


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	# The instance parser reports a broken file as a return value rather than
	# an engine error, since a damaged save is expected and handled here.
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary or json.data.is_empty():
		push_warning("The save at '%s' could not be read; trying the backup." % path)
		return {}
	return json.data
