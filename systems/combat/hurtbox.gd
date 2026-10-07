# =============================================================================
# hurtbox.gd  -  The part of an actor that can be hit
# -----------------------------------------------------------------------------
# WHAT:  A marker circle (radius, centered on the node) on an actor's body.
#        Attacks don't use physics overlaps: at the moment of impact the
#        attacker asks Combat.hits_in_arc() for every hurtbox inside its swing,
#        which is exact, frame-rate proof and easy to test.
# TEAM:  "player" (kid, dog) or "enemy". A hit never lands on its own team.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Hurtbox
extends Node2D

@export_enum("player", "enemy") var team := "enemy"
## Size of the hittable circle (px).
@export var radius := 10.0
## The Health node this hurtbox feeds. Defaults to a sibling named "Health".
@export var health_path: NodePath = ^"../Health"

@onready var health: Health = get_node_or_null(health_path)


func _ready() -> void:
	add_to_group("hurtbox")


## Who owns this hurtbox (the actor).
func actor() -> Node2D:
	return get_parent() as Node2D


## Deliver a hit. Returns the damage dealt (0 = blocked, invulnerable, same team).
func receive(info: HitInfo) -> int:
	if info.team == team or health == null:
		return 0
	var dealt := health.take_hit(info)
	if dealt > 0 and actor() and actor().has_method("on_hit"):
		actor().on_hit(info, dealt)
	return dealt
