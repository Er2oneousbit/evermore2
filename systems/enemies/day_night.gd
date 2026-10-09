# =============================================================================
# day_night.gd  -  The day/night enemy swap: who is out, and how they come and go
# -----------------------------------------------------------------------------
# WHAT:  A realm whose enemies follow the clock (AsciiRealm ENEMY_CLOCK
#        "follow_clock", or a spawner's own "clock") gets one of these. It owns
#        those enemies' spawn points ("spawners") and keeps the right ones out
#        for the time of day (EnemyData.active: always / day / night; morning
#        and golden hour count as day):
#          - dusk: day enemies stop respawning; idle ones go to the nearest
#            exit (a burrow, the map edge, ...) and are removed only once the
#            camera can't see them (or after sinking into a hole in plain view,
#            which is a visible reason). Ones in combat (aggro'd or hit lately)
#            stay until killed or calm. Bats, which hang in their oaks by day,
#            drop out of the trees and fly.
#          - dawn: the reverse. Bats fly back and hang up; day enemies come
#            back out of their holes.
#          - night enemies are brought in with their own entrance
#            (EnemyData.arrives_by): "offscreen" waits until the spawn point is
#            out of view; burrow / drop / rise / fade play a visible entrance
#            with a sound cue (EnemyData.sound_cue) a second before.
#        Everything is staggered: the swap is spread over the clock's fade plus
#        a few seconds, one at a time (MIN_GAP apart), and night enemies wait
#        until it is getting dark (DARK_DELAY). All timing is game time (the
#        director's own process delta), never the wall clock.
#
# WHY:   Enemies popping in or out in plain view looks cheap; this makes every
#        change of shift happen behind a reason (a hole, a tree, the edge of
#        the screen).
#
# HOW:   AsciiRealm calls register() per follow_clock spawner (a char of
#        ENEMIES_BY_CHAR or an ENEMY_ROOSTS entry) and add_exit() per
#        ENEMY_EXITS entry; populate() then fills the realm for the current
#        phase without ceremony (loading a scene is not a "swap"). After that
#        Clock.phase_changed queues staggered jobs (cue, then leave / arrive /
#        drop / recall) and _reconcile() (4x a second) retires leavers, nudges
#        stuck ones to another exit and starts leaves that were postponed by
#        combat. `enabled = false` freezes it (tests that want a fixed cast).
#        The logs (removal_log, arrival_log) let tests prove nothing was
#        removed on camera.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DayNightDirector
extends Node

## The swap is spread over this long (the clock's fade plus a few seconds).
const STAGGER_SECONDS := Clock.FADE_SECONDS + 4.0
## Never two changes closer than this (so never "all on one frame").
const MIN_GAP := 0.7
## Night enemies wait this long after dusk begins: it has to be getting dark.
const DARK_DELAY := 3.0
## Day enemies start coming back this long after dawn begins.
const DAWN_DELAY := 1.5
## The cue plays this long before the visible entrance.
const CUE_LEAD := 1.0
## An enemy counts as on camera until it is this far outside the view (px).
const VIEW_MARGIN := 96.0
## How high up (px) an enemy's head is when checking the view.
const HEAD_PX := 48.0
const RECONCILE_SECONDS := 0.25
const RETRY_SECONDS := 1.0
## Wait this long for an off-screen spawn point before using a visible entrance.
const OFFSCREEN_TIMEOUT := 15.0
## How far an "edge" exit lets the enemy keep walking past its cell (px).
const EDGE_RUN_PX := 220.0

## Off = it does nothing (tests that need a fixed cast).
var enabled := true
## Where enemies are added (the realm's World node), set by the realm.
var world: Node
## Every spawn point: {id, data, home, roost, enemy, release_leave, wait_since, tried, pending}.
var spawners: Array = []
## Exits: {pos, kind ("burrow"/"edge"), out}.
var exits: Array = []
## For tests: every removal {name, on_camera, via ("hole"/"fade"/"off_camera")},
## every visible entrance {name, t, how, on_camera}, every leave {name, t, kind}.
var removal_log: Array = []
var arrival_log: Array = []
var leave_log: Array = []
## Every cue played: [sound, time].
var cue_log: Array = []

var _now := 0.0
var _jobs: Array = []  # {t, kind, s}
var _reconcile_t := 0.0
var _populated := false


func _ready() -> void:
	add_to_group("day_night_director")
	Clock.phase_changed.connect(_on_phase_changed)


## One spawn point. `spec`: id, data (EnemyData), home (Vector2), roost (bool).
func register(spec: Dictionary) -> void:
	var s := {"id": spec["id"], "data": spec["data"], "home": spec["home"], "roost": spec.get("roost", false),
			"enemy": null, "release_leave": false, "wait_since": -1.0, "tried": [], "pending": false, "serial": 0}
	spawners.append(s)
	if s["data"].leaves_by == "burrow" and not s["roost"]:
		add_exit(s["home"], "burrow")  # the hole it came from
	if not _populated:
		_populated = true
		populate.call_deferred()


func add_exit(pos: Vector2, kind: String, out := Vector2.ZERO) -> void:
	exits.append({"pos": pos, "kind": kind, "out": out})


## Fill the realm for the current phase, no ceremony (a scene load).
func populate() -> void:
	for s: Dictionary in spawners:
		if s["enemy"] != null:
			continue
		if _is_out(s):
			_make(s)
		elif s["roost"]:
			var e := _make(s)
			if e:
				e.start_roosting()


# -----------------------------------------------------------------------------
# What should be out right now
# -----------------------------------------------------------------------------
## Is this spawner's enemy supposed to be out (up and about) at this time?
func _is_out(s: Dictionary) -> bool:
	match String(s["data"].active):
		"day":
			return not Clock.is_night()
		"night":
			return Clock.is_night()
	return true


func _alive(s: Dictionary) -> bool:
	return is_instance_valid(s["enemy"]) and s["enemy"].state != Enemy.State.DEAD


func _make(s: Dictionary) -> Enemy:
	if world == null:
		return null
	var e := Enemy.create(s["data"], s["home"])
	e.clock_rule = "follow_clock"
	s["serial"] += 1
	e.name = "%s_%d_%d" % [String(s["id"]).capitalize(), spawners.find(s), s["serial"]]
	world.add_child(e)
	s["enemy"] = e
	s["release_leave"] = false
	s["tried"] = []
	s["pending"] = false
	e.died.connect(func(dead: Enemy) -> void: _on_died(s, dead))
	var hd := get_tree().get_first_node_in_group("hd_view") as HdView
	if hd:
		hd.mirror_new_actors()
	return e


func _on_died(s: Dictionary, dead: Enemy) -> void:
	if s["enemy"] != dead:
		return
	s["enemy"] = null
	var d: EnemyData = s["data"]
	if d.respawn_seconds > 0.0 and not s["roost"] and _is_out(s):
		s["pending"] = true
		_queue_arrival(s, _now + d.respawn_seconds)


# -----------------------------------------------------------------------------
# Is a world point in the camera's view? (either view, margin included)
# -----------------------------------------------------------------------------
func on_camera(p: Vector2) -> bool:
	var rect := get_viewport().get_visible_rect().grow(VIEW_MARGIN)
	if rect.has_point(Fx.world_to_screen(p, 0.0)):
		return true
	return rect.has_point(Fx.world_to_screen(p, HEAD_PX))


func _enemy_on_camera(e: Enemy) -> bool:
	return on_camera(e.global_position)


# -----------------------------------------------------------------------------
# The clock changed: queue a staggered swap
# -----------------------------------------------------------------------------
func _on_phase_changed(_phase: String, _blend: float) -> void:
	if not enabled:
		return
	# A new phase replaces plans the last one made.
	_jobs.clear()
	var leaving: Array = []
	var arriving: Array = []
	var waking: Array = []
	for s: Dictionary in spawners:
		s["pending"] = false
		var present := _alive(s)
		var out := _is_out(s)
		var e: Enemy = s["enemy"] if present else null
		if out:
			s["release_leave"] = false
			if present and e.is_leaving():
				e.cancel_leave()  # it hadn't gotten away: time came back
			if s["roost"]:
				if present and e.state == Enemy.State.ROOST:
					waking.append(s)
				elif not present:
					arriving.append(s)
			elif not present:
				arriving.append(s)
		elif present and not (s["roost"] and e.state == Enemy.State.ROOST):
			leaving.append(s)  # (a bat already hanging in its tree has nowhere to go)
	_queue_group(leaving, "leave", 0.3, false)
	_queue_group(waking, "drop", DARK_DELAY, true)
	_queue_group(arriving, "arrive", DARK_DELAY if Clock.is_night() else DAWN_DELAY, true)


## Spread `group` over STAGGER_SECONDS from `start`, MIN_GAP apart at least,
## in a shuffled but repeatable order. `cue`: queue the warning sound too.
func _queue_group(group: Array, kind: String, start: float, cue: bool) -> void:
	if group.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s%d" % [kind, Clock.phase_count])
	var order := group.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var step := maxf(MIN_GAP, STAGGER_SECONDS / float(order.size()))
	# The jitter must not eat the MIN_GAP: with many enemies (the big arena has
	# 14 rats) step is MIN_GAP itself and 30% jitter made some pairs 0.5 s apart.
	for i in order.size():
		var s: Dictionary = order[i]
		var at := _now + maxf(start, CUE_LEAD + 0.1 if cue else 0.0) + float(i) * step + rng.randf_range(0.0, minf(step * 0.3, step - MIN_GAP))
		if kind == "arrive":
			s["pending"] = true
			_queue_arrival(s, at)
		else:
			if cue and _wants_cue(s):
				_jobs.append({"t": at - CUE_LEAD, "kind": "cue", "s": s})
			_jobs.append({"t": at, "kind": kind, "s": s})


func _queue_arrival(s: Dictionary, at: float) -> void:
	if _wants_cue(s):
		_jobs.append({"t": at - CUE_LEAD, "kind": "cue", "s": s})
	_jobs.append({"t": at, "kind": "arrive", "s": s})


## Visible entrances get a sound cue first; arrivals from off-screen do not.
func _wants_cue(s: Dictionary) -> bool:
	var d: EnemyData = s["data"]
	return d.sound_cue != "" and (d.arrives_by != "offscreen" or s["roost"])


# -----------------------------------------------------------------------------
# Running the jobs
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not enabled:
		return
	_now += delta
	var due: Array = []
	for j: Dictionary in _jobs:
		if j["t"] <= _now:
			due.append(j)
	for j: Dictionary in due:
		_jobs.erase(j)
		_run_job(j)
	_reconcile_t -= delta
	if _reconcile_t <= 0.0:
		_reconcile_t = RECONCILE_SECONDS
		_reconcile()


func _run_job(j: Dictionary) -> void:
	var s: Dictionary = j["s"]
	match j["kind"]:
		"cue":
			cue_log.append([s["data"].sound_cue, _now])
			if _alive(s):
				(s["enemy"] as Enemy).play_cue()
			elif s["data"].sound_cue != "":
				Audio.play_at(s["data"].sound_cue, s["home"])
		"leave":
			s["release_leave"] = true
			if _alive(s) and not (s["enemy"] as Enemy).in_combat() and not (s["enemy"] as Enemy).is_leaving():
				_start_leave(s)
		"drop":
			if _alive(s) and (s["enemy"] as Enemy).state == Enemy.State.ROOST:
				(s["enemy"] as Enemy).drop_from_roost()
				_log_arrival(s["enemy"], "drop")
		"arrive":
			_try_arrive(s)


func _try_arrive(s: Dictionary) -> void:
	if _alive(s) or not _is_out(s):
		s["pending"] = false
		return
	var d: EnemyData = s["data"]
	var how: String = "drop" if s["roost"] else d.arrives_by
	# "offscreen" types, and a killed bat coming back out of its tree, only
	# appear while their spawn point is out of view.
	var hidden_spawn: bool = (how == "offscreen" or s["roost"]) and not s.get("forced", false)
	if hidden_spawn and on_camera(s["home"]):
		if s["wait_since"] < 0.0:
			s["wait_since"] = _now
		if _now - float(s["wait_since"]) < OFFSCREEN_TIMEOUT:
			_jobs.append({"t": _now + RETRY_SECONDS, "kind": "arrive", "s": s})
			return
		s["wait_since"] = -1.0
		if s["roost"]:
			s["pending"] = false
			return  # no bat appears in plain view; the next dusk will do
		# Waited long enough: a visible entrance from the hole instead, with
		# its cue a second ahead.
		s["forced"] = true
		Audio.play_at(d.sound_cue if d.sound_cue != "" else "rustle", s["home"])
		_jobs.append({"t": _now + CUE_LEAD, "kind": "arrive", "s": s})
		return
	if s.get("forced", false):
		how = "burrow"
	s["forced"] = false
	s["wait_since"] = -1.0
	var e := _make(s)
	if e == null:
		return
	if how != "offscreen":
		e.begin_entrance(how)
		_log_arrival(e, how)


func _log_arrival(e: Enemy, how: String) -> void:
	arrival_log.append({"name": e.name, "t": _now, "how": how, "on_camera": _enemy_on_camera(e)})


# -----------------------------------------------------------------------------
# Leaving
# -----------------------------------------------------------------------------
func _start_leave(s: Dictionary) -> void:
	var e: Enemy = s["enemy"]
	var d: EnemyData = s["data"]
	var kind: String = d.leaves_by
	if s["roost"] and (not _is_out(s)):
		kind = "roost"
	var point := e.global_position
	match kind:
		"roost":
			point = s["home"]
		"fade":
			pass
		_:
			var ex := _pick_exit(s, e, kind)
			if ex.is_empty():
				# No exit known: walk straight away from the camera's middle.
				var from := get_viewport().get_canvas_transform().affine_inverse() * (get_viewport().get_visible_rect().size * 0.5)
				point = e.global_position + (e.global_position - from).normalized() * 500.0
				kind = "edge"
			else:
				point = ex["pos"] + (ex["out"] * EDGE_RUN_PX if ex["kind"] == "edge" else Vector2.ZERO)
				kind = ex["kind"]
	leave_log.append({"name": e.name, "t": _now, "kind": kind})
	e.begin_leave(kind, point)


func _pick_exit(s: Dictionary, e: Enemy, kind: String) -> Dictionary:
	var best := {}
	var best_d := INF
	for pass_kind in [kind, ""]:
		for i in exits.size():
			var ex: Dictionary = exits[i]
			if s["tried"].has(i) or (pass_kind != "" and ex["kind"] != pass_kind):
				continue
			var dist := e.global_position.distance_to(ex["pos"])
			if dist < best_d:
				best_d = dist
				best = ex.duplicate()
				best["index"] = i
		if not best.is_empty():
			break
	if not best.is_empty():
		s["tried"].append(best["index"])
	return best


# -----------------------------------------------------------------------------
# Every quarter second: retire leavers, retry postponed leaves
# -----------------------------------------------------------------------------
func _reconcile() -> void:
	for s: Dictionary in spawners:
		if not _alive(s):
			continue
		var e: Enemy = s["enemy"]
		if e.is_leaving():
			_check_leaver(s, e)
		elif s["release_leave"] and not e.in_combat() and e.state in [Enemy.State.IDLE, Enemy.State.RETURN]:
			_start_leave(s)


func _check_leaver(s: Dictionary, e: Enemy) -> void:
	if e.leave_kind == "roost":
		return  # it hangs up in its tree: nobody is removed
	if e.leave_done:
		_remove(s, e, "fade" if e.leave_kind == "fade" else "hole")
	elif not _enemy_on_camera(e):
		_remove(s, e, "off_camera")
	elif e.leave_failed:
		if s["tried"].size() >= exits.size() or s["tried"].size() >= 3:
			e.cancel_leave()
			s["release_leave"] = false  # stays on, no way out; the next phase retries
		else:
			_start_leave(s)


func _remove(s: Dictionary, e: Enemy, via: String) -> void:
	removal_log.append({"name": e.name, "on_camera": _enemy_on_camera(e), "via": via, "t": _now})
	s["enemy"] = null
	s["release_leave"] = false
	e.queue_free()
