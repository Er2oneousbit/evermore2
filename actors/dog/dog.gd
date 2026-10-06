# =============================================================================
# dog.gd  -  The dog companion (AI follower; player 2 control comes later)
# -----------------------------------------------------------------------------
# WHAT:  A small state machine that follows the kid using a BREADCRUMB TRAIL.
#
# WHY BREADCRUMBS (instead of "walk straight at the kid"):
#   The kid leaves a crumb every few pixels. The dog walks crumb to crumb,
#   so it goes around corners and fences the same way the kid did instead of
#   face-planting into walls. This is how most SNES-era followers worked, and
#   it needs no navigation mesh. A NavigationAgent2D can be added later for
#   smarter behaviors (fetch, sniff targets) without replacing this.
#
# MODERN UPGRADE ("string pulling"): every shortcut_interval the dog sweeps
#   its own collision box toward crumbs (newest first) and skips straight to
#   the furthest one it can reach. Open ground = dog cuts straight across.
#   Fences = the sweep hits them, so it still walks the corners.
#
# ANTI-STUTTER: hysteresis (resume_margin, catch_up_margin) plus easing near
#   follow_distance (slowdown_range). Without these the dog stop-starts every
#   few steps. tests/smoke_follow.gd fails if that regresses.
#
# STATES:
#   IDLE      close enough to the kid; sit tight
#   FOLLOW    walking the trail at normal speed
#   CATCH_UP  far behind; sprinting the trail
#   STAY      player told the dog to stay (E / gamepad X); ignores the kid
#
# SAFETY NET: if the dog gets farther than `warp_distance` (stuck, or the kid
#   took a path the dog can't), it warps next to the kid. F4 forces a warp.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Dog
extends CharacterBody2D

enum State { IDLE, FOLLOW, CATCH_UP, STAY }

# --- Tuning ------------------------------------------------------------------
## Who to follow. Set in the level scene; falls back to the "kid" group.
@export var target_path: NodePath
## The dog stops when it is this close to the kid (px).
@export var follow_distance := 22.0
## Once IDLE, the kid must get this much farther than follow_distance before
## the dog gets up again. This dead zone (hysteresis) stops stop-go stutter.
@export var resume_margin := 14.0
## Within this distance past follow_distance the dog eases off its speed, so it
## settles into a smooth trail behind a walking kid instead of bumping into
## follow_distance and stopping every few steps.
@export var slowdown_range := 28.0
## Beyond this distance the dog sprints.
@export var catch_up_distance := 90.0
## Sprinting continues until the gap closes to catch_up_distance minus this.
@export var catch_up_margin := 20.0
## Beyond this distance the dog gives up walking and warps to the kid.
@export var warp_distance := 260.0
@export var walk_speed := 82.0
@export var sprint_speed := 135.0
@export var acceleration := 1400.0
## Distance the kid must move before a new crumb is dropped (px).
@export var crumb_spacing := 6.0
## Hard cap on trail length so memory never grows unbounded.
@export var max_crumbs := 96
## How close the dog must get to a crumb before moving to the next one.
@export var crumb_reached_radius := 4.0
## How often (seconds) the dog looks for a straight-line shortcut along its
## trail ("string pulling"). Lower = smoother corners, slightly more CPU.
@export var shortcut_interval := 0.1
## Physics layers the dog's body can't pass through (layer 1 = "world").
@export_flags_2d_physics var blocking_mask := 1

var state: State = State.IDLE
var facing := Vector2.RIGHT
## How many times the safety-net warp fired. If this climbs during normal
## play, the follow logic is failing somewhere (shown on the F3 overlay).
var warp_count := 0

var _target: Node2D
var _trail: Array[Vector2] = []  # global positions, oldest first
var _shortcut_timer := 0.0
var _shape_query := PhysicsShapeQueryParameters2D.new()

@onready var _collision: CollisionShape2D = $CollisionShape2D

# Placeholder palette: brindle shelter mutt, orange shelter tag.
const COLOR_SHADOW := Color(0, 0, 0, 0.35)
const COLOR_COAT := Color("7a5a3a")
const COLOR_STRIPE := Color("4e3824")
const COLOR_TAG := Color("ff8c1a")
const COLOR_TRAIL := Color(1, 0.55, 0.1, 0.8)
const COLOR_TRAIL_NEXT := Color(1, 1, 0.2, 1)


func _ready() -> void:
	add_to_group("dog")
	_resolve_target()
	# Shortcut checks sweep the dog's real body shape, not a thin ray, so a
	# "clear" result means the whole dog fits through, corners included.
	_shape_query.shape = _collision.shape
	_shape_query.collision_mask = blocking_mask
	_shape_query.exclude = [get_rid()]


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		_resolve_target()
		if not is_instance_valid(_target):
			return  # Nothing to follow (already warned once in _resolve_target).

	_record_crumb()

	if state == State.STAY:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		queue_redraw()
		return

	var dist := global_position.distance_to(_target.global_position)

	if dist > warp_distance:
		warp_to_target()
		return

	# Hysteresis: an idle dog needs a bigger gap before it gets up again.
	var start_distance := follow_distance + (resume_margin if state == State.IDLE else 0.0)

	if dist <= start_distance:
		if state != State.IDLE:
			# Drop the trail on arrival: those crumbs are behind us now. While
			# idle, new crumbs keep recording so we can follow the kid's path.
			_trail.clear()
		_set_state(State.IDLE)
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
	else:
		var was_idle := state == State.IDLE
		_set_state(_pick_moving_state(dist))
		# Shortcut right away when getting up (skips stale crumbs the kid laid
		# while walking past us), then periodically while moving.
		_shortcut_timer -= delta
		if was_idle or _shortcut_timer <= 0.0:
			_shortcut_timer = shortcut_interval
			_try_shortcut()
		var speed := sprint_speed if state == State.CATCH_UP else walk_speed
		# Ease off near the target gap so we trail smoothly instead of stop-go.
		speed *= clampf((dist - follow_distance) / slowdown_range, 0.3, 1.0)
		var waypoint := _next_waypoint()
		var dir := global_position.direction_to(waypoint)
		velocity = velocity.move_toward(dir * speed, acceleration * delta)
		if dir != Vector2.ZERO:
			facing = dir

	move_and_slide()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dog_toggle_stay"):
		if state == State.STAY:
			_set_state(State.FOLLOW)
		else:
			_set_state(State.STAY)
			_trail.clear()
	elif event.is_action_pressed("debug_warp_dog"):
		warp_to_target()


## Teleport next to the kid and reset the trail. Safe to call any time.
func warp_to_target() -> void:
	if not is_instance_valid(_target):
		return
	# Land slightly behind the kid (opposite of where the kid faces).
	var behind := Vector2.DOWN
	if _target is Kid:
		behind = -(_target as Kid).facing
	global_position = _target.global_position + behind * follow_distance
	velocity = Vector2.ZERO
	_trail.clear()
	warp_count += 1
	if state != State.STAY:
		_set_state(State.IDLE)
	Debug.log_verbose("Dog warped to kid")


## State name as text, for the debug overlay and EventBus.
func get_state_name() -> String:
	return State.keys()[state]


## Read-only copy of the trail, for debugging/tests.
func get_trail_size() -> int:
	return _trail.size()


# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------
func _resolve_target() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("kid") as Node2D
	if not is_instance_valid(_target) and not has_meta("warned_no_target"):
		set_meta("warned_no_target", true)
		Debug.log_warn("Dog: no target found (target_path empty and no node in group 'kid')")


## FOLLOW vs CATCH_UP, with its own hysteresis so the dog doesn't flicker
## between walking and sprinting right at catch_up_distance.
func _pick_moving_state(dist: float) -> State:
	if state == State.CATCH_UP:
		return State.CATCH_UP if dist > catch_up_distance - catch_up_margin else State.FOLLOW
	return State.CATCH_UP if dist > catch_up_distance else State.FOLLOW


func _record_crumb() -> void:
	var pos := _target.global_position
	if _trail.is_empty() or _trail.back().distance_to(pos) >= crumb_spacing:
		_trail.append(pos)
		if _trail.size() > max_crumbs:
			_trail.pop_front()


## String pulling: scan the trail from NEWEST to oldest and jump to the first
## crumb the dog can reach in a straight line, dropping every crumb before it.
## Open ground: the dog heads almost straight for the kid. Around fences: it
## still has to walk the corners, because the body-sized sweep hits the fence.
func _try_shortcut() -> void:
	if _trail.size() < 2:
		return
	var space := get_world_2d().direct_space_state
	for i in range(_trail.size() - 1, 0, -1):  # index 0 is already our target
		if _can_reach(space, _trail[i]):
			for _k in i:
				_trail.pop_front()
			return


## True if the dog's collision shape can slide straight to `point` unblocked.
func _can_reach(space: PhysicsDirectSpaceState2D, point: Vector2) -> bool:
	var from := global_position + _collision.position
	_shape_query.transform = Transform2D(0.0, from)
	_shape_query.motion = point - global_position
	var fractions := space.cast_motion(_shape_query)
	# cast_motion returns [safe, unsafe]; [1, 1] means no hit along the way.
	return fractions.size() == 2 and fractions[0] >= 1.0


## First crumb we still need to walk to. Drops crumbs that are:
##   - reached: within crumb_reached_radius, or
##   - passed:  the NEXT crumb is closer than this one.
## The "passed" rule stops two bugs: orbiting a crumb we overshot on a sharp
## turn, and walking backward to old crumbs after the kid strolled past an
## idle dog. It's safe because consecutive crumbs are only crumb_spacing apart
## on a path the kid actually walked, so no wall can sit between them.
func _next_waypoint() -> Vector2:
	while not _trail.is_empty():
		var d0 := global_position.distance_to(_trail[0])
		var reached := d0 <= crumb_reached_radius
		var passed := _trail.size() >= 2 and global_position.distance_to(_trail[1]) < d0
		if not (reached or passed):
			break
		_trail.pop_front()
	return _trail.front() if not _trail.is_empty() else _target.global_position


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	EventBus.dog_state_changed.emit(get_state_name())
	Debug.log_verbose("Dog state -> %s" % get_state_name())


# -----------------------------------------------------------------------------
# Placeholder art (~20x12 px dog) + debug trail drawing
# -----------------------------------------------------------------------------
func _draw() -> void:
	# Debug: draw the breadcrumb trail when the overlay is on.
	if Debug.overlay_visible and not _trail.is_empty():
		for i in _trail.size():
			var p := to_local(_trail[i])
			var c := COLOR_TRAIL_NEXT if i == 0 else COLOR_TRAIL
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c)

	var dir_x := -1.0 if facing.x < 0.0 else 1.0  # flip left/right

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 10.0, COLOR_SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_rect(Rect2(-8, -4, 3, 4), COLOR_STRIPE)                 # back leg
	draw_rect(Rect2(5, -4, 3, 4), COLOR_STRIPE)                  # front leg
	draw_rect(Rect2(-9, -11, 18, 8), COLOR_COAT)                 # body
	draw_rect(Rect2(-3, -11, 2, 8), COLOR_STRIPE)                # brindle stripes
	draw_rect(Rect2(2, -11, 2, 8), COLOR_STRIPE)
	draw_rect(Rect2(dir_x * 8 - 3, -16, 7, 7), COLOR_COAT)       # head
	draw_rect(Rect2(dir_x * 8 - 2, -19, 2, 3), COLOR_STRIPE)     # ear up
	draw_rect(Rect2(dir_x * 8 + 2, -17, 3, 3), COLOR_STRIPE)     # floppy notched ear
	draw_rect(Rect2(dir_x * 6 - 1, -9, 2, 2), COLOR_TAG)         # shelter tag
	draw_rect(Rect2(-dir_x * 10 - 1, -13, 2, 4), COLOR_COAT)     # tail
