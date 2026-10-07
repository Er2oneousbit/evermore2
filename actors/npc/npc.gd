# =============================================================================
# npc.gd  -  Someone standing in the world who talks when you walk up to them
# -----------------------------------------------------------------------------
# WHAT:  A character from data/characters/<character_id>.tres (sprite and
#        name) who starts a .dlg conversation when the kid interacts. Turns to
#        face the kid while talking, then back to where they were looking.
#        Solid on the "world" physics layer, so the kid and dog walk around.
# PLACE:  from an AsciiRealm's NPCS_BY_CHAR, or drop npc.tscn in a scene and
#        set character_id, dialogue_file and start_node in the inspector.
# HD-2D: in group "hd_actor", so HdView draws it in the 3D view too.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Npc
extends CharacterBody2D

## Speaker ID: data/characters/<ID>.tres (also the ID used in .dlg lines).
@export var character_id := ""
## The .dlg file and node this NPC starts.
@export_file("*.dlg") var dialogue_file := ""
@export var start_node := ""
## Where the NPC looks when nobody is talking to them.
@export var idle_facing := Vector2.DOWN
## How close the kid must be to talk (px).
@export var interact_range := 40.0

var _talking := false

@onready var _sprite: LpcSprite = $Sprite


func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")
	add_to_group("hd_actor")
	var c := Dialogue.character(character_id)
	if c == null:
		Debug.log_warn("Npc: no data/characters/%s.tres" % character_id)
	else:
		_sprite.texture = c.sheet
		if name.begins_with("Npc") or name.begins_with("@"):
			name = character_id.capitalize()
	_sprite.play(&"idle", idle_facing)
	Dialogue.ended.connect(_on_dialogue_ended)


func interact() -> void:
	var kid := get_tree().get_first_node_in_group("kid") as Node2D
	if kid:
		_sprite.play(&"idle", global_position.direction_to(kid.global_position))
	_talking = Dialogue.start(dialogue_file, start_node, self)


func interact_label() -> String:
	var c := Dialogue.character(character_id)
	return "Talk to %s" % (c.display_name() if c else character_id)


## Which way the sprite faces (tests use it).
func sprite_dir() -> DirectionalSprite.Dir:
	return _sprite.dir


func _on_dialogue_ended(_node: String) -> void:
	if _talking:
		_talking = false
		_sprite.play(&"idle", idle_facing)
