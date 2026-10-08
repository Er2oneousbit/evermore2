# =============================================================================
# interaction.gd  (autoload: Interaction)
# -----------------------------------------------------------------------------
# WHAT:  Decides what the one you drive (Party.leader) would talk to / use if
#        you pressed interact now: the nearest node in the "interactable"
#        group, within its range, not behind him, and one he can use. The HUD
#        shows a prompt for it; the kid and the dog call
#        Interaction.try_interact() on the interact button.
#
# AN INTERACTABLE is any Node2D in group "interactable" with:
#   func interact() -> void            do the thing (talk, open, pick up)
#   func interact_label() -> String    prompt text, e.g. "Talk to Maya"
#   var interact_range: float          optional, px (default RANGE)
#   func can_interact(who) -> bool     optional: who may use it. Without it,
#                                      only the kid (talking is his: NPCs)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Default reach (px) for interactables without their own interact_range.
const RANGE := 40.0
## How far "behind" the kid still counts (dot product with his facing).
const BEHIND_LIMIT := -0.3

var _target: Node2D


func current_target() -> Node2D:
	return _target if is_instance_valid(_target) else null


## Interact with the current target. True if something happened.
func try_interact() -> bool:
	var t := current_target()
	if t == null or Dialogue.is_active():
		return false
	t.interact()
	return true


func _physics_process(_delta: float) -> void:
	var best: Node2D = null
	var who := Party.leader
	if is_instance_valid(who) and who.get("controlled") and not Dialogue.is_active():
		var best_score := INF
		for n in get_tree().get_nodes_in_group("interactable"):
			var node := n as Node2D
			# Own visibility only: in HD-2D mode the 2D World is hidden on
			# purpose, and its NPCs must still be talkable.
			if node == null or not node.visible:
				continue
			# Only the kid talks: while you drive the dog, only his things
			# (a spot he's smelled, to dig) are in reach.
			if not (node.can_interact(who) if node.has_method("can_interact") else who is Kid):
				continue
			var reach: float = node.get("interact_range") if node.get("interact_range") != null else RANGE
			var to := node.global_position - who.global_position
			var dist := to.length()
			if dist > reach:
				continue
			var dot: float = (who.facing as Vector2).dot(to / dist) if dist > 4.0 else 1.0
			if dot < BEHIND_LIMIT:
				continue
			# Closer wins; things in front of him win ties.
			var score := dist - dot * 12.0
			if score < best_score:
				best_score = score
				best = node
	if best != _target:
		_target = best
		EventBus.interaction_target_changed.emit(best)
