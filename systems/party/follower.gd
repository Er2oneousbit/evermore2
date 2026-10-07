# =============================================================================
# follower.gd  -  Walks a party member after the leader, along a BREADCRUMB TRAIL
# -----------------------------------------------------------------------------
# WHAT:  The follow brain both party members use when the AI drives them (the
#        dog behind the kid, or the kid behind the dog after a switch). It
#        returns the velocity the body wants; the body applies it.
#
# WHY BREADCRUMBS (instead of "walk straight at the leader"):
#   The leader leaves a crumb every few pixels. The follower walks crumb to
#   crumb, so it goes around corners and fences the same way the leader did
#   instead of face-planting into walls. This is how most SNES-era followers
#   worked, and it needs no navigation mesh.
#
# MODERN UPGRADE ("string pulling"): every shortcut_interval the follower
#   sweeps its own collision box toward crumbs (newest first) and skips
#   straight to the furthest one it can reach. Open ground = it cuts straight
#   across. Fences = the sweep hits them, so it still walks the corners.
#
# ANTI-STUTTER: hysteresis (resume_margin, catch_up_margin) plus easing near
#   follow_distance (slowdown_range). Without these the follower stop-starts
#   every few steps. tests/smoke_follow.gd fails if that regresses.
#
# STATES:
#   IDLE      close enough to the leader; sit tight
#   FOLLOW    walking the trail at normal speed
#   CATCH_UP  far behind; sprinting the trail
#   STAY      told to Stay put (Party); ignores the leader
#
# SAFETY NET: farther than `warp_distance` AND off-screen (stuck, or the
#   leader took a path the follower can't): it warps next to the leader. Past
#   `hard_warp_distance` it warps regardless.
#
# TUNING lives on the BODY as exports with these names (so each actor keeps
#   its own numbers in the inspector): follow_distance, resume_margin,
#   slowdown_range, catch_up_distance, catch_up_margin, warp_distance,
#   hard_warp_distance, walk_speed, sprint_speed, crumb_spacing, max_crumbs,
#   crumb_reached_radius, shortcut_interval.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Follower
extends RefCounted

enum State { IDLE, FOLLOW, CATCH_UP, STAY }

signal state_changed(state_name: String)

## The member doing the following (its exports hold the tuning, see header).
var body: CharacterBody2D
## Who to follow (Party sets the leader).
var target: Node2D
var state: State = State.IDLE
## How many times the safety-net warp fired. If this climbs during normal
## play, the follow logic is failing somewhere (shown on the F3 overlay).
var warp_count := 0

var _trail: Array[Vector2] = []  # global positions, oldest first
var _shortcut_timer := 0.0
var _shape_query := PhysicsShapeQueryParameters2D.new()
var _shape_offset := Vector2.ZERO


func _init(follower_body: CharacterBody2D, collision: CollisionShape2D, blocking_mask: int) -> void:
	body = follower_body
	# Shortcut checks sweep the real body shape, not a thin ray, so a "clear"
	# result means the whole body fits through, corners included.
	_shape_query.shape = collision.shape
	_shape_query.collision_mask = blocking_mask
	_shape_query.exclude = [body.get_rid()]
	_shape_offset = collision.position


## Drop a crumb where the leader stands (call every physics frame, even while
## staying, so a called-back follower can retrace the leader's path).
func record_crumb() -> void:
	if not is_instance_valid(target):
		return
	var pos := target.global_position
	if _trail.is_empty() or _trail.back().distance_to(pos) >= body.crumb_spacing:
		_trail.append(pos)
		if _trail.size() > body.max_crumbs:
			_trail.pop_front()


## The velocity the follower wants this frame. May warp the body (then it
## returns zero). `on_screen` keeps it from teleporting in plain sight.
func steer(delta: float, on_screen: bool) -> Vector2:
	if not is_instance_valid(target) or state == State.STAY:
		return Vector2.ZERO
	var dist := body.global_position.distance_to(target.global_position)

	if dist > body.hard_warp_distance or (dist > body.warp_distance and not on_screen):
		warp()
		return Vector2.ZERO

	# Hysteresis: an idle follower needs a bigger gap before it gets up again.
	var start_distance: float = body.follow_distance + (body.resume_margin if state == State.IDLE else 0.0)
	if dist <= start_distance:
		if state != State.IDLE:
			# Drop the trail on arrival: those crumbs are behind us now. While
			# idle, new crumbs keep recording so we can follow the leader's path.
			_trail.clear()
		set_state(State.IDLE)
		return Vector2.ZERO

	var was_idle := state == State.IDLE
	set_state(_pick_moving_state(dist))
	# Shortcut right away when getting up (skips stale crumbs the leader laid
	# while walking past us), then periodically while moving.
	_shortcut_timer -= delta
	if was_idle or _shortcut_timer <= 0.0:
		_shortcut_timer = body.shortcut_interval
		_try_shortcut()
	var speed: float = body.sprint_speed if state == State.CATCH_UP else body.walk_speed
	# Ease off near the target gap so we trail smoothly instead of stop-go.
	speed *= clampf((dist - body.follow_distance) / body.slowdown_range, 0.3, 1.0)
	return body.global_position.direction_to(_next_waypoint()) * speed


## Teleport next to the leader and reset the trail. Safe to call any time.
func warp() -> void:
	if not is_instance_valid(target):
		return
	# Land slightly behind the leader (opposite of where it faces).
	var behind := Vector2.DOWN
	var f = target.get("facing")
	if f is Vector2 and f != Vector2.ZERO:
		behind = -f
	body.global_position = target.global_position + behind * body.follow_distance
	body.velocity = Vector2.ZERO
	_trail.clear()
	warp_count += 1
	if state != State.STAY:
		set_state(State.IDLE)
	Debug.log_verbose("%s warped to the leader" % body.name)


func set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state_name())


func state_name() -> String:
	return State.keys()[state]


func clear_trail() -> void:
	_trail.clear()


func trail() -> Array[Vector2]:
	return _trail


# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------
## FOLLOW vs CATCH_UP, with its own hysteresis so the follower doesn't flicker
## between walking and sprinting right at catch_up_distance.
func _pick_moving_state(dist: float) -> State:
	if state == State.CATCH_UP:
		return State.CATCH_UP if dist > body.catch_up_distance - body.catch_up_margin else State.FOLLOW
	return State.CATCH_UP if dist > body.catch_up_distance else State.FOLLOW


## String pulling: scan the trail from NEWEST to oldest and jump to the first
## crumb the body can reach in a straight line, dropping every crumb before it.
func _try_shortcut() -> void:
	if _trail.size() < 2:
		return
	var space := body.get_world_2d().direct_space_state
	for i in range(_trail.size() - 1, 0, -1):  # index 0 is already our target
		if _can_reach(space, _trail[i]):
			for _k in i:
				_trail.pop_front()
			return


## True if the body's collision shape can slide straight to `point` unblocked.
func _can_reach(space: PhysicsDirectSpaceState2D, point: Vector2) -> bool:
	_shape_query.transform = Transform2D(0.0, body.global_position + _shape_offset)
	_shape_query.motion = point - body.global_position
	var fractions := space.cast_motion(_shape_query)
	# cast_motion returns [safe, unsafe]; [1, 1] means no hit along the way.
	return fractions.size() == 2 and fractions[0] >= 1.0


## First crumb we still need to walk to. Drops crumbs that are:
##   - reached: within crumb_reached_radius, or
##   - passed:  the NEXT crumb is closer than this one.
## The "passed" rule stops two bugs: orbiting a crumb we overshot on a sharp
## turn, and walking backward to old crumbs after the leader strolled past an
## idle follower. It's safe because consecutive crumbs are only crumb_spacing
## apart on a path the leader actually walked, so no wall can sit between them.
func _next_waypoint() -> Vector2:
	var p := body.global_position
	while not _trail.is_empty():
		var d0 := p.distance_to(_trail[0])
		var reached: bool = d0 <= body.crumb_reached_radius
		var passed := _trail.size() >= 2 and p.distance_to(_trail[1]) < d0
		if not (reached or passed):
			break
		_trail.pop_front()
	return _trail.front() if not _trail.is_empty() else target.global_position
