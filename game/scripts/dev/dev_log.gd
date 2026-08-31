class_name DevLog
extends RefCounted
## Development diagnostics for missing assets and content problems
## (Specification 23.5).
##
## Output is centrally suppressible so development messages are never
## inseparable from final game presentation. Toggle with the project setting
## [code]oathbound/dev/verbose_diagnostics[/code].

const SETTING_VERBOSE := "oathbound/dev/verbose_diagnostics"

static var _reported: Dictionary = {}


static func is_verbose() -> bool:
	return bool(ProjectSettings.get_setting(SETTING_VERBOSE, OS.is_debug_build()))


## Reports a missing asset once per unique kind/id pair so a missing sprite does
## not flood the log every frame.
static func missing_asset(kind: String, content_id: StringName) -> void:
	var key := "%s:%s" % [kind, content_id]
	if _reported.has(key):
		return
	_reported[key] = true
	if is_verbose():
		print_rich(
			(
				"[color=yellow][MISSING %s][/color] %s - using placeholder."
				% [kind.to_upper(), content_id]
			)
		)


static func content_problem(message: String) -> void:
	push_warning("[CONTENT] %s" % message)


static func info(message: String) -> void:
	if is_verbose():
		print("[DEV] %s" % message)


## Clears the "reported once" memory. Used by tests.
static func reset() -> void:
	_reported.clear()
