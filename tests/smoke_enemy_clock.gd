# =============================================================================
# smoke_enemy_clock.gd  -  Headless checks for the day/night enemy swap
# -----------------------------------------------------------------------------
# WHAT:  In the combat arena (rats = day, burrow in/out; skeletons + bats =
#        night; the yard has no enemies any more), with the clock pinned by hand:
#          1. by day: every "x" rat out, no skeleton, every roost holds a bat up
#             in the leaves (NOT DRAWN, not hittable, no aggro); a killed rat
#             respawns through its burrow entrance
#          2. dusk (jump to night): an idle rat on camera walks to a hole and
#             is removed only once invisible (sunk) or off camera, never
#             visibly popped; a rat that is fighting the kid stays; a kill at
#             night does NOT respawn; the skeletons RISE out of the ground
#             staggered (the rise animation, a dirt cue ahead, never popping);
#             the bats fly out of the canopy staggered (a wing-flap cue ahead)
#          3. dawn: the skeletons SINK back into the ground (staggered, the
#             sink animation, removed only once down), the bats fly back into
#             the leaves and vanish (nobody removed), the rats come back
#             through their burrows, staggered
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_enemy_clock.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const YARD := "res://realms/test/combat_arena.tscn"
var RAT: EnemyData = load("res://data/enemies/rat.tres")

var _failures: PackedStringArray = []
var _yard: Node2D
var _kid: Kid
var _dog: Dog
var _dn: DayNightDirector
var _n_rats := 0  # "x" cells in the arena layout
var _n_bats := 0  # ENEMY_ROOSTS entries
var _n_skel := 0  # "z" cells in the arena layout
var _heard: Array = []  # [sound, director time]


func _ready() -> void:
	Audio.played.connect(func(s: String) -> void:
		if _dn:
			_heard.append([s, _dn._now]))
	_run.call_deferred()


func _run() -> void:
	RAT.respawn_seconds = 6.0  # the real value (45 s) would make the test crawl
	_yard = load(YARD).instantiate()
	add_child(_yard)
	_kid = _yard.get_node("World/Kid")
	_dog = _yard.get_node("World/Dog")
	_dn = _yard.get_node("DayNight")
	_n_rats = "".join(_yard.layout).count("x")
	_n_bats = _yard.cfg("ENEMY_ROOSTS").size()
	_n_skel = "".join(_yard.layout).count("z")
	await _frames(5)
	Clock.hold("day", 0.0)  # pinned: the clock moves only when the test says
	await _frames(5)
	_dog.set_physics_process(false)
	_kid.health.max_hp = 9999
	_kid.health.hp = 9999
	await _test_by_day()
	await _test_dusk()
	await _test_dawn()
	if _failures.is_empty():
		print("[TEST] PASS  smoke_enemy_clock  ", _dn.removal_log.map(func(r: Dictionary) -> String: return "%s:%s%s" % [r["name"], r["via"], "(on cam)" if r["on_camera"] else ""]), " arrivals ", _dn.arrival_log.size())
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _rats() -> Array:
	return _spawner_enemies("rat")


func _skels() -> Array:
	return _spawner_enemies("skeleton")


func _bats() -> Array:
	return _spawner_enemies("bat")


func _spawner_enemies(id: String) -> Array:
	var out: Array = []
	for s: Dictionary in _dn.spawners:
		if s["id"] == id and is_instance_valid(s["enemy"]):
			out.append(s["enemy"])
	return out


func _put_kid(at: Vector2) -> void:
	_kid.global_position = at
	_dog.global_position = at + Vector2(0, 12)
	_kid.velocity = Vector2.ZERO


func _test_by_day() -> void:
	# The arena is big (the owner plays at 3440x1440: ~27x11 tiles visible) and
	# holds the whole demo: day rats with burrows, night skeletons, oak roosts.
	var layout: Array = _yard.layout
	_check(layout[0].length() >= 90 and layout.size() >= 50, "the arena is at least 90x50 tiles (%dx%d)" % [layout[0].length(), layout.size()])
	_check("".join(layout).count("r") == 0, "no rat is always out any more: rats are the day enemies")
	_check(_n_skel >= _n_rats - 2 and _n_skel <= _n_rats + 2, "about as many skeleton spawn points (%d) as rats (%d)" % [_n_skel, _n_rats])
	_check(_skels().is_empty(), "no skeleton walks by day (%d out)" % _skels().size())
	for r: Dictionary in _yard.cfg("ENEMY_ROOSTS"):
		var c: Vector2i = r["cell"]
		_check(layout[c.y][c.x] in "Tt", "the roost at %s is in an oak" % c)
	var far := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if (e as Enemy).global_position.distance_to(_kid.global_position) > 640.0:
			far += 1
	_check(far >= 20, "most enemies start far from the kid so they wake as he approaches (%d far)" % far)
	_check(_n_rats >= 10 and _rats().size() == _n_rats, "%d rats out by day, found %d" % [_n_rats, _rats().size()])
	var bats := _bats()
	_check(_n_bats >= 6 and bats.size() == _n_bats, "%d bats in the oaks, found %d" % [_n_bats, bats.size()])
	for b: Enemy in bats:
		_check(b.state == Enemy.State.ROOST, "%s is up in the leaves by day (state %d)" % [b.name, b.state])
		_check(not (b.get_node("Sprite") as Node2D).visible, "%s is not drawn by day (no bat hangs in plain view)" % b.name)
		_check(b.height >= b.data.hang_height - 0.5, "%s hangs under the canopy (height %.1f)" % [b.name, b.height])
		_check(not b.get_node("Hurtbox").is_in_group("hurtbox"), "a hanging bat can't be hit")
	_check(_dn.leave_log.filter(func(l: Dictionary) -> bool: return String(l["name"]).begins_with("Bat")).is_empty(),
			"day coming (golden to day) never recalls bats that already hang")
	# A bat hanging above the kid doesn't wake.
	_put_kid(bats[0].global_position + Vector2(0, 30))
	await _wait(1.0)
	_check(bats[0].state == Enemy.State.ROOST, "a roosting bat ignores the kid beneath it")
	_check(not bats[0].is_active(), "the AI partner never picks a hanging bat as a target")

	# A killed rat comes back through its burrow while the day lasts.
	var rats := _rats()
	var victim: Enemy = rats[0]
	_put_kid(victim.global_position + Vector2(-230, 0))
	await _wait(0.5)
	var before := _dn.arrival_log.size()
	victim.get_node("Hurtbox").receive(HitInfo.make(999.0, _kid.global_position, victim.global_position, 0.0, "player", _kid))
	await _wait(1.0)
	_check(_rats().size() == _n_rats - 1, "the killed rat is gone for now")
	await _wait(RAT.respawn_seconds + 2.5)
	_check(_rats().size() == _n_rats, "by day a killed rat respawns (%d rats)" % _rats().size())
	var burrows := _dn.arrival_log.slice(before).filter(func(a: Dictionary) -> bool: return a["how"] == "burrow")
	_check(burrows.size() == 1, "...squeezing out of its burrow (%s)" % [_dn.arrival_log.slice(before)])
	await _wait(1.5)


func _test_dusk() -> void:
	var rats := _rats()
	var idle_rat: Enemy = rats[0]
	var fight_rat: Enemy = rats[1]
	# The kid fights one rat; the other idles in plain view 200 px away. Both
	# are brought to the open plaza by the entrance road, next to two burrows:
	# rats walk straight at their hole, and a fence in between would (rightly)
	# make the leave fail, which is not what this checks.
	fight_rat.global_position = Vector2(1750, 1540)
	fight_rat.home = fight_rat.global_position
	_put_kid(fight_rat.global_position + Vector2(-100, 0))
	idle_rat.global_position = _kid.global_position + Vector2(-210, 10)
	idle_rat.home = idle_rat.global_position
	await _wait(0.5)
	_check(fight_rat.in_combat(), "one rat is fighting the kid before dusk")
	_check(not idle_rat.in_combat() and _dn.on_camera(idle_rat.global_position), "the other is idle and on camera")
	var removals_before := _dn.removal_log.size()
	var arrivals_before := _dn.arrival_log.size()
	_heard.clear()
	var t_dusk := _dn._now
	Clock.jump("night", 0.0)
	var bat_names: Array = _bats().map(func(b: Enemy) -> String: return b.name)
	var left_early := false
	var saw_leave := false
	var min_bats_flying := 99
	var fight_gone := false
	var rising := {}  # skeleton name -> seen playing "rise" while entering
	var bats_seen_visible := {}
	for i in 60 * 40:
		await get_tree().physics_frame
		for sk: Enemy in _skels():
			if sk.state == Enemy.State.ENTER and sk._sprite.current == &"rise":
				rising[sk.name] = true
				_check(not sk.get_node("Hurtbox").is_in_group("hurtbox"), "a rising skeleton can't be hit yet")
		for bt: Enemy in _bats():
			if bt.state == Enemy.State.ENTER and (bt.get_node("Sprite") as Node2D).visible:
				bats_seen_visible[bt.name] = true
		saw_leave = saw_leave or (is_instance_valid(idle_rat) and idle_rat.state == Enemy.State.LEAVE)
		if not is_instance_valid(fight_rat):
			fight_gone = true
		if is_instance_valid(idle_rat) and idle_rat.state == Enemy.State.LEAVE and idle_rat.leave_kind != "burrow":
			left_early = true
		if not is_instance_valid(idle_rat) and _bats().all(func(b: Enemy) -> bool: return b.state != Enemy.State.ENTER):
			if _dn._now - t_dusk > 22.0 and _skels().all(func(k: Enemy) -> bool: return k.state != Enemy.State.ENTER):
				break
	_check(saw_leave, "the idle rat started to leave at dusk")
	_check(not is_instance_valid(idle_rat), "the idle rat is gone by the end of the swap")
	_check(not left_early, "rats leave by burrow")
	var removals := _dn.removal_log.slice(removals_before)
	_check(removals.size() >= 1, "the director logged the idle rat's removal (%d)" % removals.size())
	for r: Dictionary in removals:
		_check(not (r["on_camera"] and r["via"] == "off_camera"), "removed in plain view: %s" % [r])
		_check(r["via"] != "off_camera" or not r["on_camera"], "removal guard: %s" % [r])
	# The fighter stays.
	_check(not fight_gone and is_instance_valid(fight_rat) and fight_rat.in_combat(),
			"a rat in combat stays through dusk (still fighting: %s)" % [is_instance_valid(fight_rat)])
	# No more rats come at night, even after a kill.
	if is_instance_valid(fight_rat):
		fight_rat.get_node("Hurtbox").receive(HitInfo.make(999.0, _kid.global_position, fight_rat.global_position, 0.0, "player", _kid))
	await _wait(RAT.respawn_seconds + 4.0)
	_check(_rats().is_empty(), "no rat respawns at night (%d out)" % _rats().size())

	# The bats: dropped out of the trees one at a time, after dark, with a cue.
	var drops := _dn.arrival_log.slice(arrivals_before).filter(func(a: Dictionary) -> bool: return a["how"] == "drop")
	_check(drops.size() == _n_bats, "all %d bats dropped (%d)" % [_n_bats, drops.size()])
	if drops.size() >= 2:
		var times: Array = drops.map(func(a: Dictionary) -> float: return a["t"])
		times.sort()
		_check(times[0] - t_dusk >= DayNightDirector.DARK_DELAY - 0.01,
				"the first bat waits for the dark (%.1f s)" % (times[0] - t_dusk))
		for i in range(1, times.size()):
			_check(times[i] - times[i - 1] >= DayNightDirector.MIN_GAP - 0.01,
					"bats drop one at a time (gap %.2f s)" % (times[i] - times[i - 1]))
		_check(times[-1] - t_dusk <= DayNightDirector.STAGGER_SECONDS + DayNightDirector.DARK_DELAY + 2.0,
				"the swap is over within the window (%.1f s)" % (times[-1] - t_dusk))
	_check(bats_seen_visible.size() == _n_bats, "every bat showed itself flying out of the canopy (%d of %d)" % [bats_seen_visible.size(), _n_bats])
	var cues := _dn.cue_log.filter(func(h: Array) -> bool: return h[0] == "wing_flap")
	for d: Dictionary in drops:
		var lead := cues.filter(func(h: Array) -> bool: return h[1] <= d["t"] - 0.5 and h[1] >= d["t"] - 1.6)
		_check(not lead.is_empty(), "a wing-flap cue about a second before the drop at %.1f" % d["t"])
	var flying := 0
	for b: Enemy in _bats():
		if b.state in [Enemy.State.IDLE, Enemy.State.CHASE, Enemy.State.WINDUP, Enemy.State.ATTACK, Enemy.State.RECOVER, Enemy.State.HURT]:
			flying += 1
			_check(b.get_node("Hurtbox").is_in_group("hurtbox"), "a flying bat can be hit")
	_check(flying == _n_bats, "%d bats are flying (%d)" % [_n_bats, flying])
	_check(bat_names.size() == _n_bats, "the same bats")
	for b: Enemy in _bats():
		_check((b.get_node("Sprite") as Node2D).visible, "a flying bat is drawn")

	# The skeletons: up out of the ground one at a time, after dark, dirt cue first.
	var rises := _dn.arrival_log.slice(arrivals_before).filter(func(a: Dictionary) -> bool: return a["how"] == "rise")
	_check(rises.size() == _n_skel, "all %d skeletons rose out of the ground (%d)" % [_n_skel, rises.size()])
	_check(_dn.arrival_log.slice(arrivals_before).filter(func(a: Dictionary) -> bool: return a["how"] == "offscreen").is_empty(),
			"nothing pops in: every skeleton arrival is a visible rise")
	_check(rising.size() == _n_skel, "each skeleton was seen playing its rise animation (%d of %d)" % [rising.size(), _n_skel])
	if rises.size() >= 2:
		var rt: Array = rises.map(func(a: Dictionary) -> float: return a["t"])
		rt.sort()
		_check(rt[0] - t_dusk >= DayNightDirector.DARK_DELAY - 0.01, "the first skeleton waits for the dark (%.1f s)" % (rt[0] - t_dusk))
		var tight := 0
		for i in range(1, rt.size()):
			if rt[i] - rt[i - 1] < DayNightDirector.MIN_GAP - 0.01:
				tight += 1
		_check(tight == 0, "skeletons rise one at a time, MIN_GAP apart (%d too close)" % tight)
	var dirt_cues := _dn.cue_log.filter(func(h: Array) -> bool: return h[0] == "grave_dirt")
	for d: Dictionary in rises:
		var lead := dirt_cues.filter(func(h: Array) -> bool: return h[1] <= d["t"] - 0.5 and h[1] >= d["t"] - 1.6)
		_check(not lead.is_empty(), "a dirt cue about a second before the rise at %.1f" % d["t"])
	_check(_skels().size() == _n_skel, "%d skeletons are out at night (%d)" % [_n_skel, _skels().size()])
	for sk: Enemy in _skels():
		_check(sk.state != Enemy.State.ENTER and sk.get_node("Hurtbox").is_in_group("hurtbox"), "%s is up and can be hit" % sk.name)
	min_bats_flying = flying
	if min_bats_flying == 0:
		return


func _test_dawn() -> void:
	var removals_before := _dn.removal_log.size()
	var arrivals_before := _dn.arrival_log.size()
	var t_dawn := _dn._now
	# A bat that is fighting at dawn stays up until it is calm: not tested here;
	# the rat's version above covers the rule. Everyone else goes home.
	# A skeleton still fighting the kid at dawn would (rightly) stay until calm:
	# take him to a quiet corner and let any chase end first.
	_put_kid(Vector2(208, 48))
	await _wait(9.0)
	for sk: Enemy in _skels():
		_check(not sk.in_combat(), "%s has calmed down before dawn" % sk.name)
	var skel_names: Array = _skels().map(func(k: Enemy) -> String: return k.name)
	var sinking := {}
	Clock.jump("morning", 0.0)
	for i in 60 * 40:
		await get_tree().physics_frame
		for sk: Enemy in _skels():
			if sk.state == Enemy.State.LEAVE and sk.leave_kind == "sink" and sk._sprite.current == &"sink":
				sinking[sk.name] = true
	var left := _dn.leave_log.filter(func(l: Dictionary) -> bool: return l["kind"] == "sink")
	_check(skel_names.size() == _n_skel and left.size() == _n_skel, "all %d skeletons sank back into the ground (%d)" % [_n_skel, left.size()])
	_check(sinking.size() == _n_skel, "each was seen playing its sink animation (%d of %d)" % [sinking.size(), _n_skel])
	if left.size() >= 2:
		var lt: Array = left.map(func(l: Dictionary) -> float: return l["t"])
		lt.sort()
		var close := 0
		for i in range(1, lt.size()):
			if lt[i] - lt[i - 1] < DayNightDirector.MIN_GAP - 0.01:
				close += 1
		_check(close == 0, "they sank one at a time (%d too close)" % close)
	var sunk := _dn.removal_log.slice(removals_before).filter(func(r: Dictionary) -> bool: return String(r["name"]).begins_with("Skeleton"))
	_check(sunk.size() == _n_skel and sunk.all(func(r: Dictionary) -> bool: return r["via"] == "hole" or (r["via"] == "off_camera" and not r["on_camera"])),
			"each was removed only after sinking, or out of sight (%d removals: %s)" % [sunk.size(), sunk.map(func(r: Dictionary) -> String: return r["via"])])
	_check(_skels().is_empty(), "no skeleton is left by day (%d)" % _skels().size())
	var bats := _bats()
	_check(bats.size() == _n_bats, "no bat was removed at dawn (%d left)" % bats.size())
	for b: Enemy in bats:
		_check(b.state == Enemy.State.ROOST and not (b.get_node("Sprite") as Node2D).visible,
				"%s is back in the leaves and gone from sight (state %d)" % [b.name, b.state])
	for r: Dictionary in _dn.removal_log.slice(removals_before):
		_check(not (r["on_camera"] and r["via"] == "off_camera"), "removed in plain view at dawn: %s" % [r])
	var back := _dn.arrival_log.slice(arrivals_before).filter(func(a: Dictionary) -> bool: return a["how"] == "burrow")
	_check(back.size() == _n_rats, "all %d rats came back out of their burrows (%d)" % [_n_rats, back.size()])
	if back.size() >= 2:
		var ts: Array = back.map(func(a: Dictionary) -> float: return a["t"])
		ts.sort()
		for i in range(1, ts.size()):
			_check(ts[i] - ts[i - 1] >= DayNightDirector.MIN_GAP - 0.01, "the rats came back one at a time (%.2f s apart)" % (ts[i] - ts[i - 1]))
		_check(ts[0] - t_dawn >= DayNightDirector.DAWN_DELAY - 0.01, "not before the dawn delay")
	_check(_rats().size() == _n_rats, "every rat is out again by day")


# -----------------------------------------------------------------------------
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * 60.0))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
