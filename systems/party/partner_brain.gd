# =============================================================================
# partner_brain.gd  -  How the AI plays whichever party member you aren't driving
# -----------------------------------------------------------------------------
# WHAT:  Each frame it picks between following the leader (Follower) and
#        fighting, based on the member's STANCE (Party / GameState):
#          offensive  goes after awake enemies near the leader and swings as
#                     soon as the charge reaches level 1
#          defensive  (kid) stays with the leader and only swings at enemies
#                     that come within reach, waiting for a full charge
#          search     (dog) keeps out of fights, follows and sniffs around;
#                     he only bites back at something that's after him
#        Stay put (Party) overrides the moving: a staying partner stands its
#        ground but still swings at anything that comes within reach.
#
# RULES THAT KEEP IT FAIR:
#   * Never wakes sleeping enemies: only enemies already active count.
#   * Never strays more than LEASH px from the leader: past that it drops the
#     fight and catches up (so it can't be kited across the map).
#
# THE MEMBER (Kid or Dog) provides: follower, charge, weapon, facing,
#   walk_speed, attack().
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name PartnerBrain
extends RefCounted

## Offensive: awake enemies within this distance of the LEADER get engaged.
const ENGAGE_RADIUS := 150.0
## Never fight farther than this from the leader.
const LEASH := 240.0
## Defensive / staying: only enemies within reach x this of the member.
const GUARD_FACTOR := 1.3
## Close in until the target is within reach x this (a bit inside, so the
## swing's arc reliably covers it).
const CLOSE_IN := 0.8
## How often (s) it looks for a better target.
const RETARGET_SECONDS := 0.25
## Swings start a little above the feet (same as Kid/Dog strike origins).
const SWING_ORIGIN := Vector2(0, -6)

var body: CharacterBody2D
## The enemy it's after right now (null = following).
var target: Node2D

var _retarget := 0.0


func _init(member: CharacterBody2D) -> void:
	body = member


## The velocity the member wants this frame; may start a swing.
func think(delta: float, stance: String, staying: bool, on_screen: bool) -> Vector2:
	var follower: Follower = body.follower
	_retarget -= delta
	if _retarget <= 0.0 or not _alive(target):
		_retarget = RETARGET_SECONDS
		target = _pick_target(stance, staying, follower.target)
	if target == null:
		return follower.steer(delta, on_screen)

	var aim := _aim_point(target)
	var to := aim - (body.global_position + SWING_ORIGIN)
	var dist := to.length()
	var reach: float = body.weapon.reach
	if dist > 0.5:
		body.facing = to / dist
	if staying or stance != "offensive":
		# Holding back: swing only at what's already within reach.
		if dist > reach:
			return Vector2.ZERO if staying else follower.steer(delta, on_screen)
	elif dist > reach * CLOSE_IN:
		return to / dist * body.walk_speed
	# In reach: swing once the charge is where the stance wants it.
	var need: int = body.weapon.max_level if stance == "defensive" else 1
	if body.charge.level() >= need:
		body.attack()
	return Vector2.ZERO


func _pick_target(stance: String, staying: bool, leader: Node2D) -> Node2D:
	if not is_instance_valid(leader):
		return null
	if not staying and body.global_position.distance_to(leader.global_position) > LEASH:
		return null  # too far from the leader: catch up first
	var reach: float = body.weapon.reach
	var guard := staying or stance == "defensive" or stance == "search"
	var best: Node2D = null
	var best_d := INF
	for n in body.get_tree().get_nodes_in_group("enemy"):
		var e := n as Node2D
		if not _alive(e) or not e.is_active():
			continue
		if stance == "search" and e.get("target") != body:
			continue  # nose down: only what's attacking him
		var d := (body.global_position + SWING_ORIGIN).distance_to(_aim_point(e))
		if guard:
			if d > reach * GUARD_FACTOR:
				continue
		elif e.global_position.distance_to(leader.global_position) > ENGAGE_RADIUS:
			continue
		if d < best_d:
			best_d = d
			best = e
	return best


## Untyped on purpose: a dead enemy may already be freed, and a freed object
## can't even be passed as a Node2D.
static func _alive(e) -> bool:
	if not is_instance_valid(e) or not (e as Node2D).is_inside_tree():
		return false
	var h: Health = e.get_node_or_null("Health")
	return h == null or not h.is_dead()


## Where to aim: the enemy's hurtbox (its body), not its feet.
static func _aim_point(e: Node2D) -> Vector2:
	var hb := e.get_node_or_null("Hurtbox") as Node2D
	return hb.global_position if hb else e.global_position
