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
#   Names.expand("Hey, {he} waved at {kid}")  -> text with every {...} token
#       filled in: pronouns and {boy|girl} splits follow GameState.kid_gender,
#       {kid}/{dog} are the player's names, {key} any names.json key (see
#       GenderedText for the syntax). Use it on ANY player-facing string that
#       is not a .dlg line (notices, signs, labels). Names.text() does it for
#       its own result, so a names.json value may hold tokens.
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
var _depth := 0


## True if names.json has `key` (the dialogue parser checks {tokens} with it).
func has_key(key: String) -> bool:
	return _names.has(key)


## Fill in every {...} token of `s` (see GenderedText). The one resolver for
## dialogue, notices and names. `gender` defaults to the kid's.
func expand(s: String, gender := "") -> String:
	if not s.contains("{"):
		return s
	_depth += 1
	var out := GenderedText.expand(s, gender if not gender.is_empty() else GameState.kid_gender,
		func(key: String) -> String: return default_name(key))
	_depth -= 1
	return out


## {kid} and {dog} are the player's names; any other key is a names.json entry.
func default_name(key: String) -> String:
	match key:
		"kid":
			return GameState.get_kid_name()
		"dog":
			return GameState.get_dog_name()
	return text(key)


func _ready() -> void:
	_load()


## Returns the display name for `key`. Keys starting with "_" are comments.
func text(key: String) -> String:
	if _names.has(key):
		var raw := str(_names[key])
		if not raw.contains("{") or _depth >= 4:  # depth: a value naming itself must not loop
			return raw
		return expand(raw)
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
