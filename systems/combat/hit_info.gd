# =============================================================================
# hit_info.gd  -  Everything about one hit: how hard, from where, from whom
# -----------------------------------------------------------------------------
# WHAT:  Built by whoever attacks, handed to every Hurtbox it reaches.
#        Health applies the damage; the actor reads knockback and stagger.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name HitInfo
extends RefCounted

## Damage before armor.
var damage := 1.0
## Push away from the attacker (px/s, applied as a velocity kick).
var knockback := Vector2.ZERO
## Seconds the target can't act.
var stagger := 0.0
## "player" or "enemy": hits never land on their own team.
var team := "player"
## Who swung (can be null).
var source: Node = null
## Charge level of the swing (0 = partial, 1-3), for effects.
var level := 1


static func make(dmg: float, from: Vector2, to: Vector2, push: float, team_name: String, who: Node = null) -> HitInfo:
	var h := HitInfo.new()
	h.damage = dmg
	h.knockback = from.direction_to(to) * push if from != to else Vector2.ZERO
	h.team = team_name
	h.source = who
	return h
