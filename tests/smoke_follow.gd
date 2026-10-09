# =============================================================================
# smoke_follow.gd  -  Automated smoke test: does the dog keep up?
# -----------------------------------------------------------------------------
# WHAT:  Loads the prototype yard, "autopilots" the kid through the fenced
#        maze by simulating stick input, and checks the dog:
#          1. never needed the safety-net warp (follow logic worked)
#          2. never fell farther behind than MAX_ALLOWED_GAP
#          3. ends up IDLE next to the kid once the kid stops
#        Then exercises the stay command, time of day, and flashlight.
#
# RUN (headless, prints PASS/FAIL, exit code 0 = pass, 1 = fail):
#   godot --headless --path . --fixed-fps 60 res://tests/smoke_follow.tscn
#
# SCREENSHOTS (needs a real display or Xvfb, not --headless):
#   EVERMORE_SHOT_DIR=/some/folder godot --path . --fixed-fps 60 res://tests/smoke_follow.tscn
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const YARD_SCENE := preload("res://realms/big_yard/prototype_yard.tscn")
const YardScript := preload("res://realms/big_yard/prototype_yard.gd")
const TILE := YardScript.TILE

## Tile coordinates the kid walks through, in order. The kid spawns at (3,5)
## with the dog sitting just down-right at (4,6). The first two legs dip
## below the dog and then head east past it: the crumbs nearest the dog are
## BEHIND it, which is exactly what made the old follow AI walk backward
## (string pulling fixes it; the backtrack check below proves it). Then the
## route goes through the fenced pen: in at the top gap, around the stub wall,
## through the inner wall's gap, out the side exit, so the dog has to follow
## every corner. (Pen layout: rows 10-22, cols 0-18 of LAYOUT.)
const ROUTE: Array[Vector2i] = [
	Vector2i(3, 7), Vector2i(8, 7), Vector2i(7, 9), Vector2i(7, 12), Vector2i(7, 14),
	Vector2i(16, 14), Vector2i(16, 18), Vector2i(22, 18), Vector2i(22, 16),
	Vector2i(24, 16),
]
## Where the kid walks while the dog is told to stay.
const STAY_WALK_TO := Vector2i(28, 18)
## Dog may lag behind while sprinting, but never more than this (px).
const MAX_ALLOWED_GAP := 200.0
## Give up on a waypoint after this many seconds (kid stuck = test bug).
const WAYPOINT_TIMEOUT := 8.0
## Max dog state changes allowed while the kid walks the route nonstop. A dog
## that flip-flops IDLE/FOLLOW stutter-steps on screen; this catches that.
const MAX_ROUTE_STATE_CHANGES := 12

var _yard: Node2D
var _kid: Kid
var _dog: Dog
var _failures: PackedStringArray = []
var _max_gap := 0.0
var _state_changes := 0
var _dog_min_x_seen := INF  # smallest dog x seen inside _walk_to (backtrack check)
var _shot_dir := OS.get_environment("EVERMORE_SHOT_DIR")


func _ready() -> void:
	_yard = YARD_SCENE.instantiate()
	add_child(_yard)
	_kid = _yard.get_node("World/Kid")
	_dog = _yard.get_node("World/Dog")
	Debug.set_overlay_visible(true)
	EventBus.dog_state_changed.connect(func(_s: String) -> void: _state_changes += 1)
	_run.call_deferred()


func _run() -> void:
	await _wait(0.5)
	await _shot("01_start_golden_hour")

	# --- 1. Walk the maze route --------------------------------------------
	# The route starts by walking the kid PAST the idle dog (kid spawns left
	# of the dog, first waypoint is to the right). A dog that backtracks to
	# stale crumbs would walk left first; it should only ever move right here.
	var dog_start_x := _dog.global_position.x
	var dog_min_x := dog_start_x
	_max_gap = 0.0
	_state_changes = 0
	for i in ROUTE.size():
		await _walk_to(ROUTE[i])
		if i <= 1:
			dog_min_x = minf(dog_min_x, _dog_min_x_seen)
		if i == 4:
			await _shot("02_maze_breadcrumbs")
	var route_changes := _state_changes
	var route_gap := _max_gap
	_release_all()
	await _wait(2.0)
	_check(dog_min_x >= dog_start_x - 6.0, "dog backtracked %.1f px left at the start (stale crumbs)" % (dog_start_x - dog_min_x))
	_check(route_changes <= MAX_ROUTE_STATE_CHANGES, "dog changed state %d times while kid walked (stutter? max %d)" % [route_changes, MAX_ROUTE_STATE_CHANGES])
	_check(_dog.state == Dog.State.IDLE, "dog should be IDLE after kid stops (was %s)" % _dog.get_state_name())
	_check(_dist() <= _dog.follow_distance + 10.0, "dog should end next to kid (dist %.1f)" % _dist())
	_check(_dog.warp_count == 0, "dog needed %d safety warps during the route" % _dog.warp_count)
	_check(route_gap <= MAX_ALLOWED_GAP, "dog fell %.1f px behind (max %.1f)" % [route_gap, MAX_ALLOWED_GAP])

	# --- 2. Stay command ------------------------------------------------------
	_tap("partner_stay")
	await _wait(0.1)
	var stay_pos := _dog.global_position
	await _walk_to(STAY_WALK_TO)
	_release_all()
	await _wait(0.3)
	_check(_dog.state == Dog.State.STAY, "dog should be in STAY")
	_check(_dog.global_position.distance_to(stay_pos) < 2.0, "dog moved while told to stay")
	_tap("partner_stay")
	await _wait(3.0)
	_check(_dist() <= _dog.follow_distance + 10.0, "dog should rejoin kid after stay (dist %.1f)" % _dist())

	# --- 3. Night + flashlight -----------------------------------------------
	_tap("debug_cycle_time")  # golden -> night
	await _wait(1.0)
	await _shot("03_night_flashlight_on")
	var light_before := _kid.light_on
	_tap("toggle_light")
	await _wait(0.2)
	_check(_kid.light_on != light_before, "flashlight toggle did nothing")
	await _shot("04_night_flashlight_off")

	# --- 4. How the kid moves (owner's playtest, 2026-10-09) -------------------
	await _test_kid_feel()

	# --- Report ---------------------------------------------------------------
	if _failures.is_empty():
		print("[TEST] PASS  smoke_follow  (route: max gap %.1f px, %d state changes, %d warps)"
				% [route_gap, route_changes, _dog.warp_count])
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
# The kid's movement: +10% speed, steady facing, smooth reversals
# -----------------------------------------------------------------------------
func _test_kid_feel() -> void:
	# +10% on every speed (walk 85, run 140, follow walk 120, follow sprint 165).
	_check(is_equal_approx(_kid.move_speed, 93.5) and is_equal_approx(_kid.run_speed, 154.0),
			"kid walk/run are 93.5 / 154 (+10%%), got %s / %s" % [_kid.move_speed, _kid.run_speed])
	_check(is_equal_approx(_kid.walk_speed, 132.0) and is_equal_approx(_kid.sprint_speed, 181.5),
			"kid follow speeds are 132 / 181.5 (+10%%), got %s / %s" % [_kid.walk_speed, _kid.sprint_speed])
	_check(_dog.sprint_speed > _kid.run_speed and _dog.sprint_speed > _kid.sprint_speed,
			"the dog's sprint (%.0f) still beats the kid's run (%.0f)" % [_dog.sprint_speed, _kid.run_speed])
	var sprite: LpcSprite = _kid.get_node("Sprite")
	# Out in the open, nobody else about.
	_kid.global_position = Vector2(3 * TILE + 16, 5 * TILE + 16)
	_kid.velocity = Vector2.ZERO
	_dog.global_position = _kid.global_position + Vector2(-60, 0)
	await _wait(0.3)
	_release_all()

	# A diagonal held with a wobbling thumb must not flicker between
	# right and down (measured before the fix: it changed every frame).
	var flips := 0
	var last := sprite.dir
	for i in 60:
		var wobble := 0.1 if i % 2 == 0 else -0.1
		Input.action_press("move_right", 0.8)
		Input.action_press("move_down", 0.8 + wobble)
		await get_tree().physics_frame
		if sprite.dir != last:
			flips += 1
			last = sprite.dir
	_release_all()
	_check(flips <= 1, "facing doesn't flicker on a wobbling diagonal (%d changes in 60 frames)" % flips)
	await _wait(0.5)

	# A 180-degree reversal brakes over a few frames; it never snaps.
	_kid.global_position = Vector2(8 * TILE + 16, 5 * TILE + 16)
	_kid.velocity = Vector2.ZERO
	Input.action_press("move_right", 1.0)
	await _wait(0.5)
	var top := _kid.velocity.x
	_check(absf(top - _kid.move_speed) < 4.0, "walking right at his walk speed (%.1f)" % top)
	Input.action_release("move_right")
	Input.action_press("move_left", 1.0)
	var vx: Array[float] = []
	for i in 30:
		await get_tree().physics_frame
		vx.append(_kid.velocity.x)
	_release_all()
	var zero_at := -1
	for i in vx.size():
		if vx[i] <= 0.0:
			zero_at = i
			break
	_check(vx[0] > top * 0.6, "the first frame of a reversal keeps most of his speed (%.1f of %.1f)" % [vx[0], top])
	_check(zero_at >= 3, "a reversal takes at least 3 frames to cross zero (took %d)" % zero_at)
	_check(zero_at != -1 and zero_at <= 14, "...but is still quick (%d frames)" % zero_at)
	var steady := true
	for i in range(1, maxi(zero_at, 1)):
		steady = steady and vx[i] < vx[i - 1]
	_check(steady, "and the speed falls every frame (no jump back up)")
	_check(vx[vx.size() - 1] < -top * 0.9, "then he's up to speed the other way (%.1f)" % vx[vx.size() - 1])
	_kid.velocity = Vector2.ZERO

	# Walk <-> run keeps the stride (no jump back to the first frame).
	_kid.set_physics_process(false)  # or his own code puts idle back each frame
	sprite.play(&"walk", Vector2.RIGHT, true)
	for i in 21:
		await get_tree().physics_frame
	var before := sprite.frame_index()
	sprite.play(&"run", Vector2.RIGHT)
	_check(before > 0 and sprite.frame_index() == before, "walk to run keeps the frame (%d then %d)" % [before, sprite.frame_index()])
	sprite.play(&"idle", Vector2.RIGHT)
	_kid.set_physics_process(true)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
## Steer the kid toward a tile center using simulated analog stick input.
func _walk_to(tile: Vector2i) -> void:
	var target := Vector2(tile.x * TILE + TILE * 0.5, tile.y * TILE + TILE * 0.5)
	var elapsed := 0.0
	while _kid.global_position.distance_to(target) > 4.0:
		var dir := _kid.global_position.direction_to(target)
		_press_axis("move_right", "move_left", dir.x)
		_press_axis("move_down", "move_up", dir.y)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		_max_gap = maxf(_max_gap, _dist())
		_dog_min_x_seen = minf(_dog_min_x_seen, _dog.global_position.x)
		if elapsed > WAYPOINT_TIMEOUT:
			_check(false, "kid got stuck heading to tile %s (at %s)" % [tile, _kid.global_position])
			return


func _press_axis(positive: String, negative: String, value: float) -> void:
	if value > 0.01:
		Input.action_press(positive, value)
		Input.action_release(negative)
	elif value < -0.01:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


## Simulate a single button press so _unhandled_input handlers fire.
func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _wait(seconds: float) -> void:
	var frames := ceili(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await get_tree().physics_frame
		_max_gap = maxf(_max_gap, _dist())


func _dist() -> float:
	return _dog.global_position.distance_to(_kid.global_position)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Save a screenshot if EVERMORE_SHOT_DIR is set and we're actually rendering.
func _shot(shot_name: String) -> void:
	if _shot_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _shot_dir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	if err != OK:
		Debug.log_warn("Screenshot failed (%s): %s" % [error_string(err), path])
	else:
		print("[TEST] screenshot -> ", path)
