# =============================================================================
# map_exits.gd  -  A realm's ways out: walk into one and Travel takes over
# -----------------------------------------------------------------------------
# WHAT:  AsciiRealm builds one of these from its EXITS table (exit cells on
#        the map's edge). Every physics frame it checks where the one you drive
#        (Party.leader: the kid, or the dog when you drive him) stands; inside
#        an exit cell it calls Travel.go(scene, entry). The partner comes along.
#
# NO BOUNCE: right after arriving, exits are ignored until the leader has been
#        seen standing outside every exit once (`armed`). Entries already put
#        the party a few tiles inside the map; this also covers a spawn that
#        lands on an exit, so a map can never throw you straight back.
#
# Not while a conversation runs, the leader is knocked out, the tree is
#        paused or a swap is already running.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name MapExits
extends Node

## [{"rect": Rect2, "to": scene path, "entry": entry id, "cell": Vector2i, "out": Vector2}]
var exits: Array[Dictionary] = []
## False until the leader has stood outside every exit since this map loaded.
var armed := false


func add(cell: Vector2i, rect: Rect2, to: String, entry: String, out: Vector2) -> void:
	exits.append({"cell": cell, "rect": rect, "to": to, "entry": entry, "out": out})


## The exit whose area holds `p` (world px), or {} if none.
func exit_at(p: Vector2) -> Dictionary:
	for e in exits:
		if (e["rect"] as Rect2).has_point(p):
			return e
	return {}


func _physics_process(_delta: float) -> void:
	var who := Party.leader
	if exits.is_empty() or not is_instance_valid(who):
		return
	var hit := exit_at(who.global_position)
	if not armed:
		armed = hit.is_empty()
		return
	if hit.is_empty() or Travel.busy or Dialogue.is_active() or Party.is_down(who) or get_tree().paused:
		return
	Travel.go(hit["to"], hit["entry"])
