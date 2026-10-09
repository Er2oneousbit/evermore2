# =============================================================================
# game_state.gd  (autoload: GameState)
# -----------------------------------------------------------------------------
# WHAT:  The current run's state: player-chosen names, current realm, and
#        story flags. Everything the SaveManager will eventually serialize.
# WHY:   One obvious place to look when asking "what does the game currently
#        believe is true?"
#
# FLAGS: simple key -> value pairs for story progress, e.g.
#   GameState.set_flag("big_yard.vacuum_defeated", true)
#   if GameState.get_flag("big_yard.vacuum_defeated"): ...
#   Convention: "<realm>.<thing>" so flags group nicely in save files.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Player-chosen names. Empty means "not chosen yet, use the default".
var kid_name := ""
var dog_name := ""

## Key from names.json for the place the player is in, e.g. "place_ruffleberg_lot".
## Each AsciiRealm sets it from its REALM_NAME_KEY when it loads.
var current_realm := "realm_test_yard"

## "normal" or "hard" (see Difficulty). Chosen when a game starts.
var difficulty := "normal"

## How the AI plays each one when he isn't the one you drive (see Party).
## The kid: "offensive" or "defensive". The dog: "offensive" or "search".
var kid_stance := "offensive"
var dog_stance := "offensive"

## What the party carries: item id (data/items/<id>.tres) -> count. Every
## adventure starts with a stick.
var inventory: Dictionary = {"stick": 1}

## What each of the duo wears: "kid"/"dog" -> slot -> item id ("" = nothing).
## See Equipment (systems/items/equipment.gd) for the rules.
var equipped: Dictionary = {"kid": {"weapon": "stick"}, "dog": {}}

## Alchemy formulas the kid knows: id -> {"level": n, "xp": casts toward the
## next level}. See Usables.
var formulas: Dictionary = {}

## The four quick slots: "item:<id>", "formula:<id>" or "" (empty).
var quick_slots: Array[String] = ["", "", "", ""]

var _flags: Dictionary = {}


## Display name for the kid (player choice, or the default from names.json).
func get_kid_name() -> String:
	return kid_name if not kid_name.is_empty() else Names.text("kid_default")


## Display name for the dog (player choice, or the shelter's name for him).
func get_dog_name() -> String:
	return dog_name if not dog_name.is_empty() else Names.text("dog_default")


func set_flag(flag: String, value: Variant = true) -> void:
	_flags[flag] = value
	EventBus.flag_changed.emit(flag, value)
	Debug.log_verbose("Flag set: %s = %s" % [flag, value])


func get_flag(flag: String, default: Variant = false) -> Variant:
	return _flags.get(flag, default)


## Forget every flag of one realm ("prologue." -> the prologue plays fresh).
func clear_flags(prefix: String) -> void:
	for flag: String in _flags.keys():
		if flag.begins_with(prefix):
			_flags.erase(flag)


## Add (or, with a negative count, take away) items. Never below zero.
func add_item(item_id: String, count := 1) -> void:
	inventory[item_id] = maxi(0, int(inventory.get(item_id, 0)) + count)


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))
