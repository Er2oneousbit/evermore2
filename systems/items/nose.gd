# =============================================================================
# nose.gd  -  The dog's nose: finding hidden items
# -----------------------------------------------------------------------------
# WHAT:  Two ways the dog finds things:
#          Any stance (AI)  when it's calm (nothing awake and after the party),
#                     he notices a hidden item near him and the leader, trots
#                     over, stops, points and barks, then digs it up (buried)
#                     or keeps pointing at the bush it's under (tucked) until
#                     the kid comes for it. Search stance reaches farther,
#                     looks more often, and skips fights to do it
#          sniff (you drive him; C / gamepad B)  scent trails, colored wisps,
#                     lead from him to the nearest few things he can smell:
#                     hidden and lying items (gold), ingredients (green),
#                     people (blue). A buried spot he's smelled can be dug.
#
# RULES: the same leash as the fighting AI (PartnerBrain.LEASH): he never goes
#   after an item far from the leader, and drops one the leader walks away
#   from. One he can't get to (a fence in the way) is skipped for a while.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Nose
extends RefCounted

## Calm, any stance: he notices items within this distance of himself...
const NOTICE_RADIUS := 130.0
## ...that are also within this distance of the leader.
const NEAR_LEADER := 140.0
## Search stance: farther, and he looks around more often.
const NOTICE_RADIUS_SEARCH := 220.0
const NEAR_LEADER_SEARCH := 230.0
const SCAN_SECONDS_SEARCH := 0.15
## Calm means no awake enemy within this distance of him or the leader.
const CALM_RADIUS := 260.0
## Sniff button: how far the scent trails reach, how many, and for how long.
const SNIFF_RANGE := 320.0
const TRAILS := 3
const TRAIL_SECONDS := 5.0
const SCENT_COLORS := {"item": Color(1.0, 0.82, 0.35), "ingredient": Color(0.5, 1.0, 0.45),
		"person": Color(0.55, 0.75, 1.0)}
## How close he gets before pointing: right on a buried spot; a tucked one is
## under a solid bush, so he stops a little short.
const ARRIVE_BURIED := 10.0
const ARRIVE_TUCKED := 30.0
## He points (stands still, facing it, one bark) this long before digging.
const POINT_SECONDS := 0.9
## A tucked find: he keeps pointing this long, or until the kid gets close.
const HOLD_SECONDS := 4.0
const KID_CLOSE := 50.0
## Not getting any closer for this long means it's out of reach: skip it.
const STALL_SECONDS := 1.5
const SKIP_SECONDS := 12.0
const SCAN_SECONDS := 0.4

enum Mode { NONE, GO, POINT, DIG, HOLD }

var dog: CharacterBody2D
## The hidden item he's working on (null = none).
var find: HiddenItem
var mode := Mode.NONE

var _eager := false
var _t := 0.0
var _scan := 0.0
var _best_dist := INF
var _stall := 0.0
## instance id -> seconds left before he tries that item again.
var _skip := {}


func _init(member: CharacterBody2D) -> void:
	dog = member


## Working on a find. DIG counts only while he's actually digging: a dig can
## outlive the stance that started it.
func busy() -> bool:
	return mode != Mode.NONE and not (mode == Mode.DIG and not dog.is_digging())


## The velocity he wants, or null when he has nothing to sniff out (then he
## just follows). `eager` = Search stance (farther, quicker, ignores fights);
## otherwise he only works while it's calm.
func think(delta: float, leader: Node2D, eager := false) -> Variant:
	_eager = eager
	if not eager and not calm(leader):
		cancel()
		return null
	for id in _skip.keys():
		_skip[id] -= delta
		if _skip[id] <= 0.0:
			_skip.erase(id)
	if mode != Mode.NONE and (not is_instance_valid(find) or find.is_queued_for_deletion()):
		_done()
	match mode:
		Mode.NONE:
			_scan -= delta
			if _scan <= 0.0:
				_scan = SCAN_SECONDS_SEARCH if eager else SCAN_SECONDS
				_pick(leader)
			return null if mode == Mode.NONE else Vector2.ZERO
		Mode.GO:
			return _go(delta, leader)
		Mode.POINT:
			_face_find()
			_t -= delta
			if _t <= 0.0:
				if find.kind == "buried":
					mode = Mode.DIG
					dog.dig(find)
				else:
					find.pointed = true
					mode = Mode.HOLD
					_t = HOLD_SECONDS
			return Vector2.ZERO
		Mode.DIG:
			if not dog.is_digging():
				_done()
			return Vector2.ZERO
		Mode.HOLD:
			_face_find()
			_t -= delta
			var kid_near := is_instance_valid(leader) and leader.global_position.distance_to(find.global_position) < KID_CLOSE
			if _t <= 0.0 or kid_near:
				_done()
				return null
			return Vector2.ZERO
	return null


## Stop whatever he was doing (stance change, Stay put, a fight, a switch).
## A dig already under way finishes (the item still pops out).
## True when no awake enemy is near him or the leader (nothing to fight).
func calm(leader: Node2D) -> bool:
	for n in dog.get_tree().get_nodes_in_group("enemy"):
		var e := n as Node2D
		if not PartnerBrain._alive(e) or not e.is_active():
			continue
		if e.global_position.distance_to(dog.global_position) < CALM_RADIUS:
			return false
		if is_instance_valid(leader) and e.global_position.distance_to(leader.global_position) < CALM_RADIUS:
			return false
	return true


func cancel() -> void:
	if mode != Mode.NONE and not dog.is_digging():
		_done()


func _pick(leader: Node2D) -> void:
	if not is_instance_valid(leader):
		return
	var best: HiddenItem = null
	var best_d := INF
	for n in dog.get_tree().get_nodes_in_group("hidden_item"):
		var h := n as HiddenItem
		if h == null or h.is_queued_for_deletion() or _skip.has(h.get_instance_id()):
			continue
		if h.kind == "tucked" and h.pointed:
			continue  # already shown to the kid
		var d := dog.global_position.distance_to(h.global_position)
		var notice := NOTICE_RADIUS_SEARCH if _eager else NOTICE_RADIUS
		var near := NEAR_LEADER_SEARCH if _eager else NEAR_LEADER
		if d > notice or h.global_position.distance_to(leader.global_position) > near:
			continue
		if d < best_d:
			best_d = d
			best = h
	if best:
		find = best
		find.sniffed = true
		mode = Mode.GO
		_best_dist = INF
		_stall = 0.0
		Debug.log_verbose("Nose: going for %s (%s)" % [find.item.id if find.item else "?", find.kind])


func _go(delta: float, leader: Node2D) -> Variant:
	if not is_instance_valid(leader) or find.global_position.distance_to(leader.global_position) > PartnerBrain.LEASH:
		_skip_find(2.0)  # the leader walked off: follow, try again later
		return null
	var to := find.global_position - dog.global_position
	var dist := to.length()
	var arrive := ARRIVE_BURIED if find.kind == "buried" else ARRIVE_TUCKED
	if dist <= arrive:
		mode = Mode.POINT
		_t = POINT_SECONDS
		_face_find()
		dog.bark()
		return Vector2.ZERO
	# Stuck behind something: give up on this one for a while.
	if dist < _best_dist - 1.0:
		_best_dist = dist
		_stall = 0.0
	else:
		_stall += delta
		if _stall >= STALL_SECONDS:
			_skip_find(SKIP_SECONDS)
			return null
	return to / dist * dog.walk_speed


func _face_find() -> void:
	var to: Vector2 = find.global_position - dog.global_position
	if to.length() > 0.5:
		dog.facing = to.normalized()


func _skip_find(seconds: float) -> void:
	if is_instance_valid(find):
		_skip[find.get_instance_id()] = seconds
	_done()


func _done() -> void:
	find = null
	mode = Mode.NONE
	_scan = SCAN_SECONDS


# -----------------------------------------------------------------------------
# The sniff button
# -----------------------------------------------------------------------------
## Show scent trails to the nearest few things in range; buried spots among
## them become diggable. Returns what the trails lead to.
func sniff() -> Array:
	var origin: Vector2 = dog.global_position
	var found := []
	for group in ["hidden_item", "item_pickup", "npc"]:
		for n in dog.get_tree().get_nodes_in_group(group):
			var node := n as Node2D
			if node == null or node.is_queued_for_deletion():
				continue
			var d := origin.distance_to(node.global_position)
			if d <= SNIFF_RANGE:
				found.append([d, node])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var targets := []
	for pair in found.slice(0, TRAILS):
		var node: Node2D = pair[1]
		targets.append(node)
		var scent: String = node.scent_kind() if node.has_method("scent_kind") else "person"
		Fx.scent_trail(dog, node, SCENT_COLORS.get(scent, SCENT_COLORS["item"]), TRAIL_SECONDS)
		if node is HiddenItem:
			(node as HiddenItem).sniffed = true
	EventBus.dog_sniffed.emit(targets)
	return targets
