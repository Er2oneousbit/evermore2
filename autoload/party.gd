# =============================================================================
# party.gd  (autoload: Party)
# -----------------------------------------------------------------------------
# WHAT:  The kid and the dog as a team. Phase A of combat: who's in the party,
#        and what happens when someone is knocked out:
#          - one member down: he gets back up after REVIVE_SECONDS with a
#            fraction of his HP (the other one keeps fighting)
#          - both down: "Knocked out", then the scene restarts
#        Phase B adds switching control, Stay put and stances here.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Emitted when everyone is down (the scene restarts shortly after).
signal wiped

const REVIVE_SECONDS := 8.0
const REVIVE_FRACTION := 0.3
const WIPE_RESTART_SECONDS := 2.5

var kid: Node2D
var dog: Node2D


func register(member: Node2D) -> void:
	if member.is_in_group("kid"):
		kid = member
	elif member.is_in_group("dog"):
		dog = member
	var h: Health = member.get_node_or_null("Health")
	if h:
		h.died.connect(_on_member_died.bind(member))


func members() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for m in [kid, dog]:
		if is_instance_valid(m):
			out.append(m)
	return out


func is_down(member: Node2D) -> bool:
	return is_instance_valid(member) and member.get("downed") == true


func _on_member_died(member: Node2D) -> void:
	var all_down := true
	for m in members():
		if not is_down(m):
			all_down = false
	if all_down:
		_wipe()
		return
	await get_tree().create_timer(REVIVE_SECONDS, false).timeout
	if is_instance_valid(member) and is_down(member) and not _all_down():
		member.revive(REVIVE_FRACTION)


func _all_down() -> bool:
	for m in members():
		if not is_down(m):
			return false
	return true


func _wipe() -> void:
	wiped.emit()
	Debug.log_info("Party knocked out; restarting the scene")
	await get_tree().create_timer(WIPE_RESTART_SECONDS, false).timeout
	if _all_down():
		get_tree().reload_current_scene()
