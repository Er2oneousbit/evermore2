# =============================================================================
# names.gd  (autoload: Names)
# -----------------------------------------------------------------------------
# WHAT:  Loads every proper noun (characters, places, items) from
#        res://data/names.json and hands them out by key.
# WHY:   PROJECT RULE: no character/place/item names hardcoded in code or
#        scenes. A full rename (typo fix, localization, or a spiritual-
#        successor rebrand) should be a one-file edit.
#
# USAGE:
#   Names.text("robot")          -> "Carltron"
#   Names.text("realm_hub")      -> "The Mansion That Was"
#   Missing keys return "[missing:key]" and log a warning ONCE, so typos show
#   up loudly on screen instead of silently becoming blank labels.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const NAMES_PATH := "res://data/names.json"

var _names: Dictionary = {}
var _warned_keys: Dictionary = {}  # used as a set: key -> true


func _ready() -> void:
	_load()


## Returns the display name for `key`. Keys starting with "_" are comments.
func text(key: String) -> String:
	if _names.has(key):
		return str(_names[key])
	if not _warned_keys.has(key):
		_warned_keys[key] = true
		Debug.log_warn("Names: missing key '%s' in %s" % [key, NAMES_PATH])
	return "[missing:%s]" % key


## Re-read the JSON file. Handy from a debug console while editing names.
func reload() -> void:
	_names.clear()
	_warned_keys.clear()
	_load()


func _load() -> void:
	if not FileAccess.file_exists(NAMES_PATH):
		Debug.log_error("Names: %s not found. Every name will show as [missing:...]" % NAMES_PATH)
		return

	var raw := FileAccess.get_file_as_string(NAMES_PATH)
	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		Debug.log_error("Names: JSON error in %s line %d: %s"
				% [NAMES_PATH, json.get_error_line(), json.get_error_message()])
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		Debug.log_error("Names: %s must contain a JSON object at the top level" % NAMES_PATH)
		return

	_names = json.data
	Debug.log_verbose("Names: loaded %d entries" % _names.size())
