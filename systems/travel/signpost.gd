# =============================================================================
# signpost.gd  -  A sign by a road: walk up, read where it goes
# -----------------------------------------------------------------------------
# WHAT:  The talkable half of a realm's SIGNS entry (the post itself is the
#        "signpost" prop). Interact shows "<place>  ->" as a HUD notice, the
#        arrow pointing the way the road leaves the map.
# WHY:   Place names come from names.json (no proper nouns in code or art), so
#        the board is blank art and the words live here.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Signpost
extends Node2D

const ARROWS := {Vector2.LEFT: "<-", Vector2.RIGHT: "->", Vector2.UP: "^", Vector2.DOWN: "v"}

## names.json key of the place the road leads to.
var place_key := ""
## Which way the road goes from here.
var dir := Vector2.RIGHT
var interact_range := 40.0


func _ready() -> void:
	add_to_group("interactable")


func text() -> String:
	var arrow: String = ARROWS.get(dir, "")
	if dir == Vector2.LEFT:
		return "%s  %s" % [arrow, Names.text(place_key)]
	return "%s  %s" % [Names.text(place_key), arrow]


func interact_label() -> String:
	return "Read the sign"


func interact() -> void:
	Audio.play("ui_confirm")
	EventBus.notice.emit(text())
