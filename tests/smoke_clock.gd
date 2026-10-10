# =============================================================================
# smoke_clock.gd  -  Headless checks for the game clock, shops and night rules
# -----------------------------------------------------------------------------
# WHAT:  1. The clock runs on GAME time: morning -> day -> golden -> night ->
#           morning, each change with the long fade; a frame of game time is
#           a frame of clock time; the tree's pause stops it
#        2. hold() freezes it (a jump keeps it held), release() runs it,
#           set_time() jumps and runs on
#        3. Debug keys: F7 pauses and resumes, F9 cycles x1 / x10 / x60
#        4. The test yard runs free and its look FADES when the clock moves on
#           (the HD sun is between the two moods a second in)
#        5. Shops: the corner store is closed at night (keeper gone, shutter
#           down, the shutter says so) and open in the morning; the all-night
#           stand is open at night; each hands over its item once per phase;
#           set_rule() overrides the clock
#           (the yard has no enemies; steps 6 and 7 run in the combat arena,
#           which also runs the clock free)
#        6. Night misses: only at night, only outside the flashlight beam (2D
#           cone and HdView's spotlight), seeded dice; a miss deals nothing,
#           pops "Miss" and whiffs
#        7. The dog's nose: enemies glow (scent 1, 2D glow, HD shader) only at
#           night while you drive the dog
#        9. Game hours: 1 real minute = 1 game hour, phases start at 5, 11, 17
#           and 20 (6, 6, 3 and 9 hours), Clock.hour() runs 0-24
#        10. The HUD sky dial (ui/hud/sky_dial.gd, in a HUD of its own at
#           16:9 and 21:9 view sizes): the sun is at the top at noon and the
#           moon at midnight, a tick every 3 hours, hold/F7/F9 badges, no time
#           text or setting, hotbar bottom
#           centre, dial top centre, nothing overlaps
#        8. The prologue holds the clock (golden), and its @time night moves
#           it without releasing it
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_clock.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const YARD_HD := "res://realms/big_yard/yard_hd.tscn"
const ARENA_HD := "res://realms/test/combat_arena_hd.tscn"
const LOT := "res://realms/podunk/ruffleberg_lot.tscn"

var _failures: PackedStringArray = []
var _sounds: Array[String] = []
var _popped: Array[String] = []
var _dialogues: Array[String] = []


func _ready() -> void:
	Audio.played.connect(func(s: String) -> void: _sounds.append(s))
	Fx.popped.connect(func(t: String) -> void: _popped.append(t))
	EventBus.dialogue_started.connect(func(n: String) -> void: _dialogues.append(n))
	_run.call_deferred()


func _run() -> void:
	await _test_order_and_game_time()
	await _test_hold_set_release()
	await _test_debug_keys()
	await _test_hours()
	await _test_dial()
	await _test_hud_layout()
	var scene: Node = load(YARD_HD).instantiate()
	add_child(scene)
	await _frames(10)
	await _test_yard_fades(scene)
	await _test_shops(scene)
	scene.queue_free()
	await _frames(5)
	# The yard has no enemies (they live in the arena): night misses and the
	# dog's nose are proved on a rat placed in the arena.
	var arena: Node = load(ARENA_HD).instantiate()
	add_child(arena)
	await _frames(10)
	# The arena's rats are day-schedule ones now (they leave at dusk), so night
	# misses and the dog's nose are proved on one placed by hand that ignores the clock.
	var fixed_rat := Enemy.create(load("res://data/enemies/rat.tres"), Vector2(1750, 1540))
	fixed_rat.clock_rule = "unchanged"
	arena.get_node("Yard/World").add_child(fixed_rat)
	_check(Clock.mode == "free", "the arena runs the clock free, so day and night happen there (%s)" % Clock.mode)
	await _test_night_misses(arena)
	await _test_dog_nose(arena)
	arena.queue_free()
	await _frames(5)
	await _test_prologue_held()
	if _failures.is_empty():
		print("[TEST] PASS  smoke_clock")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_order_and_game_time() -> void:
	var seen: Array[String] = []
	var blends: Array[float] = []
	var on_change := func(p: String, b: float) -> void:
		seen.append(p)
		blends.append(b)
	Clock.phase_changed.connect(on_change)
	Clock.enter_realm("hold", "morning")
	_check(Clock.phase == "morning" and Clock.mode == "hold", "enter_realm(hold, morning) holds at morning")
	_check(is_equal_approx(Clock.phase_seconds("morning"), 6.0 * 60.0) and is_equal_approx(Clock.phase_seconds(), 6.0 * 60.0),
			"morning lasts 6 game hours (6 minutes)")
	_check(is_equal_approx(Clock.DAY_MINUTES, 24.0), "a game day is 24 real minutes by default")
	Clock.advance(Clock.phase_seconds() - 1.0)
	_check(seen.is_empty() and Clock.phase == "morning", "one second short of a phase: still morning")
	Clock.advance(1.5)
	for i in 3:
		Clock.advance(Clock.phase_seconds())
	_check(seen == ["day", "golden", "night", "morning"], "phases in order and wrapping: %s" % [seen])
	_check(blends.all(func(b: float) -> bool: return b == Clock.FADE_SECONDS) and Clock.FADE_SECONDS >= 3.0,
			"the clock's own changes fade slowly (%s)" % [blends])

	# Game time: 60 frames at --fixed-fps 60 is one second on the clock.
	Clock.release()
	var before := Clock.elapsed
	await _frames(60)
	var ran := Clock.elapsed - before
	_check(ran > 0.9 and ran < 1.1, "60 frames should run the clock 1 s (ran %.2f)" % ran)
	get_tree().paused = true
	before = Clock.elapsed
	await _frames(30)
	_check(Clock.elapsed == before, "a paused game stops the clock")
	get_tree().paused = false
	Clock.phase_changed.disconnect(on_change)


func _test_hold_set_release() -> void:
	Clock.hold("night", 0.0)
	var t := Clock.elapsed
	await _frames(30)
	_check(Clock.phase == "night" and Clock.elapsed == t and Clock.mode == "hold", "hold freezes the clock")
	Clock.jump("day", 0.0)
	await _frames(10)
	_check(Clock.phase == "day" and Clock.mode == "hold" and Clock.elapsed == 0.0, "a jump keeps a held clock held")
	Clock.release()
	await _frames(30)
	_check(Clock.mode == "free" and Clock.elapsed > 0.3, "release runs it again")
	Clock.hold("golden", 0.0)
	Clock.set_time("night", 0.0)
	await _frames(30)
	_check(Clock.phase == "night" and Clock.mode == "free" and Clock.elapsed > 0.3, "set jumps, then runs on")


func _test_debug_keys() -> void:
	Clock.set_time("day", 0.0)
	_tap("debug_clock_pause")
	await _frames(2)
	var t := Clock.elapsed
	await _frames(30)
	_check(Clock.paused and Clock.elapsed == t, "F7 stops the clock")
	_tap("debug_clock_pause")
	await _frames(2)
	_check(not Clock.paused and Clock.is_running(), "F7 again restarts it")
	_tap("debug_clock_speed")
	await _frames(2)
	_check(Clock.speed == 10.0, "F9 speeds it to x10 (x%d)" % int(Clock.speed))
	t = Clock.elapsed
	await _frames(60)
	_check(absf(Clock.elapsed - t - 10.0) < 1.0, "x10 runs 10 s a second (ran %.1f)" % (Clock.elapsed - t))
	_tap("debug_clock_speed")
	await _frames(2)
	_check(Clock.speed == 60.0, "then x60")
	_tap("debug_clock_speed")
	await _frames(2)
	_check(Clock.speed == 1.0, "then back to x1")
	_check(Clock.status_text().contains("day") and Clock.status_text().contains("x1"),
			"the F3 line names the phase and speed: %s" % Clock.status_text())


# -----------------------------------------------------------------------------
func _test_hours() -> void:
	var lengths := {"morning": 6.0, "day": 6.0, "golden": 3.0, "night": 9.0}
	var starts := {"morning": 5.0, "day": 11.0, "golden": 17.0, "night": 20.0}
	for p in Clock.PHASES:
		_check(is_equal_approx(Clock.phase_hours(p), lengths[p]), "%s lasts %.0f hours (%.1f)" % [p, lengths[p], Clock.phase_hours(p)])
		Clock.hold(p, 0.0)
		_check(is_equal_approx(Clock.hour(), starts[p]), "%s starts at %.0f:00 (%.2f)" % [p, starts[p], Clock.hour()])
	# Crossing a boundary by running: 1 minute of game time = 1 hour, the phase
	# flips at 5, 11, 17 and 20, and the hour wraps past midnight.
	Clock.hold("night", 0.0)
	Clock.advance(60.0 * 3.5)
	_check(absf(Clock.hour() - 23.5) < 0.001 and Clock.phase == "night", "3.5 minutes after 20:00 it is 23:30 (%.2f)" % Clock.hour())
	Clock.advance(60.0)
	_check(absf(Clock.hour() - 0.5) < 0.001, "an hour later it is 0:30, wrapped (%.2f)" % Clock.hour())
	Clock.advance(60.0 * 4.0)
	_check(Clock.phase == "night" and absf(Clock.hour() - 4.5) < 0.001, "still night at 4:30 (%s %.2f)" % [Clock.phase, Clock.hour()])
	Clock.advance(60.0)
	_check(Clock.phase == "morning" and absf(Clock.hour() - 5.5) < 0.001, "morning from 5:00 (%s %.2f)" % [Clock.phase, Clock.hour()])
	Clock.advance(60.0 * 6.0)
	_check(Clock.phase == "day" and absf(Clock.hour() - 11.5) < 0.001, "day from 11:00 (%s %.2f)" % [Clock.phase, Clock.hour()])
	Clock.advance(60.0 * 6.0)
	_check(Clock.phase == "golden" and absf(Clock.hour() - 17.5) < 0.001, "golden from 17:00 (%s %.2f)" % [Clock.phase, Clock.hour()])
	Clock.advance(60.0 * 3.0)
	_check(Clock.phase == "night" and absf(Clock.hour() - 20.5) < 0.001, "night from 20:00 (%s %.2f)" % [Clock.phase, Clock.hour()])
	# Real game time: 60 frames at 60 fps is one second, so 1/60 of an hour.
	Clock.release()
	var h0 := Clock.hour()
	await _frames(120)
	var dh := Clock.hour() - h0
	_check(absf(dh - 2.0 / 60.0) < 0.004, "two seconds of game time is 1/30 of an hour (%.4f)" % dh)
	# F2 lands on the next phase's start.
	Clock.hold("golden", 0.0)
	Clock.next_phase(0.0)
	_check(Clock.phase == "night" and is_equal_approx(Clock.hour(), 20.0), "F2 from golden goes to 20:00")


func _test_dial() -> void:
	# Pure mapping first.
	var noon_sun := SkyDial.body_offset(12.0)
	var noon_moon := SkyDial.body_offset(12.0, true)
	_check(noon_sun.distance_to(Vector2(0, -SkyDial.WHEEL_R)) < 0.01, "the sun is at the top of the dial at noon (%s)" % noon_sun)
	_check(noon_moon.y > 0.0, "and the moon is under the dial then (%s)" % noon_moon)
	var mid_moon := SkyDial.body_offset(0.0, true)
	_check(mid_moon.distance_to(Vector2(0, -SkyDial.WHEEL_R)) < 0.01, "the moon is at the top at midnight (%s)" % mid_moon)
	_check(SkyDial.body_offset(DayLight.SUNRISE).x < -SkyDial.WHEEL_R + 0.01 and absf(SkyDial.body_offset(DayLight.SUNRISE).y) < 0.01,
			"the sun rises on the left at the world's sunrise (%.1f)" % DayLight.SUNRISE)
	_check(SkyDial.body_offset(DayLight.SUNSET).x > SkyDial.WHEEL_R - 0.01 and absf(SkyDial.body_offset(DayLight.SUNSET).y) < 0.01,
			"and sets on the right at the world's sunset (%.1f)" % DayLight.SUNSET)
	_check(SkyDial.body_offset(9.0).y < -5.0 and SkyDial.body_offset(9.0).x < 0.0, "at 9:00 it is climbing, left of the top")
	_check(SkyDial.body_offset(3.0).distance_to(-SkyDial.body_offset(3.0, true)) < 0.01, "the moon is always opposite the sun")
	var day_sky: Color = SkyDial.sky_colors(13.0)[1]
	var dusk_sky: Color = SkyDial.sky_colors(DayLight.SUNSET)[1]
	var night_sky: Color = SkyDial.sky_colors(1.0)[0]
	_check(day_sky.b > 0.9 and dusk_sky.r > dusk_sky.b + 0.4 and night_sky.b < 0.25, "pale blue by day, orange at dusk, navy at night")
	_check(SkyDial.star_alpha(13.0) == 0.0 and SkyDial.star_alpha(1.0) == 1.0, "stars only at night")

	# The live dial.
	var hud = load("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	await _frames(3)
	var dial: SkyDial = hud.sky_dial()
	var ticks: Array[Vector2i] = []
	dial.ticked.connect(func(h: int, big: bool) -> void: ticks.append(Vector2i(h, 1 if big else 0)))
	Clock.hold("day", 0.0)  # 11:00, held
	await _frames(3)
	_check(dial.badges() == ["pause"], "a held clock shows the pause badge (%s)" % [dial.badges()])
	Clock.release()
	_check(dial.badges().is_empty(), "a running clock shows no badge")
	Clock.toggle_pause()
	_check(dial.badges() == ["pause"], "F7 (stopped) shows the pause badge")
	Clock.toggle_pause()
	Clock.cycle_speed()
	_check(dial.badges() == ["x10"], "x10 shows its badge (%s)" % [dial.badges()])
	Clock.cycle_speed()
	_check(dial.badges() == ["x60"], "x60 shows its badge (%s)" % [dial.badges()])
	Clock.cycle_speed()
	_check(dial.badges().is_empty(), "back at x1: none")

	# A tick every 3 game hours, big at 0, 6, 12 and 18; the chime plays.
	Clock.hold("morning", 0.0)  # 5:00
	await _frames(2)
	ticks.clear()
	_sounds.clear()
	Clock.release()
	for i in 30:  # 30 steps of 0.25 hour = 7.5 hours, 5:00 -> 12:30
		Clock.advance(Clock.hour_seconds() * 0.25)
		await _frames(1)
	_check(ticks == [Vector2i(6, 1), Vector2i(9, 0), Vector2i(12, 1)], "ticks at 6 (big), 9, 12 (big) between 5:00 and 12:30: %s" % [ticks])
	_check(_sounds.count("dial_chime_big") == 2 and _sounds.count("dial_chime") == 1, "a soft chime each, bigger on the big ones: %s" % [_sounds])
	ticks.clear()
	Clock.next_phase(0.0)  # a jump is not a tick
	await _frames(3)
	_check(ticks.is_empty(), "F2 jumps do not tick")
	Clock.hold("night", 0.0)
	Clock.release()
	await _frames(2)
	ticks.clear()
	for i in 12:  # 20:00 -> 23:00
		Clock.advance(Clock.hour_seconds() * 0.25)
		await _frames(1)
	_check(ticks == [Vector2i(21, 0)], "night: 21 ticks, small (%s)" % [ticks])

	Clock.hold("golden", 0.0)
	await _frames(3)
	# No time text, no setting for it.
	_check(not dial.has_method("text_shown") and Settings.option("show_time").is_empty(), "the dial has no time text and there is no Show the time option")
	# Hidden while people talk, back after.
	EventBus.dialogue_started.emit("x")
	_check(not dial.visible, "the dial hides with the rest of the HUD during dialogue")
	EventBus.dialogue_ended.emit("x")
	_check(dial.visible, "and returns")
	hud.queue_free()
	await _frames(2)


## Top-centre dial, bottom-centre hotbar, nothing overlapping, at 16:9 and 21:9.
func _test_hud_layout() -> void:
	for view in [Vector2i(640, 360), Vector2i(840, 360), Vector2i(1280, 720)]:
		var sv := SubViewport.new()
		sv.size = view
		add_child(sv)
		var hud = load("res://ui/hud/hud.tscn").instantiate()
		sv.add_child(hud)
		await _frames(4)
		var frame: Rect2 = hud.get_safe_frame().get_global_rect()
		var dial: Control = hud.sky_dial()
		var bar: Control = hud.get_node("SafeFrame/QuickBar")
		var kid: Control = hud.get_node("SafeFrame/KidCard")
		var dog: Control = hud.get_node("SafeFrame/DogCard")
		var prompt: Label = hud.get_node("SafeFrame/InteractPrompt")
		prompt.text = "[E] Talk to a neighbour"
		prompt.visible = true
		hud.show_toast("Found Old key x2   2/5 here")
		hud.show_notice("Slot 2 is empty")
		await _frames(3)
		var toast: Control = hud.get_node("SafeFrame/FoundToast")
		var notice: Control = hud.get_node("SafeFrame/Notice")
		var tag := "at %dx%d: " % [view.x, view.y]
		var cx := frame.position.x + frame.size.x * 0.5
		_check(absf(bar.get_global_rect().get_center().x - cx) <= 0.6 and bar.get_global_rect().end.y > frame.end.y - 8.0
				and bar.get_global_rect().position.y > frame.size.y * 0.8, tag + "the hotbar is at the bottom centre (%s)" % bar.get_global_rect())
		_check(absf(dial.get_global_rect().get_center().x - cx) <= 0.6 and dial.get_global_rect().position.y < 8.0,
				tag + "the dial is at the top centre (%s)" % dial.get_global_rect())
		var parts := {"dial": dial, "bar": bar, "kid": kid, "dog": dog, "prompt": prompt, "toast": toast, "notice": notice}
		var names: Array = parts.keys()
		for i in names.size():
			var r: Rect2 = (parts[names[i]] as Control).get_global_rect()
			_check(frame.encloses(r), tag + "%s is inside the safe frame (%s in %s)" % [names[i], r, frame])
			for j in range(i + 1, names.size()):
				var r2: Rect2 = (parts[names[j]] as Control).get_global_rect()
				_check(not r.intersects(r2), tag + "%s and %s do not overlap (%s, %s)" % [names[i], names[j], r, r2])
		sv.queue_free()
		await _frames(2)


# -----------------------------------------------------------------------------
func _test_yard_fades(scene: Node) -> void:
	var atmo: Atmosphere = scene.get_node("Yard/Atmosphere")
	var hd: HdView = scene.get_node("HdView")
	_check(Clock.mode == "free", "the test yard runs the clock free (%s)" % Clock.mode)
	Clock.paused = true  # we step the clock by hand below
	atmo.set_time("day", 0.0)
	await _frames(5)
	var sun: DirectionalLight3D = hd.get_node("Sun")
	var moon: DirectionalLight3D = hd.get_node("Moon")
	var day_e: float = HdView.look_for(Clock.hour())["sun_energy"]
	_check(absf(sun.light_energy - day_e) < 0.01 and day_e > 1.0, "day sun to start (%.2f vs %.2f)" % [sun.light_energy, day_e])

	# The look follows the HOUR: step 11:00 -> 20:30 in ten-minute strides across
	# the golden phase change (17:00) and watch the sun: no jump anywhere, and the
	# elevation travels (owner, 2026-10-09: the sun dial doesn't match the lighting).
	var last_e := sun.light_energy
	var last_el := sun.rotation_degrees.x
	var worst_e := 0.0
	var worst_el := 0.0
	var crossed_17 := 0.0
	var elevs: Array[float] = []
	while Clock.hour() < 20.5:
		var was := Clock.phase
		Clock.advance(Clock.hour_seconds() / 6.0)
		await _frames(2)
		worst_e = maxf(worst_e, absf(sun.light_energy - last_e))
		worst_el = maxf(worst_el, absf(sun.rotation_degrees.x - last_el))
		if was != Clock.phase and Clock.phase == "golden":
			crossed_17 = absf(sun.light_energy - last_e)
			_check(absf(Clock.hour() - 17.0) < 0.2, "golden starts at 17:00 (%.2f)" % Clock.hour())
		last_e = sun.light_energy
		last_el = sun.rotation_degrees.x
		elevs.append(-sun.rotation_degrees.x)
	_check(worst_e < 0.45, "the sun's energy never jumps (worst ten-minute step %.2f)" % worst_e)
	_check(worst_el < 2.5, "the sun's elevation moves smoothly (worst step %.2f deg)" % worst_el)
	_check(crossed_17 < 0.1, "nothing pops at the golden phase change (%.3f)" % crossed_17)
	_check(elevs.max() > 55.0 and elevs.min() >= 29.9, "the sun climbs and sinks but stays above 30 degrees (%.1f..%.1f)" % [elevs.min(), elevs.max()])
	_check(moon.light_energy > 0.05 and sun.light_energy < 0.01, "after dusk the moon light has taken over (moon %.2f, sun %.2f)" % [moon.light_energy, sun.light_energy])

	# Phases still switch at their hours for gameplay.
	Clock.hold("morning", 0.0)
	var starts := {"day": 11.0, "golden": 17.0, "night": 20.0, "morning": 5.0}
	var prev := {"day": "morning", "golden": "day", "night": "golden", "morning": "night"}
	for ph: String in starts:
		Clock.hold(prev[ph], 0.0)
		var left := (float(Clock.PHASE_START[ph]) - float(Clock.PHASE_START[prev[ph]]))
		left = fposmod(left, 24.0)
		Clock.advance((left - 0.01) * Clock.hour_seconds())
		var before := Clock.phase
		Clock.advance(0.02 * Clock.hour_seconds())
		_check(before == prev[ph] and Clock.phase == ph, "%s starts at %02d:00 (was %s, now %s)" % [ph, int(starts[ph]), before, Clock.phase])

	# F2 crossfades quickly from the look on screen to the new hour's look.
	Clock.hold("day", 0.0)
	await _frames(5)
	var before_e := sun.light_energy
	Clock.next_phase(0.8)
	await _frames(6)
	var target_e: float = HdView.look_for(Clock.hour())["sun_energy"]
	_check(absf(sun.light_energy - before_e) < absf(target_e - before_e) - 0.05 or absf(target_e - before_e) < 0.1,
			"F2 starts a blend, no pop (%.2f from %.2f toward %.2f)" % [sun.light_energy, before_e, target_e])
	await _wait(1.2)
	_check(absf(sun.light_energy - target_e) < 0.02, "and lands on the new phase's start in under 1.5 s (%.2f vs %.2f)" % [sun.light_energy, target_e])
	# A held clock holds the look.
	var held_e := sun.light_energy
	await _wait(1.0)
	_check(absf(sun.light_energy - held_e) < 0.001, "a held clock holds the look")
	Clock.release()
	Clock.paused = false

	# Dial and world agree: over 24 h the world's sun is above the horizon exactly
	# when the dial's sun is, and the moon likewise.
	var disagreements := 0
	var lit_while_down := 0
	var n := 0
	var h := 0.1
	while h < 24.0:
		n += 1
		var dial_up := SkyDial.body_offset(h).y < 0.0
		var dial_moon_up := SkyDial.body_offset(h, true).y < 0.0
		var look := HdView.look_for(h)
		var sp := DayLight.sun_pose(h)
		var mp := DayLight.moon_pose(h)
		if dial_up != sp["up"] or dial_moon_up != mp["up"] or dial_up == dial_moon_up:
			disagreements += 1
		if (look["sun_energy"] > 0.001 and not dial_up) or (look["moon_energy"] > 0.001 and not dial_moon_up):
			lit_while_down += 1
		if sp["up"] and sp["elev"] < 29.9:
			lit_while_down += 1
		h += 0.25
	_check(disagreements == 0, "dial and world agree on sun and moon over 24 h (%d of %d samples differ)" % [disagreements, n])
	_check(lit_while_down == 0, "a light is never on while its body is below the dial's horizon (%d)" % lit_while_down)
	# The look is smooth by hour for every number in both views' tables.
	var worst := 0.0
	var key_at := ""
	var prev_look := HdView.look_for(0.0)
	var prev_2d := DayLight.sample(Atmosphere.PRESETS, 0.0)
	h = 0.05
	while h < 24.0:
		for pair in [[prev_look, HdView.look_for(h)], [prev_2d, DayLight.sample(Atmosphere.PRESETS, h)]]:
			for k: String in pair[1]:
				var a: Variant = pair[0][k]
				var b: Variant = pair[1][k]
				var d: float = (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) if a is Color else absf(a - b)
				var scale: float = 1.0 if (a is Color or k == "sun_elev" or k == "moon_elev" or k == "sun_yaw" or k == "moon_yaw") else maxf(absf(b), absf(a)) + 0.3
				if k.ends_with("elev") or k.ends_with("yaw"):
					continue  # a body below the horizon is unlit and may re-aim (energy is checked)
				if d / scale > worst:
					worst = d / scale
					key_at = "%s at %.2f" % [k, h]
		prev_look = HdView.look_for(h)
		prev_2d = DayLight.sample(Atmosphere.PRESETS, h)
		h += 0.05
	_check(worst < 0.35, "no value in the look jumps by hour (worst %.2f, %s)" % [worst, key_at])
	# Morning has its own look in both views.
	_check(HdView.PRESETS.has("morning") and Atmosphere.PRESETS.has("morning"), "a morning preset in both views")


func _test_shops(_scene: Node) -> void:
	var corner: Shop = null
	var stand: Shop = null
	for s: Shop in get_tree().get_nodes_in_group("shop"):
		if s.shop_id == "corner_store":
			corner = s
		elif s.shop_id == "all_night":
			stand = s
	_check(corner != null and stand != null, "the yard has both shops")
	_check(get_tree().get_nodes_in_group("enemy").is_empty(), "the yard has no enemies (no rats, burrows or bats)")
	_check(_scene.get_node("Yard").get_node_or_null("DayNight") == null, "and no day/night director")
	if corner == null or stand == null:
		return
	_check(corner.rule == "follow_clock" and stand.rule == "always_open", "one follows the clock, one stays open")

	Clock.hold("night", 0.0)
	await _frames(2)
	_check(not corner.is_open() and not corner.keeper.visible and corner.shutter.visible,
			"corner store at night: keeper gone, shutter down")
	_check(corner.keeper.process_mode == Node.PROCESS_MODE_DISABLED, "and the missing keeper isn't solid")
	_check(stand.is_open() and stand.keeper.visible and not stand.shutter.visible, "the all-night stand is open at night")
	corner.shutter.interact()
	await _finish_dialogue()
	_check(_dialogues.has("shop_corner_closed"), "the shutter says it's closed (%s)" % [_dialogues])

	var sodas := GameState.item_count("soda")
	stand.keeper.interact()
	await _finish_dialogue()
	_check(GameState.item_count("soda") == sodas + 1, "the night vendor hands over a soda")
	stand.keeper.interact()
	await _finish_dialogue()
	_check(GameState.item_count("soda") == sodas + 1 and _dialogues.back() == "shop_allnight_again",
			"only once per phase (then: %s)" % _dialogues.back())

	Clock.jump("morning", 0.0)
	await _frames(2)
	_check(corner.is_open() and corner.keeper.visible and not corner.shutter.visible,
			"corner store open in the morning")
	var apples := GameState.item_count("apple")
	corner.keeper.interact()
	await _finish_dialogue()
	_check(GameState.item_count("apple") == apples + 1 and _dialogues.back() == "shop_corner",
			"the grocer greets and hands over an apple")
	Clock.jump("day", 0.0)
	await _frames(2)
	stand.keeper.interact()
	await _finish_dialogue()
	_check(GameState.item_count("soda") == sodas + 2, "a new phase, a new soda")

	stand.set_rule("always_closed")
	_check(not stand.is_open() and stand.shutter.visible and not stand.keeper.visible, "a scene can close a shop")
	stand.set_rule("always_open")


func _test_night_misses(scene: Node) -> void:
	var kid: Kid = scene.get_node("Yard/World/Kid")
	var hd: HdView = scene.get_node("HdView")
	kid.light_on = true
	kid.facing = Vector2.RIGHT
	var at := kid.global_position
	# The 2D cone.
	_check(kid.in_beam_2d(at + Vector2(100, 0)), "2D: straight ahead is in the beam")
	_check(not kid.in_beam_2d(at + Vector2(-100, 0)), "2D: behind him is not")
	_check(not kid.in_beam_2d(at + Vector2(80, 80)), "2D: 45 degrees off is not")
	_check(not kid.in_beam_2d(at + Vector2(400, 0)), "2D: past the beam's reach is not")
	# HdView's real spotlight.
	if not hd.enabled:
		hd.set_enabled(true)
	await _frames(3)
	_check(hd.in_beam(at + Vector2(70, 0)), "HD: the spotlight covers a rat two meters ahead")
	_check(not hd.in_beam(at + Vector2(-70, 0)), "HD: not one behind him")
	_check(not hd.in_beam(at + Vector2(0, 70)), "HD: not one beside him")
	_check(kid.point_in_beam(at + Vector2(70, 0)) and not kid.point_in_beam(at + Vector2(-70, 0)),
			"Kid.point_in_beam asks the HD view while it's on")
	kid.light_on = false
	_check(not kid.point_in_beam(at + Vector2(70, 0)), "flashlight off: nothing is lit")
	kid.light_on = true

	var behind := at + Vector2(-60, 0)
	var ahead := at + Vector2(60, 0)
	kid.night_miss_chance = 1.0
	Clock.hold("day", 0.0)
	_check(not kid.misses_at(behind), "by day he never misses")
	Clock.hold("night", 0.0)
	_check(kid.misses_at(behind) and not kid.misses_at(ahead), "at night: misses outside the beam, not in it")
	kid.night_miss_chance = 0.2
	_check(is_equal_approx(0.2, kid.get_script().get_property_default_value("night_miss_chance")),
			"default night miss chance is 20%")
	var counts: Array[int] = []
	for run in 2:
		kid.miss_rng.seed = 12345
		var n := 0
		for i in 1000:
			n += 1 if kid.misses_at(behind) else 0
		counts.append(n)
	_check(counts[0] == counts[1], "seeded dice repeat (%s)" % [counts])
	_check(counts[0] > 150 and counts[0] < 250, "about 20%% of 1000 night swings outside the beam miss (%d)" % counts[0])

	# A miss deals nothing, pops "Miss" and whiffs.
	var rat := _rat()
	if rat == null:
		_failures.append("no rat in the arena")
		return
	var hp := rat.health.hp
	kid.night_miss_chance = 1.0
	kid.facing = Vector2.LEFT  # the rat is not in front of him
	kid.global_position = rat.global_position + Vector2(-20, 0)
	(kid.get_node("Camera2D") as Camera2D).reset_smoothing()  # sounds this far off are culled
	await _frames(3)
	_popped.clear()
	_sounds.clear()
	var info: HitInfo = kid._make_hit(rat.get_node("Hurtbox"))
	_check(info == null and _popped.has("Miss") and _sounds.has("swing"), "a night miss pops Miss and whiffs")
	var dealt := Combat.strike(get_tree(), rat.global_position, Vector2.RIGHT, 40.0, 360.0, "player",
			func(_hb: Hurtbox) -> HitInfo: return null)
	_check(dealt == 0 and rat.health.hp == hp, "a missed target takes no damage")
	kid.facing = Vector2.RIGHT  # now it's in his beam
	await _frames(3)
	_check(kid._make_hit(rat.get_node("Hurtbox")) != null, "the same rat in the beam is hit")
	kid.night_miss_chance = 0.2
	kid.global_position = at


func _test_dog_nose(scene: Node) -> void:
	var hd: HdView = scene.get_node("HdView")
	var rat := _rat()
	if rat == null:
		return
	var kid: Kid = scene.get_node("Yard/World/Kid")
	var dog: Dog = scene.get_node("Yard/World/Dog")
	Clock.hold("night", 0.0)
	await _wait(1.0)
	_check(Party.leader == kid and rat.scent == 0.0, "night, driving the kid: no scent (%.2f)" % rat.scent)
	Party.switch_control()
	await _wait(1.0)
	var glow: Sprite2D = rat.get_node("ScentGlow")
	_check(Party.leader == dog and rat.scent == 1.0 and glow.visible, "night, driving the dog: enemies glow (%.2f)" % rat.scent)
	var s3: Sprite3D = hd._mirrored.get(rat.get_instance_id())
	_check(s3 != null and is_equal_approx(float(s3.get_instance_shader_parameter("scent")), 1.0),
			"and the HD sprite glows too")
	_check(rat.health.max_hp == Difficulty.enemy_hp(rat.data.hp), "no stat change")
	Clock.hold("day", 0.0)
	await _wait(1.0)
	_check(rat.scent == 0.0 and not glow.visible, "by day, even with the dog: no glow")
	Party.switch_control()
	await _frames(5)


func _test_prologue_held() -> void:
	var lot: Node = load(LOT).instantiate()
	lot.skip_intro = true
	add_child(lot)
	await _frames(10)
	_check(Clock.mode == "hold" and Clock.phase == "golden", "the prologue holds the clock at golden (%s, %s)" % [Clock.mode, Clock.phase])
	Clock.advance(0.0)
	await _frames(60)
	_check(Clock.elapsed == 0.0 and Clock.phase == "golden", "and it doesn't move by itself")
	Dialogue.command.emit("time", PackedStringArray(["night", "0"]))
	await _frames(2)
	var atmo: Atmosphere = lot.get_node("Atmosphere")
	_check(Clock.phase == "night" and Clock.mode == "hold" and atmo.time_name == "night",
			"@time night moves it and keeps it held")
	lot.queue_free()
	await _frames(3)


# -----------------------------------------------------------------------------
func _rat() -> Enemy:
	for e in get_tree().get_nodes_in_group("enemy"):
		# Only a rat that ignores the clock: the day/night ones leave at dusk.
		if e is Enemy and not (e as Enemy).health.is_dead() and (e as Enemy).data.name_key == "enemy_rat" 				and (e as Enemy).clock_rule != "follow_clock":
			return e
	return null


func _finish_dialogue() -> void:
	await _frames(14)  # past the box's open guard
	for i in 60:
		if not Dialogue.is_active():
			return
		_tap("interact")
		await _frames(3)


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * 60.0))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
